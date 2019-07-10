module cart_bram(
		 input clk,
		 input[a_bits-1:0] read_addr,
		 input[a_bits-1:0] write_addr,
		 output[7:0] read_data,
		 input[7:0] write_data,
		 input read_strobe,
		 input write_strobe
		 );

   parameter a_bits = 14;

   reg [7:0] ram_data[(1 << a_bits)-1:0];
   reg [7:0] data_latch;

   assign read_data = data_latch;

   always @(posedge clk) begin
      if (write_strobe)
	ram_data[write_addr] <= write_data;

      if (read_strobe)
	data_latch <= ram_data[read_addr];
   end

endmodule // cart_bram
