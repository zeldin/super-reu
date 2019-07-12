module bus_manager (
		    input clk,

		    // Data and address bus
		    output ds_dir,
		    output ds_en_n,
		    input[7:0] d_d,
		    output[7:0] d_q,
		    output d_oe,
		    output as_dir,
		    output as_en_n,
		    input[15:0] a_d,
		    output[15:0] a_q,
		    output a_oe,

		    // Bus control signals
		    input ba,
		    input ioef,
		    input romlh,
		    input rw_in,
		    output rw_out,
		    output dma,

		    // ROM
		    input[7:0] romlhdata,
		    output romlh_r_strobe,

		    // IO
		    input[7:0] ioefdata,
		    output ioef_r_strobe,
		    output ioef_w_strobe
		    );

   reg 	     ds_dir_reg;
   reg 	     ds_en_n_reg;
   reg 	     d_oe_reg;
   reg [7:0] d_q_reg;

   assign ds_dir  = ds_dir_reg;
   assign ds_en_n = ds_en_n_reg;
   assign d_oe    = d_oe_reg;
   assign d_q     = d_q_reg;

   assign as_dir  = 1'b0;
   assign as_en_n = 1'b0;
   assign a_oe    = 1'b0;
   assign a_q     = 16'h0000;

   assign rw_out  = 1'b0;
   assign dma     = 1'b0;

   reg [1:0] romlh_filter;
   reg [7:0] ioef_filter;

   assign romlh_r_strobe = romlh_filter == 2'b01;
   assign ioef_r_strobe = (rw_in == 1'b1) & (ioef_filter[1:0] == 2'b01);
   assign ioef_w_strobe = (rw_in == 1'b0) & (ioef_filter == 8'b01111111);

   always @(posedge clk) begin
      romlh_filter = { romlh_filter[0:0], romlh };
      ioef_filter = { ioef_filter[6:0], ioef };

      if (romlh_filter == 2'b11) begin
	 ds_dir_reg  <= 1'b1;
	 ds_en_n_reg <= 1'b0;
	 d_oe_reg    <= 1'b1;
	 d_q_reg     <= romlhdata;
      end else if (ioef_filter[1:0] == 2'b11) begin
	 ds_dir_reg  <= rw_in;
	 ds_en_n_reg <= 1'b0;
	 d_oe_reg    <= rw_in;
	 d_q_reg     <= ioefdata;
      end else begin
	 ds_dir_reg  <= 1'b1;
	 ds_en_n_reg <= 1'b1;
	 d_oe_reg    <= 1'b0;
      end
   end

endmodule // bus_manager
