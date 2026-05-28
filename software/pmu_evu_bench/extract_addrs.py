#!/usr/bin/env python3
"""
Extract PC milestone addresses for both profiled functions from objdump output.

Outputs four #defines consumed by pmu_firmware/main.c:
  FUNC_ALU_ENTRY / FUNC_ALU_EXIT   — func_alu_chain (short, pure ALU)
  FUNC_COLD_ENTRY / FUNC_COLD_EXIT — func_l1_cold  (large, 512 cold loads)
"""

import sys
import re


# Map: function name → (entry_define, exit_define)
FUNCS = {
    "func_alu_chain": ("FUNC_ALU_ENTRY",  "FUNC_ALU_EXIT"),
    "func_l1_cold":   ("FUNC_COLD_ENTRY", "FUNC_COLD_EXIT"),
}


def find_func_body(text, func_name):
    """Return (entry_addr, exit_addr) for func_name, or (None, None)."""
    start_pat = rf"^([0-9a-fA-F]+)\s+<{re.escape(func_name)}>:"
    m = re.search(start_pat, text, re.MULTILINE)
    if not m:
        return None, None

    entry_addr = int(m.group(1), 16)
    body_start = m.end()

    # Delimit body: stop at the next function label
    next_func = re.search(r"^[0-9a-fA-F]+\s+<[^>]+>:", text[body_start:], re.MULTILINE)
    body = text[body_start: body_start + next_func.start()] if next_func else text[body_start:]

    # Exit = last ret or jr ra in the body
    ret_pat = r"^\s+([0-9a-fA-F]+):\s+[0-9a-fA-F]+\s+(?:ret|jr\s+ra)\b"
    rets = list(re.finditer(ret_pat, body, re.MULTILINE))
    exit_addr = int(rets[-1].group(1), 16) if rets else None

    return entry_addr, exit_addr


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <dump_file>", file=sys.stderr)
        sys.exit(1)

    dump_file = sys.argv[1]
    with open(dump_file) as f:
        text = f.read()

    print(f"// Auto-extracted from {dump_file}")
    print(f"// Re-generate with: python3 extract_addrs.py <binary>.dump > auto_func_addrs.h")
    print()

    ok = True
    for func_name, (entry_def, exit_def) in FUNCS.items():
        entry_addr, exit_addr = find_func_body(text, func_name)
        print(f"// PC milestone addresses for {func_name}")
        if entry_addr is not None:
            print(f"#undef  {entry_def}")
            print(f"#define {entry_def}   0x{entry_addr:08X}U  // {func_name} entry")
        else:
            print(f"// WARNING: {func_name} not found in dump — {entry_def} not set")
            ok = False

        if exit_addr is not None:
            print(f"#undef  {exit_def}")
            print(f"#define {exit_def}    0x{exit_addr:08X}U  // {func_name} ret")
        else:
            print(f"// WARNING: no ret found in {func_name} — {exit_def} not set")
            ok = False
        print()

    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
