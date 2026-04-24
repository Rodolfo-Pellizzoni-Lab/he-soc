// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "apb/assign.svh"
`include "apb/typedef.svh"

// Author: Luca Valente <luca.valente@unibo.it>
  
/// Testbench for APB FLL Interface
module apb_fll_tb #(
    parameter int unsigned APB_ADDR_WIDTH = 12,
    parameter int unsigned NR_FLLS        = 3
);

   localparam int unsigned RTC_CLOCK_PERIOD = 30.517us;
   localparam time SYS_TA   = 1ns;
   localparam time SYS_TT   = 2ns;

   localparam int unsigned ApbAddrWidth      = 32;
   localparam int unsigned ApbDataWidth      = 32;
   localparam int unsigned ApbStrbWidth      = 4;
   localparam int unsigned RegDataWidth      = 32;
   localparam int unsigned NoApbRegs         = 12;   
   localparam logic [NoApbRegs-1:0] ReadOnly = 12'h001; 
   
   typedef logic [ApbAddrWidth-1:0] apb_addr_t;
   typedef logic [ApbDataWidth-1:0] apb_data_t;
   typedef logic [ApbStrbWidth-1:0] apb_strb_t;
   typedef logic [RegDataWidth-1:0] reg_data_t;

   localparam apb_addr_t BaseAddr      = 32'h1A10_0000;
   localparam apb_addr_t TestStartAddr = 32'h1A10_0000;
   localparam apb_addr_t TestEndAddr   = 32'h1A10_0030;

   logic [3:0]  clk;
   logic rst_n;
   logic ref_clk;
   integer f1, f2, f3, f4;
   
    APB #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb(
                );
    FLL_BUS fll_intf(
                     .clk_i(clk[0])
                     );
    APB_DV #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_dv(
                  .clk_i(clk[0])
                  );
   
    typedef apb_test::apb_driver #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .TA(SYS_TA), .TT(SYS_TT)) apb_drv_t;
    apb_drv_t apb_master = new(apb_dv);
    `APB_ASSIGN(apb,apb_dv)

    apb_to_fll #(
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH )
    ) i_apb_fll_if (
        .clk_i     ( clk[0]   ),
        .rst_ni    ( rst_n    ),
        .apb       ( apb      ),
        .fll_intf  ( fll_intf )
    );

    gf22_FLL i_gf22_fll (
        // Clock & reset
        .OUTCLK(clk), // FLL clock outputs
        .REFCLK(ref_clk), // Reference clock input
        .RSTB(rst_n),   // Asynchronous reset (active low)
        .CFGREQ(fll_intf.req), // CFG I/F access request (active high)
        .CFGACK(fll_intf.ack), // CFG I/F access granted (active high)
        .CFGAD(fll_intf.addr),  // CFG I/F address bus
        .CFGD(fll_intf.wdata),   // CFG I/F input data bus (write)
        .CFGQ(fll_intf.rdata),   // CFG I/F output data bus (read)
        .CFGWEB(fll_intf.web), // CFG I/F write enable (active low)
        .PWD(1'b0),   // Asynchronous power down (active high)
        .RET(1'b0),    // Asynchronous retention/isolation control (active high)
        .TM(1'b0),     // Test mode (active high)
        .TE(1'b0),     // Scan enable (active high)
        .TD('0),     // Scan data input for chain 1:4
        .TQ(),     // Scan data output for chain 1:4
        .JTD(1'b0),    // Scan data in 5
        .JTQ()     // Scan data out 5
        );

   
    initial begin
        ref_clk = 1'b0;
        rst_n = 1'b0;
        repeat (8)
            #(RTC_CLOCK_PERIOD/2) ref_clk = 1'b0;

        rst_n = 1'b1;
        forever
            #(RTC_CLOCK_PERIOD/2) ref_clk = ~ref_clk;
    end

   
    initial begin
       automatic realtime   t0, t1;
       f1 = $fopen ("f1.txt","w");
       forever begin
          @(posedge clk[0]);
          t0=$time;
          @(posedge clk[0]);
          t1=$time;
   
          $fwrite(f1,"%f, %f\n", t0, (1000/(t1-t0)));
       end
    end   
    initial begin
       automatic realtime   t0, t1;
       f2 = $fopen ("f2.txt","w");
       forever begin
          @(posedge clk[1]);
          t0=$time;
          @(posedge clk[1]);
          t1=$time;
   
          $fwrite(f2,"%f, %f\n", t0, (1000/(t1-t0)));
       end
    end   
    initial begin
       automatic realtime   t0, t1;
       f3 = $fopen ("f3.txt","w");
       forever begin
          @(posedge clk[2]);
          t0=$time;
          @(posedge clk[2]);
          t1=$time;
   
          $fwrite(f3,"%f, %f\n", t0, (1000/(t1-t0)));
       end
    end   
    initial begin
       automatic realtime   t0, t1;
       f4 = $fopen ("f4.txt","w");
       forever begin
          @(posedge clk[3]);
          t0=$time;
          @(posedge clk[3]);
          t1=$time;
   
          $fwrite(f4,"%f, %f\n", t0, (1000/(t1-t0)));
       end
    end   
   
  initial begin : proc_apb_master
    automatic apb_addr_t addr;
    automatic apb_data_t data;
    automatic apb_strb_t strb;
    automatic logic      resp;
    automatic bit        w;
    automatic logic      err;
    automatic realtime   t0, t1;
     

    strb = '1;
    // reset dut
    @(posedge rst_n);
    apb_master.reset_master();
    repeat (50) @(posedge ref_clk);

    @(posedge clk[0]);
    t0=$time;
    @(posedge clk[0]);
    t1=$time;

    $display("FREQ = %f MHz", (1000/(t1-t0)));
     
    // Step 0 : set clk[0]
    addr = 'h1A100010;
    apb_master.read(addr, data, resp);
    $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);

    addr = 'h1A100010;
    data = 32'h25C350;
    apb_master.write(addr, data, strb, resp);
    $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);
     
    apb_master.read(addr, data, resp);
    $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);

    @(posedge clk[0]);
    t0=$time;
    @(posedge clk[0]);
    t1=$time;

    $display("FREQ = %f MHz", (1000/(t1-t0)));
          
    addr = 'h1A100030;
    apb_master.read(addr, data, resp);
    $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);

    data = 'h0001;
    apb_master.write(addr, data, strb, resp);
    $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);

    apb_master.read(addr, data, resp);
    $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);
     
    addr = 'h1A10000C;
    apb_master.read(addr, data, resp);
    $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);

    data = 'h40030A73;
    apb_master.write(addr, data, strb, resp);
    $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);
     
    apb_master.read(addr, data, resp);
    $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);


     @(posedge clk[0]);
     t0=$time;
     @(posedge clk[0]);
     t1=$time;

    $display("FREQ = %f MHz", (1000/(t1-t0)));
     

    // Read all registers
    for (int unsigned i = TestStartAddr; i < TestEndAddr; i=i+4) begin
      addr = apb_addr_t'(i);
      apb_master.read(addr, data, resp);
      $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
      repeat ($urandom_range(10,15)) @(posedge ref_clk);
    end

    // Set DCOD and MFI for other FLLs 
    for (int unsigned i = 'h1a100018; i < 'h1a100029; i=i+8) begin
      addr = apb_addr_t'(i);
      data = 32'h25C350;
      apb_master.write(addr, data, strb, resp);
      $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
      repeat ($urandom_range(10,15)) @(posedge ref_clk);
      apb_master.read(addr, data, resp);
      $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
      repeat ($urandom_range(10,15)) @(posedge ref_clk);
    end

    // Set to open loop
    for (int unsigned i = 'h1a100014; i < 'h1a100025; i=i+8) begin
      addr = apb_addr_t'(i);
      data = 'h40060A73;
      apb_master.write(addr, data, strb, resp);
      $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
      repeat ($urandom_range(10,15)) @(posedge ref_clk);
      apb_master.read(addr, data, resp);
      $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
      repeat ($urandom_range(10,15)) @(posedge ref_clk);
    end

    addr = 'h1A100030;
    apb_master.read(addr, data, resp);
    $display("Read to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat ($urandom_range(10,15)) @(posedge ref_clk);

    // Select FLL[i].clk for each clko[i]
    data = 'h4321;
    apb_master.write(addr, data, strb, resp);
    $display("Write to addr: %0h. Data: %0h. Resp: %0h", addr,  data, resp);
    repeat (200) @(posedge ref_clk);

    @(posedge clk[0]);
    t0=$time;
    @(posedge clk[0]);
    t1=$time;

    $display("FREQ 1= %f MHz", (1000/(t1-t0)));
    @(posedge clk[1]);
    t0=$time;
    @(posedge clk[1]);
    t1=$time;

    $display("FREQ 2= %f MHz", (1000/(t1-t0)));

    @(posedge clk[2]);
    t0=$time;
    @(posedge clk[2]);
    t1=$time;

    $display("FREQ 3= %f MHz", (1000/(t1-t0)));

    @(posedge clk[3]);
    t0=$time;
    @(posedge clk[3]);
    t1=$time;

    $display("FREQ 4= %f MHz", (1000/(t1-t0)));     
    $finish();
     
  end

endmodule
