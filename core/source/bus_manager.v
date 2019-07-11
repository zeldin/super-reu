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
		    output romlh_r_strobe
		    );

   assign ds_dir  = 1'b1;
   assign ds_en_n = ~romlh;
   assign d_oe    = romlh;
   assign d_q     = romlhdata;

   assign as_dir  = 1'b0;
   assign as_en_n = 1'b0;
   assign a_oe    = 1'b0;
   assign a_q     = 16'h0000;

   assign rw_out  = 1'b0;
   assign dma     = 1'b0;

   reg        romlh1;
   reg        romlh2;

   assign romlh_r_strobe = romlh1 & ~romlh2;

   always @(posedge clk) begin
      romlh1 <= romlh;
      romlh2 <= romlh1;
   end

endmodule // bus_manager
