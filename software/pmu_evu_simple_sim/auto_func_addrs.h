// Auto-extracted from pmu_simple_bench.dump
// Re-generate with: python3 extract_simple_addrs.py <binary>.dump > auto_func_addrs.h

// WARNING: func_seq_loads not found in dump!
// WARNING: func_seq_stores not found in dump!
// WARNING: func_alu_only not found in dump!
// WARNING: func_branch_taken not found in dump!
#define ADDR_FUNC_L1_COLD                        0x8000318E
// WARNING: func_l1_warm not found in dump!
// 1/6 ADDR_ defines found

// PC milestone addresses for func_l1_cold
// Used by: pmu_firmware/main.c (FUNC_ENTRY/FUNC_EXIT)
//          pmu_simple_bench.c  (poll condition on PC_MILESTONE_SLOT0)
#undef  FUNC_ENTRY
#define FUNC_ENTRY  0x8000318EU  // func_l1_cold entry
#undef  FUNC_EXIT
#define FUNC_EXIT   0x800031A4U  // func_l1_cold ret
