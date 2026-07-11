/*
 * System-level token bucket throttle verification.
 *
 * Drives real CVA6 AXI traffic (L1 misses -> AR reads, dirty L1 evicts -> AW writes)
 * through the per-core token bucket throttle. Each test configures the bucket,
 * lets it settle to TOKEN_LIMIT, then times N transactions under various rates.
 *
 * Tests: [1-7] single-core reads and writes at different intervals; [8-9] dual-core
 * isolation and simultaneous throttling via hart1 running in parallel; [10] data
 * correctness under throttle; [11] concurrent AR+AW sharing one bucket; [12-13]
 * live TOKEN_LIMIT/REFILL_TOKENS reconfig.
 */

#include <stdio.h>
#include "encoding.h"
#include "utils.h"
#include "tb_defines.h"

#define read_32b(a)       (*(volatile uint32_t *)(long)(a))
#define write_32b(a, v)   (*(volatile uint32_t *)(long)(a) = (v))
#define TB(c, off)        (TB_CFG_BASE_ADDR + (c) * TB_CORE_BYTES + (off))
#define FENCE()           asm volatile("fence iorw, iorw" ::: "memory")

#define TOKEN_LIMIT     8U
#define REFILL_TOKENS   1U
#define REFILL_INTERVAL 500U
#define AR_COST         1U
#define AW_COST         1U

#define STRIDE_BYTES    64U
#define STRIDE          (STRIDE_BYTES / sizeof(uint64_t)) //Same stride but expressed in array-element units
#define AR_COUNT         64U

#define THROTTLE_THRESHOLD  (((AR_COUNT - TOKEN_LIMIT) * REFILL_INTERVAL) * 4U / 5U)

#define AW_COUNT         384U
#define AW_INTERVAL     200U

#define THRASH_BYTES    (32U * 1024U)

#define HART1           1U

#define MH_ROUNDS       3U

#define MH_TIMEOUT      200000ULL

#define MH_MAGIC        0x600D0000U
#define MH_GO(r)        (MH_MAGIC + (r))

static volatile uint64_t rd_buf [AR_COUNT * STRIDE]      __attribute__((aligned(64)));
static volatile uint64_t wr_buf [AW_COUNT * STRIDE]      __attribute__((aligned(64)));
static volatile uint64_t mix_buf[AW_COUNT * STRIDE]      __attribute__((aligned(64)));
static volatile uint64_t thrash [THRASH_BYTES / sizeof(uint64_t)] __attribute__((aligned(64)));
static volatile uint64_t mh_buf [MH_ROUNDS * AR_COUNT * STRIDE]  __attribute__((aligned(64)));

__attribute__ ((section(".heapl2ram"))) volatile uint32_t mh_go       = 0;
__attribute__ ((section(".heapl2ram"))) volatile uint32_t mh_done     = 0;
__attribute__ ((section(".heapl2ram"))) volatile uint32_t mh_throttle = 0;
__attribute__ ((section(".heapl2ram"))) volatile uint64_t mh_t1       = 0;

// Writes config regs only; enable/disable is controlled separately via tb_en().
static void tb_cfg(unsigned c, uint32_t limit, uint32_t refill,
                   uint32_t interval, uint32_t ar, uint32_t aw)
{
    write_32b(TB(c, TOKEN_LIMIT_OFFSET),     limit);
    write_32b(TB(c, REFILL_TOKENS_OFFSET),   refill);
    write_32b(TB(c, REFILL_INTERVAL_OFFSET), interval);
    write_32b(TB(c, AR_COST_OFFSET),         ar);
    write_32b(TB(c, AW_COST_OFFSET),         aw);
    FENCE();
}

static inline void tb_en(unsigned c, int on)
{
    write_32b(TB(c, CTRL_OFFSET), on ? CTRL_ENABLE : CTRL_DISABLE);
    FENCE();
}

static void tb_settle(uint32_t limit, uint32_t refill, uint32_t interval)
{
    uint64_t need = (uint64_t)(limit / refill + 1U) * interval * 2U;
    uint64_t t0 = read_csr(mcycle);
    while (read_csr(mcycle) - t0 < need);
}

//Used to push rd_buf's lines out of L1.
static void l1_evict(void)
{
    for (unsigned i = 0; i < THRASH_BYTES / STRIDE_BYTES; i++)
        (void)thrash[i * STRIDE];
    FENCE();
}

// Configure + evict + enable + settle in one call.
static void tb_arm(unsigned c, uint32_t limit, uint32_t refill, uint32_t interval,
                    uint32_t ar, uint32_t aw)
{
    tb_cfg(c, limit, refill, interval, ar, aw);
    l1_evict();
    tb_en(c, 1);
    tb_settle(limit, refill, interval);
}

