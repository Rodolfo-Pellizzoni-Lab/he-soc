# Simulation Models

## Vendor Specific Peripherals

- `hyper_sram`: HyperBus generic model
- `s26ks512s`: Cypress, HyperBus flash model (16/32/64 MByte)
- `s27ks0641`: Cypress, HyperBus pseudo SRAM model/self-refresh DRAM (8/16 MByte)
- `s25fs256s`: Cypress, QuadSPI flash (16/32 MByte)
- `24xx1025`: Microchip, I2C EEPROM

## Generic Delay

- `generic_delay_D4_O1_3P750_CG0.behav.sv`: Delay macro with 4-bit delay control, 1 output, 3,75 ns total delay, no clock gate
