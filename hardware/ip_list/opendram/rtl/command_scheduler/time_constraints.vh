`define USE_SEPARATE_INTER_INTRA_TABLES

//-----------------------------------------------------------------------------
// Copyright (C) 2025 McMaster University, University of Waterloo
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

`define     BL          64
`define     tCK         13.28 // not used anywhere
`define     tAL         0
`define     tCL         288
`define     tCWL        192
`define     tRCD        256
`define     tRP         256
`define     tRAS        624
`define     tRC         976
`define     tRFC        5008 // not used anywhere
`define     tRFC2       4992 // not used anywhere
`define     tRFC4       3072 // not used anywhere
`define     tREFI       149808 // not used anywhere
`define     tPRE        16
`define     tWTR_L      160
`define     tFAW        640
`define     tWR         320
`define     tCCD_S      64
`define     tCCD_L      96
`define     tCKE        96
`define     tCKESR      112
`define     tXS         6912 // not used anywhere
`define     tXP         128        
`define     tRTRS       0

`ifdef OMIT_TFAW_COUNTER
    `define     tRRD_S      (`tFAW + 1) / 4
    `define     tRRD_L      (`tFAW + 1) / 4
`else
    `define     tRRD_S      112
    `define     tRRD_L      128
`endif // `ifdef OMIT_TFAW_COUNTER

`ifdef USE_SEPARATE_INTER_INTRA_TABLES
    `define     tWTR_S      (`tWTR_L - `tCCD_S)
    `ifdef OMIT_TRAS_COUNTER
        `define     tRTP        (`tRAS - (`tRCD - `tAL))
    `else
        `define     tRTP        160
    `endif // `ifdef OMIT_TRAS_COUNTER
`else
    `define     tWTR_S      64
    `define     tRTP        160
`endif // `ifdef USE_SEPARATE_INTER_INTRA_TABLES
