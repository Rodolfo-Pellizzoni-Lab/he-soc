/* Wrapper to embed PMU text section binary */
.section .rodata
.global _binary_text_section_bin_start
.global _binary_text_section_bin_end
.global _binary_text_section_bin_size
.align 8

_binary_text_section_bin_start:
.incbin "text_section.bin"
_binary_text_section_bin_end:

.align 8
_binary_text_section_bin_size:
.quad _binary_text_section_bin_end - _binary_text_section_bin_start