static void tb_reconfig(uint32_t limit, uint32_t refill, uint32_t interval)
{
    tb_cfg(0, limit, refill, interval, AR_COST, AW_COST);
    l1_evict();
    tb_settle(limit, refill, interval);
}

static uint64_t timed_reads(volatile uint64_t *p)
{
    uint64_t t0 = read_csr(mcycle);
    for (unsigned i = 0; i < AR_COUNT; i++)
        (void)p[i * STRIDE];
    return read_csr(mcycle) - t0;
}

static uint64_t timed_writes(volatile uint64_t *p)
{
    uint64_t t0 = read_csr(mcycle);
    for (unsigned i = 0; i < AW_COUNT; i++)
        p[i * STRIDE] = i + 1;
    FENCE();
    return read_csr(mcycle) - t0;
}

// Interleaves a read (AR) and a write (AW) per iteration so both channels
// contend for the same bucket concurrently. n must exceed L1 capacity so dirty
// lines are evicted (real AWs) inside the window; reads wrap and re-miss as
// the writes evict them.
static uint64_t timed_mixed(volatile uint64_t *rp, volatile uint64_t *wp, unsigned n)
{
    uint64_t t0 = read_csr(mcycle);
    for (unsigned i = 0; i < n; i++) {
        (void)rp[(i % AR_COUNT) * STRIDE];
        wp[i * STRIDE] = i + 1;
    }
    FENCE();
    return read_csr(mcycle) - t0;
}

static uint32_t verify_pattern(volatile uint64_t *p, unsigned n, uint64_t base)
{
    uint32_t bad = 0;
    for (unsigned i = 0; i < n; i++)
        if (p[i * STRIDE] != base + i + 1) bad++;
    return bad;
}

// TB_OFF:    leave the bucket disabled (baseline).
// TB_ENABLE: enable the bucket after configuring it.
// TB_LIVE:   bucket is already enabled; config takes effect on the fly.
// Neither mode disables the bucket afterward -- that's the caller's job, so
// back-to-back enabled runs can hand off via TB_LIVE.
typedef enum { TB_OFF, TB_ENABLE, TB_LIVE } tb_mode_t;

static uint64_t timed_run(uint32_t interval, tb_mode_t mode, int is_write)
{
    uint32_t ar_cost = is_write ? 0U : AR_COST; //When testing write, read requests are free as to isolate AW throttling

    tb_cfg(0, TOKEN_LIMIT, REFILL_TOKENS, interval, ar_cost, AW_COST);
    l1_evict();

    if (mode == TB_ENABLE) tb_en(0, 1);
    if (mode != TB_OFF) tb_settle(TOKEN_LIMIT, REFILL_TOKENS, interval);

    return is_write ? timed_writes(wr_buf) : timed_reads(rd_buf);
}

static int mh_wait(volatile uint32_t *flag, uint32_t val)
{
    for (uint64_t i = 0; i < MH_TIMEOUT; i++) {
        if (*flag == val) return 1;
        FENCE();
    }
    return 0;
}

//Hart1 is not primed like hart0 so it shows larger baseline during sim, but thats fine since the value is reliable across iterations.
static void run_hart1(void)
{
    mh_done = 0;
    FENCE();

    tb_cfg(HART1, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);

    for (uint32_t round = 1; round <= MH_ROUNDS; round++) {
        uint32_t go;
        do { FENCE(); go = mh_go; }
        while (go < MH_GO(round) || go > MH_GO(MH_ROUNDS));
        round = go - MH_MAGIC;
        if (mh_throttle) { tb_en(HART1, 1); tb_settle(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL); }
        mh_t1 = timed_reads(mh_buf + (round - 1) * AR_COUNT * STRIDE);
        if (mh_throttle) tb_en(HART1, 0);
        FENCE();
        mh_done = MH_GO(round);
        FENCE();
    }
    while (1) asm volatile("wfi");
}

int thread_entry(int cid, int nc){
  return 0;
}

