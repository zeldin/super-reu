module mmc64(
	     input clk,
	     input reset,
	     input[3:0] a,
	     input[7:0] d_d,
	     output[7:0] d_q,
	     input read_strobe,
	     input write_strobe,
	     input [7:0] spi_q,
	     output [7:0] spi_d,
	     output spi_req,
	     output spi_speed,
	     input spi_ack,
	     input wp,
	     input cd,
	     output spi_cs,
	     input exrom,
	     input game
	     );

   reg [7:0] d_q_reg;

   assign d_q = d_q_reg;

   reg [7:0] spi_d_reg;
   reg [7:0] spi_q_reg;
   reg 	     active;
   reg 	     trigger_mode;
   reg 	     speed = 1'b0;
   reg 	     cs = 1'b1;

   reg 	     spi_req_reg = 1'b0;
   reg 	     spi_ack_reg = 1'b0;
   assign spi_req = spi_req_reg;
   assign spi_d = spi_q_reg;
   assign spi_speed = speed;
   assign spi_cs = cs;

   always @(posedge clk) begin

      if (reset) begin

	 spi_d_reg <= 8'hff;
	 spi_q_reg <= 8'hff;
	 active <= 1'b0;
	 trigger_mode <= 1'b0;
	 speed <= 1'b0;
	 cs <= 1'b1;

	 spi_req_reg <= spi_ack;
	 spi_ack_reg <= spi_ack;

      end else begin

	 if (spi_ack^spi_ack_reg) begin
	    spi_ack_reg <= spi_ack;
	    spi_d_reg <= spi_q;
	 end

	 if (read_strobe) begin
	    d_q_reg <= 8'hFF;
	    case (a[3:0])
	      4'h0: begin
		 d_q_reg <= spi_d_reg;
		 if (active == 1'b0 && trigger_mode == 1'b1)
		   spi_req_reg <= ~spi_ack;
	      end
	      4'h1: d_q_reg <= { active, trigger_mode, 3'b000, speed, cs, 1'b1 };
	      4'h2: d_q_reg <= { 3'b000, wp, cd, exrom, game, spi_req_reg^spi_ack };
	    endcase
	 end // if (read_strobe)

	 if (write_strobe) begin
	    case (a[3:0])
	      4'h0: begin
		 spi_q_reg <= d_d;
		 if (active == 1'b0 && trigger_mode == 1'b0)
		   spi_req_reg <= ~spi_ack;
	      end
	      4'h1: begin
		 active <= d_d[7];
		 trigger_mode <= d_d[6];
		 speed <= d_d[2];
		 cs <= d_d[1];
	      end
	    endcase
	 end // if (write_strobe)

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // mmc64
