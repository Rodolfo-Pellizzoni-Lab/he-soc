
#tcheck_status /hyperbus_tb/hyperram_model

# disable reset timing constraint of model
tcheck_set /hyperbus_tb/hyperram_model \
	"( HOLD CSNeg (posedge  RESETNeg) )" OFF


tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_2phase_trans_signals/i_dst/req_dst_q_reg \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF
tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_2phase_trans_signals/i_dst/req_dst_q_reg \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (negedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF

# TX FIFO
tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_TX_fifo/dst_wptr_gray_q_reg_0_ \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF
tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_TX_fifo/dst_wptr_gray_q_reg_0_ \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (negedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF


tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_TX_fifo/dst_wptr_gray_q_reg_2_ \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF
tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_TX_fifo/dst_wptr_gray_q_reg_2_ \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (negedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF


# RX FIFO
tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_RX_fifo/src_rptr_gray_q_reg_2_ \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF
tcheck_set /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/i_cdc_RX_fifo/src_rptr_gray_q_reg_2_ \
	"( SETUP (COND (ENABLE_RB_AND_NOT_SE === 1) (negedge  D) ) (COND (ENABLE_RB_AND_NOT_SE === 1) (posedge  CK)) )" OFF

