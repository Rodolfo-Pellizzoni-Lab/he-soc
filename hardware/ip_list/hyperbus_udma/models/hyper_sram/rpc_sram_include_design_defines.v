/**************************************************************************
* Copyright (C)2013-2014 Spansion LLC All Rights Reserved. 
*
* This source code is owned and published by: 
* Spansion LLC 915 DeGuigne Dr. Sunnyvale, CA  94088-3453 ("Spansion").
*
* BY INSTALLING OR USING THIS HYPERBUS MASTER CONTROLLER RTL SOURCE CODE, 
* YOU AGREE TO BE BOUND BY ALL THE TERMS AND CONDITIONS SET FORTH IN SPANSION 
* LICENSE AGREEMENT AND BELOW.
*
* This source code is licensed by Spansion to be adapted only 
* for use in the development of HyperBus Master Controller. Spansion is not
* responsible for misuse or illegal use of this source code.  Spansion is 
* providing this source code "AS IS" and will not be responsible for issues 
* arising from incorrect user implementation of the source code herein.  
*
* SPANSION MAKES NO WARRANTY, EXPRESS OR IMPLIED, ARISING BY LAW OR OTHERWISE, 
* REGARDING THE SOURCE CODE, ITS PERFORMANCE OR SUITABILITY FOR YOUR INTENDED 
* USE, INCLUDING, WITHOUT LIMITATION, NO IMPLIED WARRANTY OF MERCHANTABILITY, 
* FITNESS FOR A  PARTICULAR PURPOSE OR USE, OR NONINFRINGEMENT.  SPANSION WILL 
* HAVE NO LIABILITY (WHETHER IN CONTRACT, WARRANTY, TORT, NEGLIGENCE OR 
* OTHERWISE) FOR ANY DAMAGES ARISING FROM USE OR INABILITY TO USE THE SOURCE CODE, 
* INCLUDING, WITHOUT LIMITATION, ANY DIRECT, INDIRECT, INCIDENTAL, 
* SPECIAL, OR CONSEQUENTIAL DAMAGES OR LOSS OF DATA, SAVINGS OR PROFITS, 
* EVEN IF SPANSION HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.  
*
* This source code may be replicated in part or whole for the licensed use, 
* with the restriction that this Copyright notice must be included with 
* this source code, whether used in part or whole, at all times.  
*/
//////////////////////////////////////////////////////////////////////////////
//  File name : rpc_sram_include_design_defines.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////

//----------------------------------
// RPC Gen Market
//----------------------------------
`define ADDR_BITS  25
`define PAGE_ADDR_BITS  22
`define WORD_ADDR_BITS  3

//----------------------------------
// Command/Address Bit Assignments
//----------------------------------
`define CA0_RW_ADDR_LSB      15
`define CA0_TARGET_LSB       14
`define CA0_BURST_TYPE_LSB   13

`define CA0_PAGE_ADDR_BITS   6  // MSB + LSB + 1
`define CA0_PAGE_ADDR_LSB    0
`define CA0_PAGE_ADDR_MSB    5

`define CA1_PAGE_ADDR_BITS   16
`define CA1_PAGE_ADDR_LSB    0
`define CA1_PAGE_ADDR_MSB    15

`define CA2_WORD_ADDR_LSB    0
`define CA2_WORD_ADDR_MSB    2

`define MIN_READ_LATENCY    5


`define ADDR_8_WORD_BITS   3
`define ADDR_16_WORD_BITS  4
`define ADDR_32_WORD_BITS  5

`define BURST_LENGTH_BITS  2

`define BURST_LENGTH_64B   2'b01
`define BURST_LENGTH_16B   2'b10
`define BURST_LENGTH_32B   2'b11

`ifdef FPGA
//`define CORE_MEM_ADDR_BITS 13
`define CORE_MEM_ADDR_BITS 12  //8KB
`else
`define CORE_MEM_ADDR_BITS 25
`endif

`define READ_LATENCY_BITS  4
