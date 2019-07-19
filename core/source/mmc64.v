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
	     input game,
	     output[(ram_a_bits-1):0] ram_a,
	     output[7:0] ram_d,
	     input[7:0] ram_q,
	     output ram_we,
	     output ram_req,
	     input ram_ack
	     );

   parameter ram_a_bits = 17;  // 1-24

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

   reg [23:0] ram_addr = 24'h000000;
   reg 	      ram_req_reg = 1'b0;

   assign ram_a = ram_addr[(ram_a_bits-1):0];
   assign ram_d = spi_d_reg;
   assign ram_we = 1'b1;
   assign ram_req = ram_req_reg;

   reg [7:0]  blockcnt = 8'h00;
   reg 	      readblocks = 1'b0;
   reg 	      blockfail = 1'b0;
   reg [1:0]  state = 2'b00;
   reg [8:0]  bytecnt;

   always @(posedge clk) begin

      if (reset) begin

	 spi_d_reg <= 8'hff;
	 spi_q_reg <= 8'hff;
	 active <= 1'b0;
	 trigger_mode <= 1'b0;
	 speed <= 1'b0;
	 cs <= 1'b1;

	 ram_addr <= 24'h000000;
	 blockcnt <= 8'h00;
	 readblocks <= 1'b0;
	 blockfail <= 1'b0;
	 state <= 2'b00;

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
	      4'h3: d_q_reg <= { 6'b00000, blockfail, readblocks };
	      4'h4: d_q_reg <= blockcnt;
	      4'h5: d_q_reg <= ram_addr[7:0];
	      4'h6: d_q_reg <= ram_addr[15:8];
	      4'h7: d_q_reg <= ram_addr[23:16];
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
	      4'h3: begin
		 if (d_d[0] & ~readblocks) begin
		    readblocks <= 1'b1;
		    blockfail <= 1'b0;
		    spi_q_reg <= 8'hff;
		    spi_req_reg <= ~spi_ack;
		 end else if (readblocks & ~d_d[0]) begin
		    readblocks <= 1'b0;
		    blockfail <= 1'b1;
		    state <= 2'b00;
		 end
	      end
	      4'h4: blockcnt <= d_d;
	      4'h5: ram_addr[7:0] <= d_d;
	      4'h6: ram_addr[15:8] <= d_d;
	      4'h7: ram_addr[23:16] <= d_d;
	    endcase
	 end // if (write_strobe)

	 if (readblocks & (spi_req_reg == spi_ack) & (ram_req_reg == ram_ack)) begin
	    case (state)
	      2'b00: begin
		 // Wait for 0xfe that marks beginning of block
		 if (spi_q == 8'hfe) begin
		    bytecnt <= 9'h1ff;
		    state <= 2'b01;
		    spi_req_reg <= ~spi_req_reg;
		 end else if (spi_q == 8'hff) begin
		    spi_req_reg <= ~spi_req_reg;
		 end else begin
		    blockfail <= 1'b1;
		    readblocks <= 1'b0;
		 end
	      end // case: 2'b00
	      2'b01: begin
		 // Write the fetched byte to RAM
		 ram_req_reg <= ~ram_req_reg;
		 state <= 2'b10;
	      end
	      2'b10: begin
		 ram_addr <= ram_addr + 1;
		 if (bytecnt == 0) begin
		    // Read CRC16
		    bytecnt <= 9'h001;
		    spi_req_reg <= ~spi_req_reg;
		    state <= 2'b11;
		 end else begin
		    bytecnt <= bytecnt - 1;
		    // Fetch next byte of block
		    spi_req_reg <= ~spi_req_reg;
		    state <= 2'b01;
		 end
	      end // case: 2'b10
	      2'b11: begin
		 if (bytecnt[0] == 1'b0) begin
		    state <= 2'b00;
		    if (blockcnt == 8'h01) begin
		       // Transfer complete
		       readblocks <= 1'b0;
		    end else begin
		       // Next block
		       spi_req_reg <= ~spi_req_reg;
		    end
		    blockcnt <= blockcnt - 1;
		 end else begin
		    bytecnt[0] <= 1'b0;
		    // Fetch next byte of CRC16
		    spi_req_reg <= ~spi_req_reg;
		 end
	      end // case: 2'b11

	    endcase // case (state)

	 end // if (readblocks & (spi_req_reg == spi_ack) & (ram_req_reg == ram_ack))

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // mmc64
