module system_registers(
			input clk,
			input reset,
			input[3:0] a,
			input[7:0] d_d,
			output[7:0] d_q,
			input read_strobe,
			input write_strobe,
			output reg clockport_enable,
			output reg soft_reset
			);

   reg [7:0] d_q_reg;

   assign d_q = d_q_reg;

   reg [7:0] scratch;
   reg [7:0] last_write_addr;
   reg [7:0] last_write_data;
   reg [7:0] soft_rst_cnt;

   reg de01_enabled;

   always @(posedge clk)

     if(reset) begin

	de01_enabled <= 1'b1;
	clockport_enable <= 1'b0;
	soft_reset <= 1'b0;
	soft_rst_cnt <= 0;

     end else begin

      if (soft_rst_cnt == 0)
	soft_reset <= 0;
      else begin
	 soft_reset <= 1;
	 soft_rst_cnt <= soft_rst_cnt + 1;
      end
	
      if (read_strobe) begin
	 d_q_reg <= 8'hFF;
	 case (a[3:0])
	   4'h0: d_q_reg <= 8'h42;
	   4'h1: d_q_reg <= 8'h73;
	   4'h2: d_q_reg <= scratch;
	   4'h4: d_q_reg <= last_write_addr;
	   4'h5: d_q_reg <= last_write_data;
	 endcase
      end

      if (write_strobe) begin
	 last_write_addr <= { 4'b0000, a[3:0] };
	 last_write_data <= d_d;

	 case (a[3:0])
	   4'h0:
	     if (d_d == 8'h52) soft_rst_cnt <= 8'h01;
	   4'h1:
	     if (de01_enabled) begin
		if (d_d[0]) clockport_enable <= 1'b1;
		de01_enabled <= 1'b0;
	     end
	   4'h2: scratch <= d_d;
	 endcase
      end

   end

endmodule // system_registers
