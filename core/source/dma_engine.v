module dma_engine(
		  input clk,
		  input reset,
		  input[7:0] a,
		  input[7:0] d_d,
		  output[7:0] d_q,
		  input read_strobe,
		  input write_strobe,
		  input ff00_strobe,

		  output [15:0] dma_a,
		  output [7:0]  dma_d,
		  input [7:0]   dma_q,
		  output        dma_rw,
		  output        dma_req,
		  input         dma_ack
		  );

   parameter ram_a_bits = 17;  // 17-24

   localparam ram_a_reg_bits = (ram_a_bits > 19? 24 : 19);

   wire        exp_512k;
   wire [3:0]  version;
   wire [23:0] def_ram_addr;

   assign exp_512k = ram_a_bits >= 19;
   assign version = 4'h8;
   assign def_ram_addr = 24'hf80000;


   reg [7:0] d_q_reg;

   assign d_q = d_q_reg;

   reg [15:0] dma_a_reg = 16'h0000;
   reg [7:0]  dma_d_reg = 8'h00;
   reg        dma_rw_reg = 1'b0;
   reg        dma_req_reg = 1'b0;

   assign dma_a = dma_a_reg;
   assign dma_d = dma_d_reg;
   assign dma_rw = dma_rw_reg;
   assign dma_req = dma_req_reg;

   reg [(ram_a_reg_bits-1):0] ram_a_reg = 0;

   reg        irq_eob = 1'b0;
   reg 	      irq_fault = 1'b0;
   reg        execute = 1'b0;
   reg 	      load = 1'b0;
   reg 	      ff00 = 1'b1;
   reg [1:0]  ttype = 2'b00;
   reg [15:0] tcnt = 16'hffff;
   reg 	      irq_enable = 1'b0;
   reg 	      im_eob = 1'b0;
   reg 	      im_fault = 1'b0;
   reg 	      fix_dma_a = 1'b0;
   reg 	      fix_ram_a = 1'b0;

   wire       irq_pending;
   assign     irq_pending = (irq_eob & im_eob) | (irq_fault & im_fault);

   always @(posedge clk) begin

      if (reset) begin
	 dma_a_reg <= 16'h0000;
	 dma_req_reg <= dma_ack;

	 ram_a_reg <= def_ram_addr[(ram_a_reg_bits-1):0];

	 irq_eob <= 1'b0;
	 irq_fault <= 1'b0;
	 execute <= 1'b0;
	 load <= 1'b0;
	 ff00 <= 1'b1;
	 ttype <= 2'b00;
	 tcnt <= 16'hffff;
	 irq_enable <= 1'b0;
	 im_eob <= 1'b0;
	 im_fault <= 1'b0;
	 fix_dma_a <= 1'b0;
	 fix_ram_a <= 1'b0;
      end // if (reset)
      else begin

	 if (read_strobe) begin
	    d_q_reg <= 8'hFF;
	    case (a[3:0])
	      4'h0: begin
		 d_q_reg <= { irq_pending, irq_eob, irq_fault, exp_512k, version };
		 irq_eob <= 1'b0;
		 irq_fault <= 1'b0;
	      end
	      4'h1: d_q_reg <= { execute, 1'b0, load, ff00, 2'b00, ttype };
	      4'h2: d_q_reg <= dma_a_reg[7:0];
	      4'h3: d_q_reg <= dma_a_reg[15:8];
	      4'h4: d_q_reg <= ram_a_reg[7:0];
	      4'h5: d_q_reg <= ram_a_reg[15:8];
	      4'h6: d_q_reg <= (ram_a_reg_bits >= 24?
				ram_a_reg[23:16] :
				{ def_ram_addr[23:ram_a_reg_bits], ram_a_reg[(ram_a_reg_bits-1):16] });
	      4'h7: d_q_reg <= tcnt[7:0];
	      4'h8: d_q_reg <= tcnt[15:8];
	      4'h9: d_q_reg <= { irq_enable, im_eob, im_fault, 5'b11111 };
	      4'ha: d_q_reg <= { fix_dma_a, fix_ram_a, 6'b111111 };
	    endcase
	 end // if (read_strobe)

	 if (write_strobe) begin
	    case (a[3:0])
	      4'h1: begin
		 execute <= d_d[7];
		 load <= d_d[5];
		 ff00 <= d_d[4];
		 ttype <= d_d[1:0];
	      end
	      4'h2: dma_a_reg[7:0] <= d_d;
	      4'h3: dma_a_reg[15:8] <= d_d;
	      4'h4: ram_a_reg[7:0] <= d_d;
	      4'h5: ram_a_reg[15:8] <= d_d;
	      4'h6: ram_a_reg[(ram_a_reg_bits-1):16] <= d_d[(ram_a_reg_bits-17):0];
	      4'h7: tcnt[7:0] <= d_d;
	      4'h8: tcnt[15:8] <= d_d;
	      4'h9: begin
		 irq_enable <= d_d[7];
		 im_eob <= d_d[6];
		 im_fault <= d_d[5];
	      end
	      4'ha: begin
		 fix_dma_a <= d_d[7];
		 fix_ram_a <= d_d[6];
	      end
	    endcase
	 end // if (write_strobe)

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // dma_engine
