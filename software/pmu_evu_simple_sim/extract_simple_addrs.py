#!/usr/bin/env python3
"""Extract synthetic function addresses from objdump output.

Also outputs FUNC_ENTRY / FUNC_EXIT for func_l1_cold (the profiled function)
so the Ibex firmware and CVA6 poll-condition can be updated automatically.
"""

import sys
import re

FUNCTIONS = [
    "func_seq_loads",
    "func_seq_stores",
    "func_alu_only",
    "func_branch_taken",
    "func_l1_cold",
    "func_l1_warm",
]

# The function whose entry/exit we track with the PC milestone
MILESTONE_FUNC = "func_l1_cold"


def find_func_exit(text, func_name):
    """Return the address of the last ret/jr-ra instruction in func_name's body."""
    start_pattern = rf"^([0-9a-fA-F]+)\s+<{re.escape(func_name)}>:"
    start_match = re.search(start_pattern, text, re.MULTILINE)
    if not start_match:
        return None

    body_start = start_match.end()

    # Slice to the next function label (or EOF)
    next_func = re.search(r"^[0-9a-fA-F]+\s+<[^>]+>:", text[body_start:], re.MULTILINE)
    func_body = text[body_start: body_start + next_func.start()] if next_func else text[body_start:]

    # Match all ret / jr ra instructions; take the last one
    ret_pat = r"^\s+([0-9a-fA-F]+):\s+[0-9a-fA-F]+\s+(?:ret|jr\s+ra)\b"
    matches = list(re.finditer(ret_pat, func_body, re.MULTILINE))
    return int(matches[-1].group(1), 16) if matches else None


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <dump_file>", file=sys.stderr)
        sys.exit(1)

    dump_file = sys.argv[1]
    with open(dump_file) as f:
        text = f.read()

    print(f"// Auto-extracted from {dump_file}")
    print(f"// Re-generate with: python3 extract_simple_addrs.py <binary>.dump > auto_func_addrs.h")
    print()

    found = 0
    for func in FUNCTIONS:
        pattern = rf"^([0-9a-fA-F]+)\s+<{re.escape(func)}>:"
        match = re.search(pattern, text, re.MULTILINE)
        if match:
            addr_int = int(match.group(1), 16)
            print(f"#define ADDR_{func.upper():<35s} 0x{addr_int:08X}")
            found += 1
        else:
            print(f"// WARNING: {func} not found in dump!")

    print(f"// {found}/{len(FUNCTIONS)} ADDR_ defines found")
    print()

    # PC milestone entry/exit for the profiled function
    entry_pat = rf"^([0-9a-fA-F]+)\s+<{re.escape(MILESTONE_FUNC)}>:"
    entry_match = re.search(entry_pat, text, re.MULTILINE)
    if entry_match:
        entry_addr = int(entry_match.group(1), 16)
        exit_addr  = find_func_exit(text, MILESTONE_FUNC)

        print(f"// PC milestone addresses for {MILESTONE_FUNC}")
        print(f"// Used by: pmu_firmware/main.c (FUNC_ENTRY/FUNC_EXIT)")
        print(f"//          pmu_simple_bench.c  (poll condition on PC_MILESTONE_SLOT0)")
        print(f"#undef  FUNC_ENTRY")
        print(f"#define FUNC_ENTRY  0x{entry_addr:08X}U  // {MILESTONE_FUNC} entry")
        if exit_addr:
            print(f"#undef  FUNC_EXIT")
            print(f"#define FUNC_EXIT   0x{exit_addr:08X}U  // {MILESTONE_FUNC} ret")
        else:
            print(f"// WARNING: no ret found in {MILESTONE_FUNC} body")
    else:
        print(f"// WARNING: {MILESTONE_FUNC} not found — FUNC_ENTRY/FUNC_EXIT not set")


if __name__ == "__main__":
    main()
