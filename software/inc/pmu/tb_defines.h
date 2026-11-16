// =============================================================================
// Token Bucket Register Map
//
// Start Address: 0x1060_7000
// End Address: 0x1060_8000 (4 KB page; NumCVA6 * 32 bytes used)
//
// One axi_lite_regs block for all cores (hardware/ip_list/token_bucket/src/token_bucket_cfg_regs.sv).
//
// Per-core register map (byte offsets within each CoreBytes window):
//   +0x00  TOKEN_LIMIT      |  bucket depth (max tokens)
//   +0x04  REFILL_TOKENS    |  tokens added per refill interval
//   +0x08  REFILL_INTERVAL  |  refill period in cycles
//   +0x0C  AW_COST          |  tokens consumed per AW transaction
//   +0x10  AR_COST          |  tokens consumed per AR transaction
//   +0x14  CTRL             |  1-bit enable. CTRL[0]; CTRL[31:8] read-only 0
//   +0x18  reserved         |  read-only 0
//   +0x1C  reserved         |  read-only 0
//   (CoreBytes = 32; +0x20 starts next core's window)
// =============================================================================

#ifndef TB_DEFINES_H
#define TB_DEFINES_H

#define TB_CFG_BASE_ADDR        0x10607000UL
#define TB_CORE_BYTES           32

#define TOKEN_LIMIT_OFFSET      0x00
#define REFILL_TOKENS_OFFSET    0x04
#define REFILL_INTERVAL_OFFSET  0x08
#define AW_COST_OFFSET          0x0C
#define AR_COST_OFFSET          0x10
#define CTRL_OFFSET             0x14

// Reset defaults (from token_bucket_cfg_regs.sv CORE_RST)
#define RST_TOKEN_LIMIT         256
#define RST_REFILL_TOKENS       1
#define RST_REFILL_INTERVAL     100
#define RST_AW_COST             1
#define RST_AR_COST             1
#define RST_CTRL                0

#define CTRL_ENABLE             0x1
#define CTRL_DISABLE            0x0

#endif // TB_DEFINES_H
