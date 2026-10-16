# socket_dma — the accelerator socket's DMA from Linux

`socket_dma.c` drives slot 0 of the accelerator socket (the `example` engine) from Linux user space, the way a
driver would, and checks that the device and the CPU see each other's memory with no cache maintenance. It is the
end-to-end proof that a device plugged into the socket can do DMA against a running Linux.

The socket's memory port is a port of the coherence unit (`hardware/host/cva6_synth_wrap.sv`): reads are ACE
ReadOnce, writes WriteUnique, both snooped against the cores' write-back L1 data caches. The in-SoC measurement is
`software/soc_tests/t_dma`; this is its Linux counterpart.

## Build

```
make install      # builds static with the buildroot toolchain and copies to the rootfs overlay (/usr/bin/socket_dma)
```

`ALSAQR_SW` (default `~/alsaqr-software`) locates the toolchain
(`linux/cva6-sdk/buildroot/output/host/bin/riscv64-buildroot-linux-gnu-gcc`) and the overlay
(`linux/cva6-sdk/rootfs/usr/bin`). Rebuild the Linux image afterwards so the binary ships in the initramfs.

## Run

```
socket_dma [pool] [anon] [uio] [irq]      # default: all four
```

- **pool** — registers and buffers through `/dev/mem`, buffers in the reserved DMA pool (device tree
  `reserved-memory` node `dma-pool@9f000000`, 16 MB, physically contiguous).
- **anon** — buffers in ordinary process memory (one locked page each, physical address from
  `/proc/self/pagemap`): the kernel's cached RAM, as a driver's streaming mapping would hand it.
- **uio** — registers mapped through `/dev/uio0` (device tree node `accel-socket@10000000`, driver
  `uio_pdrv_genirq`) instead of `/dev/mem`.
- **irq** — completion by the interrupt (PLIC 9 through `/dev/uio0`, a blocking `read()`) instead of polling.

Each mode prints `SOCKET_DMA <mode> ok|FAIL ...` with the words that came out correct without any cache
maintenance, and the engine's cycle count. Exit code = number of failed modes.

## What Linux needs (alsaqr-software `linux/cva6-sdk`)

- Kernel config `configs/linux64_defconfig`: `CONFIG_UIO`, `CONFIG_UIO_PDRV_GENIRQ`, `CONFIG_PROC_PAGE_MONITOR`
  (for `/proc/self/pagemap`), and `CONFIG_VIRTIO_MMIO/BLK/CONSOLE/NET` for emulated I/O devices in a slot.
- Device tree `alsaqr-socket.dts`: the `generic-uio` node for the socket window, the `shared-dma-pool`
  reserved-memory region, and `uio_pdrv_genirq.of_id=generic-uio` in `bootargs`.
- The loader must pass that device tree to OpenSBI in `a1` (the boot ROM leaves its own built-in DTB there);
  alsaqr-mcp `linux_boot` does this.

A kernel driver gets the same coherent DMA with `dma_alloc_coherent` (from the pool when its node names it in
`memory-region`) or `dma_map_single`, with no `dma_sync` cost, because the hardware is coherent.