int main(int argc, char const *argv[]){
    uint32_t mhartid;
    asm volatile("csrr %0, 0xF14\n" : "=r"(mhartid));
    if (mhartid == HART1) { run_hart1(); }
    if (mhartid != 0)     { while (1) asm volatile("wfi"); }

#ifdef FPGA_EMULATION
    uint32_t baud_rate = 9600, test_freq = 100000000;
#else
    uint32_t baud_rate = 115200, test_freq = 50000000;
#endif
    uart_set_cfg(0, (test_freq / baud_rate) >> 4);

    printf("=== Token Bucket Throttle Test ===\r\n");
    printf("AR_COUNT=%u limit=%u refill=%u/%u ar_cost=%u  threshold=%u\r\n",
           AR_COUNT, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST,
           THROTTLE_THRESHOLD);
    uart_wait_tx_done();
    
    //Warm-up for TLB and initial write allocations.
    for (unsigned i = 0; i < AR_COUNT; i++) 
        (void) rd_buf[i * STRIDE];
    for (unsigned i = 0; i < AW_COUNT; i++) 
        wr_buf[i * STRIDE] = i + 1; //Initialize wr_buf
    FENCE();

    uint64_t t_base = timed_run(REFILL_INTERVAL, TB_OFF, 0);
    printf("[1] Read Baseline (disabled)        = %u cycles  (ctrl readback=%u)\r\n",
           (unsigned int)t_base, read_32b(TB(0, CTRL_OFFSET)));

    uint64_t t_read_1x = timed_run(REFILL_INTERVAL, TB_ENABLE, 0);
    printf("[2] Read x1  (interval=%u)     = %u cycles\r\n",
           REFILL_INTERVAL, (unsigned int)t_read_1x);

    uint64_t t_read_2x = timed_run(REFILL_INTERVAL * 2U, TB_LIVE, 0);
    printf("[3] Read x2  (interval=%u)     = %u cycles\r\n",
           REFILL_INTERVAL * 2U, (unsigned int)t_read_2x);
    tb_en(0, 0);

    uint64_t t_release = timed_run(REFILL_INTERVAL, TB_OFF, 0);
    printf("[4] Release  (disabled)        = %u cycles\r\n", (unsigned int)t_release);

    uint64_t t_wbase = timed_run(AW_INTERVAL, TB_OFF, 1);
    printf("[5] Write Baseline (disabled)      = %u cycles\r\n", (unsigned int)t_wbase);

    uint64_t t_w1 = timed_run(AW_INTERVAL, TB_ENABLE, 1);
    printf("[6] Write x1 (interval=%u)     = %u cycles\r\n",
           AW_INTERVAL, (unsigned int)t_w1);

    uint64_t t_w2 = timed_run(AW_INTERVAL * 2U, TB_LIVE, 1);
    printf("[7] Write x2 (interval=%u)     = %u cycles\r\n",
           AW_INTERVAL * 2U, (unsigned int)t_w2);
    tb_en(0, 0);
    uart_wait_tx_done();

    //Dual-Core Tests
    mh_throttle = 0; //Hart1 flags defined above
    FENCE();
    mh_go = MH_GO(1);
    FENCE();
    int alone_ok = mh_wait(&mh_done, MH_GO(1));
    uint64_t t_iso1_alone = mh_t1;
    printf("[8a] Hart1 alone (reference)   = %u cycles  (ok=%d)\r\n",
           (unsigned int)t_iso1_alone, alone_ok);

    tb_arm(0, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);
    mh_throttle = 0;
    FENCE();
    mh_go = MH_GO(2);
    FENCE();
    uint64_t t_iso0 = timed_reads(rd_buf);
    tb_en(0, 0);
    int iso_ok = mh_wait(&mh_done, MH_GO(2));
    uint64_t t_iso1 = mh_t1;
    printf("[8] Isolation: hart0 throttled=%u  hart1 free=%u cycles  (ok=%d)\r\n",
           (unsigned int)t_iso0, (unsigned int)t_iso1, iso_ok);

    tb_arm(0, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);
    mh_throttle = 1;
    FENCE();
    mh_go = MH_GO(3);
    FENCE();
    uint64_t t_dual0 = timed_reads(rd_buf);
    tb_en(0, 0);
    int dual_ok = mh_wait(&mh_done, MH_GO(3));
    uint64_t t_dual1 = mh_t1;
    printf("[9] Dual:      hart0 throttled=%u  hart1 throttled=%u cycles  (ok=%d)\r\n",
           (unsigned int)t_dual0, (unsigned int)t_dual1, dual_ok);
    uart_wait_tx_done();

    // [10] Data correctness: throttled writes + evict + throttled read-back must
    // return exactly what was written.
    tb_arm(0, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);
    for (unsigned i = 0; i < AW_COUNT; i++)
        wr_buf[i * STRIDE] = 0xA000ULL + i + 1;
    FENCE();
    l1_evict();                                                  // push dirty lines out via throttled AW
    uint32_t data_errors = verify_pattern(wr_buf, AW_COUNT, 0xA000ULL); // read back via throttled AR
    tb_en(0, 0);
    printf("[10] Data correctness (throttled RW)  = %u mismatches / %u words\r\n",
           data_errors, AW_COUNT);

    // [11] Concurrent AR+AW requests. AR_COST and AW_COST both nonzero, unlike other tests.
    tb_cfg(0, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);
    l1_evict();
    uint64_t t_mix_base = timed_mixed(rd_buf, mix_buf, AW_COUNT); //Base value

    tb_arm(0, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);
    uint64_t t_mix_thr = timed_mixed(rd_buf, mix_buf, AW_COUNT); //Throttled
    tb_en(0, 0);
    printf("[11] Mixed AR+AW: base=%u throttled=%u cycles\r\n",
           (unsigned int)t_mix_base, (unsigned int)t_mix_thr);

    // [12] TOKEN_LIMIT reconfig: live-widening the limit shrinks stall time
    // without ever disabling the bucket.
    uint32_t small_limit = 2U, large_limit = TOKEN_LIMIT * 4U;

    tb_arm(0, small_limit, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST);
    uint64_t t_lim_small = timed_reads(rd_buf);

    tb_reconfig(large_limit, REFILL_TOKENS, REFILL_INTERVAL); // TB_LIVE
    uint64_t t_lim_large = timed_reads(rd_buf);
    tb_en(0, 0);
    printf("[12] TOKEN_LIMIT reconfig: limit=%u -> %u  cycles=%u -> %u\r\n",
           small_limit, large_limit, (unsigned int)t_lim_small, (unsigned int)t_lim_large);

    // [13] REFILL_TOKENS reconfig: live-raising the refill rate shrinks stall time.
    uint32_t slow_refill = REFILL_TOKENS, fast_refill = REFILL_TOKENS * 4U;

    tb_arm(0, TOKEN_LIMIT, slow_refill, REFILL_INTERVAL, AR_COST, AW_COST);
    uint64_t t_refill_slow = timed_reads(rd_buf);

    tb_reconfig(TOKEN_LIMIT, fast_refill, REFILL_INTERVAL); // TB_LIVE
    uint64_t t_refill_fast = timed_reads(rd_buf);
    tb_en(0, 0);
    printf("[13] REFILL_TOKENS reconfig: refill=%u -> %u  cycles=%u -> %u\r\n",
           slow_refill, fast_refill, (unsigned int)t_refill_slow, (unsigned int)t_refill_fast);
    uart_wait_tx_done();

    //Overhead Calculations
    uint64_t oh_read_1x = (t_read_1x > t_base)  ? t_read_1x - t_base  : 0;
    uint64_t oh_read_2x = (t_read_2x > t_base)  ? t_read_2x - t_base  : 0;
    uint64_t oh_w1      = (t_w1 > t_wbase)      ? t_w1 - t_wbase      : 0;
    uint64_t oh_w2      = (t_w2 > t_wbase)      ? t_w2 - t_wbase      : 0;
    uint64_t oh_mix_thr = (t_mix_thr > t_mix_base) ? t_mix_thr - t_mix_base : 0;

    printf("\n--- Verification (threshold=%u) ---\r\n", THROTTLE_THRESHOLD);

    uint32_t errors = 0;
    int pass_cond;
    pass_cond = (oh_read_1x >= THROTTLE_THRESHOLD);
    printf("%s [A] read throttling adds overhead\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (oh_read_2x >= oh_read_1x + oh_read_1x / 2U);
    printf("%s [B] read rate scales with interval\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (t_release <= t_base * 2U);
    printf("%s [C] disabling restores speed\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (oh_w1 > 0);
    printf("%s [D] write (AW) throttling adds overhead\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (oh_w2 >= oh_w1 + oh_w1 / 2U);
    printf("%s [E] write rate scales with interval\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (iso_ok && alone_ok && t_iso1_alone > 0
        && t_iso0 >= THROTTLE_THRESHOLD
        && t_iso1 <= t_iso1_alone + t_iso1_alone / 2U);
    printf("%s [F] per-core isolation (hart1 unaffected by hart0)\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (dual_ok
        && t_dual0 >= THROTTLE_THRESHOLD
        && t_dual1 >= t_iso1_alone + t_iso1_alone / 2U);
    printf("%s [G] dual-core throttle (both harts slow)\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (data_errors == 0);
    printf("%s [H] data correctness preserved under throttle\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (oh_mix_thr >= THROTTLE_THRESHOLD);
    printf("%s [I] concurrent AR+AW throttling adds overhead\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (oh_mix_thr >= oh_w1);
    printf("%s [J] billing AR+AW together costs more than AW alone\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (t_lim_small > t_lim_large)
        && (t_lim_small - t_lim_large >= THROTTLE_THRESHOLD / 2U);
    printf("%s [K] TOKEN_LIMIT reconfig: wider limit cuts stall time\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    pass_cond = (t_refill_slow > t_refill_fast)
        && (t_refill_slow - t_refill_fast >= THROTTLE_THRESHOLD / 2U);
    printf("%s [L] REFILL_TOKENS reconfig: faster refill cuts stall time\r\n", pass_cond ? "PASS" : "FAIL");
    errors += !pass_cond;

    printf("\n=== Token Bucket Test: %s (%u error%s) ===\r\n",
           errors == 0 ? "PASSED" : "FAILED", errors, errors == 1 ? "" : "s");
    uart_wait_tx_done();
    return (int)errors;
}
