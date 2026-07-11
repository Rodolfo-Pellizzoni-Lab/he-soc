/* Wrapper to embed PMU data section binary */
.section .rodata
.global _binary_data_rodata_bss_bin_start
.global _binary_data_rodata_bss_bin_end
.global _binary_data_rodata_bss_bin_size
.align 8

_binary_data_rodata_bss_bin_start:
.incbin "data_rodata_bss.bin"
_binary_data_rodata_bss_bin_end:

.align 8
_binary_data_rodata_bss_bin_size:
.quad _binary_data_rodata_bss_bin_end - _binary_data_rodata_bss_bin_start
