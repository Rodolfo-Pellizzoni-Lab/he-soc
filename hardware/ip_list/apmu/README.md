# Advanced Performance Monitoring Unit
This is the RISC-V implementation of the APMU design specification.

# Important:
1. The RTL for the APMU might seem a little confusing, because it relies heavily on C-like constructs: struct, union, etc. That is because the AXI4-lite-based read and writes to the APMU are handled by the axi_lite_regs IP (which was developed independently by Al Saqr). Therefore, to understand the `pmu_top.sv`, please also study the RTL for this IP and the `axi_llc_config.sv` module in `axi_llc` because the APMU is designed in a very similar fashion.

2. The APMU currently has the following memory map (given below). Here, each counter and its associated registers are placed in a separate page, spaced at 4kB boundary (0x1000).
   | Register Name 	| Address    	| Page   	|
   |---------------	|------------	|--------	|
   | Timer         	| 0x10405000 	|    -   	|
   | Period Reg    	| 0x10405008 	|    -   	|
   | Status Reg    	| 0x10406000 	|    -   	|
   | Boot Addr Reg 	| 0x10406004 	|    -   	|
   | Counter 0     	| 0x10407000 	| Page 0 	|
   | Event Sel 0   	| 0x10407004 	| Page 0 	|
   | Event Info 0  	| 0x10407008 	| Page 0 	|
   | Info Budget 0 	| 0x1040700C 	| Page 0 	|
   | Counter 1     	| 0x10408000 	| Page 1 	|
   | Event Sel 1   	| 0x10408004 	| Page 1 	|
   | Event Info 1  	| 0x10408008 	| Page 1 	|
   | Info Budget 1 	| 0x1040800C 	| Page 1 	|
   |     ...        	|     ...    	|   ...    	|

3. 

# To Do:
1. Update the APMU memory map such that all counters are spaced at 4kB boundaries, but all their configuration registers are placed together.
2. Fix the address remapping such that is completely generalizable based on a APMU_BASE_ADDR parameter.
   **Context**
   All APMU counters and co. (counters, timers, status, boot addr registers, etc.) are spaced at 4kB (0x1000) address boundaries. So, if we are looking at one counter, we effectively have: one counter, its two configuration registers, and an info-budget register. So, four 32-bit registers, amounting to 64B. The remaining 3936B (0xFC0) of space is not needed / does not exist.
   
   But the axi_lite_regs IP only expects a contiguous array of bytes, something like:
   ```
   Byte 3 : 0    - Timer
   Byte 7 : 4    - Period Reg
   Byte 11: 8    - Status Reg
   Byte 15:12    - Boot Addr Reg
   Byte 19:16    - Counter 0
   Byte 23:20    - Event Sel 0
   Byte 27:24    - Event Info 0
   ....
   ```

   So, we need to have some logic that maps the APMU address to a contiguous byte mapping. Remember that both timers are 64-bit or 8B wide.
   | Bytes 	| Register Name 	| Address    	| Page   	|
   |-------	|---------------	|------------	|--------	|
   | 7:0   	| Timer         	| 0x10405000 	|    -   	|
   | 15:8  	| Period Reg    	| 0x10405008 	|    -   	|
   | 19:16	| Status Reg    	| 0x10406000 	|    -   	|
   | 23:20 	| Boot Addr Reg 	| 0x10406004 	|    -   	|
   | 27:24 	| Counter 0     	| 0x10407000 	| Page 0 	|
   | 31:28 	| Event Sel 0   	| 0x10407004 	| Page 0 	|
   | 35:32 	| Event Info 0  	| 0x10407008 	| Page 0 	|
   | 39:36 	| Info Budget 0 	| 0x1040700C 	| Page 0 	|
   | 43:40 	| Counter 1     	| 0x10408000 	| Page 1 	|
   | 47:44 	| Event Sel 1   	| 0x10408004 	| Page 1 	|
   | 51:48 	| Event Info 1  	| 0x10408008 	| Page 1 	|
   | 55:52 	| Info Budget 1 	| 0x1040800C 	| Page 1 	|
   |  ...  	|   ...           |     ...    	|   ...    	|

   To make the logic for remapping simpler, we added some unused padding bytes as follows:
   | Bytes 	   | Register Name 	| Address    	| Page   	|
   |---------	|---------------	|------------	|--------	|
   | 79:0      | Unused (Padding)| 0x10400000   |    -      |
   | 87:80     | Timer         	| 0x10405000 	|    -   	|
   | 95:88     | Period Reg    	| 0x10405008 	|    -   	|
   | 103:96 	| Status Reg    	| 0x10406000 	|    -   	|
   | 107:104   | Boot Addr Reg 	| 0x10406004 	|    -   	|
   | 111:108   | Unused (Padding)| 0x10406008   |    -      |
   | 115:112   | Counter 0     	| 0x10407000 	| Page 0 	|
   | 119:116 	| Event Sel 0   	| 0x10407004 	| Page 0 	|
   | 123:120 	| Event Info 0  	| 0x10407008 	| Page 0 	|
   | 127:124 	| Info Budget 0 	| 0x1040700C 	| Page 0 	|
   | 131:128 	| Counter 1     	| 0x10408000 	| Page 1 	|
   | 135:132 	| Event Sel 1   	| 0x10408004 	| Page 1 	|
   | 139:136 	| Event Info 1  	| 0x10408008 	| Page 1 	|
   | 143:140 	| Info Budget 1 	| 0x1040800C 	| Page 1 	|
   |  ...  	   |   ...           |     ...    	|   ...    	|
   | 387:384   |  Counter 17   	| 0x10418000  	| Page 31  	|
   |  ...  	   |   ...           |     ...    	|   ...    	|
   | 611:608   |  Counter 31   	| 0x10426000  	| Page 31  	|

   So, what's the trick?
   Convert the starting byte number for each register into Hexadecimal and voila!
   ```
   d'80  = 0x50
   d'88  = 0x58
   d'108 = 0x6C
   d'116 = 0x74
   d'384 = 0x180
   d'608 = 0x260
   ...
   ```
   Do you see it yet?
   
   Basically, if the address of a APMU register is 0x104**X**_**Y**00**Z**. It maps to a set of bytes starting with byte number XYZ. This is very easy to implement in SystemVerilog as all we are doing is shifting bits.

   **What needs to be done?**
   Right now, the size of the padding bytes is calculated manually depending on what the APMU base address is. In an earlier project version, the base address was 0x1040_4000, so the padding size was 64B. As `d'64 = 0x40`. Now, the address is 0x1040_5000, so we have a padding of 80B. Make this calculation dynamic.

   Update the `PadB_NumBytes` localparam in `pmu_top.sv`.
      
4. Remove the period register and the info budget registers as they are not needed anymore. 
