module fifo_sync
    // Parameters section
    #( parameter int FIFO_DEPTH = 8
	)
    // Ports section   
	(
		input  logic 								clk_i, 
		input  logic								rst_ni,
		input  logic 								cs,     // chip select	 
		input  logic								wr_en, 
		input  logic								rd_en, 
		input  ariane_axi_soc::address_queue_entry_t 		data_in, 
		output ariane_axi_soc::address_queue_entry_t 		data_out, 
		output logic								empty,
		output logic								full,	// when the full is asserted the FIFO will not accept any data; write ignored silently even if we_en == 1
		output logic								AR_AW_tag_o,
		// Only to be used for debugging:
		output ariane_axi_soc::address_queue_entry_t fifo [0:FIFO_DEPTH-1],// depth 8 => [0:7] 32 bit elements
		output reg [$clog2(FIFO_DEPTH):0] write_pointer,//3:0
  		output reg [$clog2(FIFO_DEPTH):0] read_pointer//3:0
	); 

  localparam int FIFO_DEPTH_LOG = $clog2(FIFO_DEPTH);// 
	
    // Declare a by-dimensional array to store the data
  // ariane_axi_soc::ar_fifo_entry_t fifo [0:FIFO_DEPTH-1];// depth 8 => [0:7] 32 bit elements
	
	// Wr/Rd pointer have 1 extra bits at MSB
  // reg [FIFO_DEPTH_LOG:0] write_pointer;//3:0
  // reg [FIFO_DEPTH_LOG:0] read_pointer;//3:0

  //write
    always_ff @(posedge clk_i or negedge rst_ni) 
      begin
      if(!rst_ni)//rst =0 system reset happens
		    write_pointer <= '0;
      else if (cs && wr_en && !full) begin
          fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
	       write_pointer <= write_pointer + 1'b1;
      end
      end
  
	//read
	always_ff @(posedge clk_i or negedge rst_ni) 
      begin
	    if(!rst_ni) begin
		    read_pointer <= '0;
			data_out <= '0;
      end 
	  else if (cs && rd_en && !empty) begin
          	data_out <= fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];
	        read_pointer <= read_pointer + 1'b1;
      end
	end
	
	// ----------------------------
	// Status signals
	// ----------------------------
	// Declare the empty/full logic
    assign empty = (read_pointer == write_pointer);
	// Full condition: read pointer = write pointer with MSB inverted
	assign full  = (read_pointer == {~write_pointer[FIFO_DEPTH_LOG], write_pointer[FIFO_DEPTH_LOG-1:0]});

	assign AR_AW_tag_o = fifo[read_pointer[FIFO_DEPTH_LOG-1:0]].AR_AW_tag;
endmodule
