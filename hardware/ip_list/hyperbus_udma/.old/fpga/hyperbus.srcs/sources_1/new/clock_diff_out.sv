`timescale 1ns / 1ps

module clock_diff_out
(
    input  logic in_i,
    input  logic en_i, //high enable
    output logic out_o,
    output logic out_no
);

    logic clk_out;

    //Clock gating resulting in clk_rwds
    pulp_clock_gating cdc_read_ck_gating (
        .clk_i      ( in_i    ),
        .en_i       ( en_i    ),
        .test_en_i  ( 1'b0    ),
        .clk_o      ( clk_out )
    );

    OBUFTDS out_buffer
    (
        .I  ( clk_out),
        .T  ( 1'b0   ),
        .O  ( out_o  ),
        .OB ( out_no )
    );
    
endmodule
