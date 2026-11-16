/*
 * System-level token bucket throttle verification.
 *
 * Drives real CVA6 AXI traffic (L1 misses -> AR, dirty L1 write-backs -> AW) through
 * the per-core token bucket. Each step flushes L1 (fence.i), lets the bucket fill,
 * then times N transactions and checks the time against the configured rate.
 *
 * [1-4] reads: baseline, throttled, interval x2, release; [5-7] writes: baseline,
 * throttled, interval x2; [8] hart1 unaffected by hart0's bucket; [9] data correctness; [10-11] live TOKEN_LIMIT and
 * REFILL_TOKENS reconfig.
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
#define COUNT           64U   // transactions per timed run

#define HART1           1U
#define MH_READY        0x600D0000U
#define MH_GO(r)        (MH_READY + (r))
#define MH_BOOT_TIMEOUT 100000000ULL  // cycles; hart1 reaches main ~15M cycles after hart0 on the board
#define MH_RUN_TIMEOUT  2000000ULL

static volatile uint64_t rd_buf[COUNT * STRIDE] __attribute__((aligned(64)));
static volatile uint64_t wr_buf[COUNT * STRIDE] __attribute__((aligned(64)));
static volatile uint64_t mh_buf[COUNT * STRIDE] __attribute__((aligned(64)));

__attribute__ ((section(".heapl2ram"))) volatile uint32_t mh_go   = 0;
__attribute__ ((section(".heapl2ram"))) volatile uint32_t mh_done = 0;
__attribute__ ((section(".heapl2ram"))) volatile uint64_t mh_t1   = 0;

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

// Writes back and invalidates the whole L1 D$ (thrashing can't: victims are picked by LFSR).
static inline void l1_flush(void)
{
    asm volatile("fence.i" ::: "memory");
}

// Flush + configure + (enable) + settle. on=0 keeps the current enable state (live reconfig).
static void tb_arm(uint32_t limit, uint32_t refill, uint32_t interval,
                   uint32_t ar, uint32_t aw, int on)
{
    tb_cfg(0, limit, refill, interval, ar, aw);
    l1_flush();
    if (on) tb_en(0, 1);
    tb_settle(limit, refill, interval);
}

// Least time n transactions can take from a full bucket; one interval of slack
// for refill phase, one for the bucket's one-cost debt.
static uint64_t min_cycles(uint32_t n, uint32_t limit, uint32_t refill, uint32_t interval)
{
    uint32_t refills = (n > limit) ? (n - limit + refill - 1U) / refill : 0U;
    return (refills > 2U) ? (uint64_t)(refills - 2U) * interval : 0U;
}

// COUNT L1 misses -> COUNT ARs.
static uint64_t timed_reads(volatile uint64_t *p)
{
    uint64_t t0 = read_csr(mcycle);
    for (unsigned i = 0; i < COUNT; i++)
        (void)p[i * STRIDE];
    return read_csr(mcycle) - t0;
}

// COUNT store misses, then the flush writes the COUNT dirty lines back -> COUNT AWs.
static uint64_t timed_writes(volatile uint64_t *p, uint64_t base)
{
    uint64_t t0 = read_csr(mcycle);
    for (unsigned i = 0; i < COUNT; i++)
        p[i * STRIDE] = base + i + 1;
    l1_flush();
    return read_csr(mcycle) - t0;
}

static int mh_wait(volatile uint32_t *flag, uint32_t val, uint64_t timeout)
{
    uint64_t t0 = read_csr(mcycle);
    while (read_csr(mcycle) - t0 < timeout)
        if (*flag == val) return 1;
    return 0;
}

// Two rounds of timed reads, each started by hart0 through mh_go.
static void run_hart1(void)
{
    mh_done = MH_READY;
    for (uint32_t round = 1; round <= 2U; round++) {
        while (mh_go != MH_GO(round));
        l1_flush();
        mh_t1 = timed_reads(mh_buf);
        mh_done = MH_GO(round);
    }
    while (1) asm volatile("wfi");
}

int thread_entry(int cid, int nc){
  return 0;
}

static uint32_t check(int ok, const char *what)
{
    printf("%s %s\r\n", ok ? "PASS" : "FAIL", what);
    return !ok;
}

int main(int argc, char const *argv[]){
    uint32_t mhartid;
    asm volatile("csrr %0, 0xF14\n" : "=r"(mhartid));
    if (mhartid == HART1) { run_hart1(); }
    if (mhartid != 0)     { while (1) asm volatile("wfi"); }

#ifndef FPGA_EMULATION
    uint32_t baud_rate = 115200, test_freq = 50000000;
    uart_set_cfg(0, (test_freq / baud_rate) >> 4);
#endif

    printf("=== Token Bucket Throttle Test ===\r\n");
    printf("count=%u limit=%u refill=%u/%u\r\n", COUNT, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL);
    uart_wait_tx_done();

    // Reads: AR_COST only.
    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 0);
    uint64_t t_base = timed_reads(rd_buf);
    printf("[1] Read baseline (disabled)   = %u cycles\r\n", (unsigned int)t_base);

    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 1);
    uint64_t t_read_1x = timed_reads(rd_buf);
    printf("[2] Read x1  (interval=%u)    = %u cycles\r\n", REFILL_INTERVAL, (unsigned int)t_read_1x);

    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL * 2U, AR_COST, AW_COST, 0); // live
    uint64_t t_read_2x = timed_reads(rd_buf);
    printf("[3] Read x2  (interval=%u)   = %u cycles\r\n", REFILL_INTERVAL * 2U, (unsigned int)t_read_2x);
    tb_en(0, 0);

    l1_flush();
    uint64_t t_release = timed_reads(rd_buf);
    printf("[4] Release  (disabled)        = %u cycles\r\n", (unsigned int)t_release);

    // Writes: AR is free so only the AWs are billed.
    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, 0U, AW_COST, 0);
    uint64_t t_wbase = timed_writes(wr_buf, 0);
    printf("[5] Write baseline (disabled)  = %u cycles\r\n", (unsigned int)t_wbase);

    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, 0U, AW_COST, 1);
    uint64_t t_w1 = timed_writes(wr_buf, 0);
    printf("[6] Write x1 (interval=%u)    = %u cycles\r\n", REFILL_INTERVAL, (unsigned int)t_w1);

    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL * 2U, 0U, AW_COST, 0); // live
    uint64_t t_w2 = timed_writes(wr_buf, 0);
    tb_en(0, 0);
    printf("[7] Write x2 (interval=%u)   = %u cycles\r\n", REFILL_INTERVAL * 2U, (unsigned int)t_w2);
    uart_wait_tx_done();

    // [8] Isolation: hart1 times the same reads alone, then while hart0 is throttled.
    int h1_ok = mh_wait(&mh_done, MH_READY, MH_BOOT_TIMEOUT);
    mh_go = MH_GO(1);
    h1_ok = h1_ok && mh_wait(&mh_done, MH_GO(1), MH_RUN_TIMEOUT);
    uint64_t t_h1_alone = mh_t1;

    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 1);
    mh_go = MH_GO(2);
    uint64_t t_iso0 = timed_reads(rd_buf);
    tb_en(0, 0);
    h1_ok = h1_ok && mh_wait(&mh_done, MH_GO(2), MH_RUN_TIMEOUT);
    uint64_t t_iso1 = mh_t1;
    printf("[8] Isolation: hart1 alone=%u  hart0 throttled=%u  hart1 meanwhile=%u cycles  (ok=%d)\r\n",
           (unsigned int)t_h1_alone, (unsigned int)t_iso0, (unsigned int)t_iso1, h1_ok);

    // [9] Data correctness: throttled writes + write-back + throttled read-back, AR and AW both billed.
    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 1);
    (void)timed_writes(wr_buf, 0xA000ULL);
    uint32_t data_errors = 0;
    for (unsigned i = 0; i < COUNT; i++)
        if (wr_buf[i * STRIDE] != 0xA000ULL + i + 1) data_errors++;
    tb_en(0, 0);
    printf("[9] Data correctness           = %u mismatches / %u words\r\n", data_errors, COUNT);

    // [10] TOKEN_LIMIT: a deeper bucket lets more reads through before stalling.
    uint32_t small_limit = 2U, large_limit = TOKEN_LIMIT * 4U;
    tb_arm(small_limit, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 1);
    uint64_t t_lim_small = timed_reads(rd_buf);
    tb_arm(large_limit, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 0); // live
    uint64_t t_lim_large = timed_reads(rd_buf);
    printf("[10] TOKEN_LIMIT %u -> %u        = %u -> %u cycles\r\n",
           small_limit, large_limit, (unsigned int)t_lim_small, (unsigned int)t_lim_large);

    // [11] REFILL_TOKENS: more tokens per interval shortens the stall.
    uint32_t fast_refill = REFILL_TOKENS * 4U;
    tb_arm(TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL, AR_COST, AW_COST, 0); // live
    uint64_t t_refill_slow = timed_reads(rd_buf);
    tb_arm(TOKEN_LIMIT, fast_refill, REFILL_INTERVAL, AR_COST, AW_COST, 0);   // live
    uint64_t t_refill_fast = timed_reads(rd_buf);
    tb_en(0, 0);
    printf("[11] REFILL_TOKENS %u -> %u      = %u -> %u cycles\r\n",
           REFILL_TOKENS, fast_refill, (unsigned int)t_refill_slow, (unsigned int)t_refill_fast);
    uart_wait_tx_done();

    uint64_t min_1x = min_cycles(COUNT, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL);
    uint64_t min_2x = min_cycles(COUNT, TOKEN_LIMIT, REFILL_TOKENS, REFILL_INTERVAL * 2U);
    // Expected saving of each reconfig; half of it must show.
    uint64_t save_lim    = (uint64_t)(large_limit - small_limit) * REFILL_INTERVAL;
    uint64_t save_refill = min_1x - min_cycles(COUNT, TOKEN_LIMIT, fast_refill, REFILL_INTERVAL);

    printf("\n--- Verification (min cycles: x1=%u x2=%u) ---\r\n",
           (unsigned int)min_1x, (unsigned int)min_2x);

    uint32_t errors = 0;
    errors += check(t_base < min_1x / 2U && t_read_1x >= min_1x, "[A] reads are throttled to the AR rate");
    errors += check(t_read_2x >= min_2x,                          "[B] read rate follows REFILL_INTERVAL");
    errors += check(t_release <= t_base * 2U,                     "[C] disabling restores speed");
    errors += check(t_wbase < min_1x / 2U && t_w1 >= min_1x,     "[D] writes are throttled to the AW rate");
    errors += check(t_w2 >= min_2x,                               "[E] write rate follows REFILL_INTERVAL");
    errors += check(h1_ok && t_h1_alone > 0 && t_iso0 >= min_1x
                    && t_iso1 <= t_h1_alone + t_h1_alone / 2U,    "[F] hart1 unaffected by hart0's bucket");
    errors += check(data_errors == 0,                             "[G] data correct under throttle");
    errors += check(t_lim_small >= t_lim_large + save_lim / 2U,   "[H] deeper TOKEN_LIMIT cuts stall time");
    errors += check(t_refill_slow >= t_refill_fast + save_refill / 2U, "[I] larger REFILL_TOKENS cuts stall time");

    printf("\n=== Token Bucket Test: %s (%u error%s) ===\r\n",
           errors == 0 ? "PASSED" : "FAILED", errors, errors == 1 ? "" : "s");
    uart_wait_tx_done();
    return (int)errors;
}
