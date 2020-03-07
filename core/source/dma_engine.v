module dma_engine(
		  input clk,
		  input reset,
		  output irq,
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
		  input         dma_ack,

		  output[(ram_a_bits-1):0] ram_a,
		  output[7:0] ram_d,
		  input[7:0] ram_q,
		  output ram_we,
		  output ram_req,
		  input ram_ack,

		  input phi2tick
		  );

   parameter ram_a_bits = 17;  // 17-24
   parameter channels = 1; // 1-16

   localparam ram_a_reg_bits = (ram_a_bits > 19? 24 : 19);

   wire        exp_512k;
   wire [3:0]  version;
   wire [23:0] def_ram_addr;

   assign exp_512k = ram_a_bits >= 19;
   assign version = 4'h8;
   assign def_ram_addr = 24'hf80000;


   reg [7:0] d_q_reg;

   assign d_q = d_q_reg;

   reg [7:0] dma_d_reg = 8'h00;
   reg 	     dma_rw_reg = 1'b0;
   reg 	     dma_req_reg = 1'b0;
   reg [7:0] ram_d_reg = 8'h00;
   reg 	     ram_we_reg = 1'b0;
   reg 	     ram_req_reg = 1'b0;
   reg [15:0] dma_a_out_reg;
   reg [(ram_a_bits-1):0] ram_a_out_reg;

   assign dma_d = dma_d_reg;
   assign dma_rw = dma_rw_reg;
   assign dma_req = dma_req_reg;
   assign ram_d = ram_d_reg;
   assign ram_we = ram_we_reg;
   assign ram_req = ram_req_reg;
   assign dma_a = dma_a_out_reg;
   assign ram_a = ram_a_out_reg;

   reg [3:0] active_channel = 4'd0;
   reg       channel_selected = 1'b0;

   wire [7:0] dqs[(channels-1):0];
   wire [15:0] dma_a_regs[(channels-1):0];
   wire [(ram_a_reg_bits-1):0] ram_a_regs[(channels-1):0];
   wire [1:0] ttypes[(channels-1):0];
   wire [(channels-1):0] last_transfer;
   wire [(channels-1):0] irqs;
   wire [(channels-1):0] runnings;

   genvar    chan;
   generate
      for (chan=0; chan < channels; chan=chan+1) begin : CHANNEL

	 reg [15:0] dma_a_reg = 16'h0000;

	 reg [(ram_a_reg_bits-1):0] ram_a_reg = {ram_a_reg_bits{1'b0}};

	 reg        irq_eob = 1'b0;
	 reg 	    irq_fault = 1'b0;
	 reg        execute = 1'b0;
	 reg 	    load = 1'b0;
	 reg 	    ff00 = 1'b1;
	 reg [1:0]  ttype = 2'b00;
	 reg [15:0] tcnt = 16'hffff;
	 reg 	    irq_enable = 1'b0;
	 reg 	    im_eob = 1'b0;
	 reg 	    im_fault = 1'b0;
	 reg 	    fix_dma_a = 1'b0;
	 reg 	    fix_ram_a = 1'b0;
	 reg 	    constrate = 1'b0;
	 reg 	    constdelay = 1'b0;
	 reg [15:0] delay;
	 reg [7:0]  subdelay;

	 reg 	    running = 1'b0;
	 reg 	    paused = 1'b0;
	 reg [15:0] dma_a_save;
	 reg [(ram_a_reg_bits-1):0] ram_a_save;
	 reg [15:0] tcnt_save;
	 reg [15:0] delaycnt;
	 reg [8:0]  subdelaycnt;

	 reg [7:0]  d_q_val;
	 wire 	    irq_pending;
	 assign     irq_pending = (irq_eob & im_eob) | (irq_fault & im_fault);

	 assign     irqs[chan] = irq_enable & irq_pending;
	 assign     dqs[chan] = d_q_val;

	 assign dma_a_regs[chan] = dma_a_reg;
	 assign ram_a_regs[chan] = ram_a_reg;
	 assign ttypes[chan] = ttype;
	 assign last_transfer[chan] = (tcnt == 16'h0001);
	 assign runnings[chan] = running & ~paused;

	 always @(posedge clk) begin

	    if (reset) begin
	       dma_a_reg <= 16'h0000;
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
	       constrate <= 1'b0;
	       constdelay <= 1'b0;
	       delay <= 16'h0000;
	       subdelay <= 8'h00;
	       running <= 1'b0;
	       paused <= 1'b0;
	       delaycnt <= 16'h0000;
	       subdelaycnt <= 9'h000;
	    end // if (reset)
	    else begin

	       if (read_strobe && a[7:4] == chan && a[3:0] == 4'h0) begin
		  irq_eob <= 1'b0;
		  irq_fault <= 1'b0;
	       end

	       if (write_strobe && a[7:4] == chan)
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
		   4'hb: begin
		      constrate <= d_d[7];
		      constdelay <= d_d[6];
		   end
		   4'hc: delay[7:0] <= d_d;
		   4'hd: delay[15:8] <= d_d;
		   4'he: subdelay <= d_d;
		 endcase // case (a[3:0])

	       if (~running &&
		   ((write_strobe && a[7:4] == chan && a[3:0] == 4'h1 && d_d[7] && d_d[4]) ||
		    (ff00_strobe & execute & ~ff00))) begin
		  dma_a_save <= dma_a_reg;
		  ram_a_save <= ram_a_reg;
		  tcnt_save <= tcnt;
		  running <= 1'b1;
		  delaycnt <= 16'h0001;
		  subdelaycnt <= 8'h00;
		  paused <= constrate | constdelay;
	       end

	       if (running && phi2tick &&
		   (constrate || (constdelay && paused))) begin
		  if (delaycnt == delay) begin
		     paused <= 1'b0;
		     delaycnt <= {15'h0000, ~subdelaycnt[8]};
		     subdelaycnt <= {1'b0, subdelaycnt[7:0]} + {1'b0, subdelay};
		  end else begin
		     delaycnt <= delaycnt + 1;
		  end
	       end

	       if (channel_selected && active_channel == chan && constrate)
		  paused <= 1'b1;

	       if (active_channel == chan) begin
		  case (state)
		    4'b0001: begin
		       if (tcnt == 16'h0001) begin
			  running <= 1'b0;
			  execute <= 1'b0;
			  irq_eob <= 1'b1;
			  if (load) begin
			     dma_a_reg <= dma_a_save;
			     ram_a_reg <= ram_a_save;
			     tcnt <= tcnt_save;
			  end
		       end else begin
			  tcnt <= tcnt - 1;
		       end
		    end
		    4'b1000: // C64 -> RAM step 1
		      if (dma_req_reg == dma_ack && ~fix_dma_a)
			dma_a_reg <= dma_a_reg + 1;
		    4'b1001: // C64 -> RAM step 2
		      if (ram_req_reg == ram_ack) begin
			 if (~fix_ram_a)
			   ram_a_reg <= ram_a_reg + 1;
			 if (constdelay)
			   paused <= 1'b1;
		      end
		    4'b1010: // C64 <- RAM step 1
		      if (ram_req_reg == ram_ack && ~fix_ram_a)
			ram_a_reg <= ram_a_reg + 1;
		    4'b1011: // C64 <- RAM step 2
		      if (dma_req_reg == dma_ack) begin
			 if (~fix_dma_a)
			   dma_a_reg <= dma_a_reg + 1;
			 if (constdelay)
			   paused <= 1'b1;
		      end
		    4'b0100: // swap step 3
		      if (dma_req_reg == dma_ack && ~fix_dma_a)
			dma_a_reg <= dma_a_reg + 1;
		    4'b0101: // swap step 4
		      if (ram_req_reg == ram_ack) begin
			 if (~fix_ram_a)
			   ram_a_reg <= ram_a_reg + 1;
			 if (constdelay)
			   paused <= 1'b1;
		      end
		    4'b1111: // verify step 2
		      if (dma_req_reg == dma_ack)
			if (dma_q == ram_d_reg) begin
			 if (~fix_dma_a)
			   dma_a_reg <= dma_a_reg + 1;
			 if (~fix_ram_a)
			   ram_a_reg <= ram_a_reg + 1;
			 if (constdelay)
			   paused <= 1'b1;
			end else begin
			   running <= 1'b0;
			   execute <= 1'b0;
			   irq_fault <= 1'b1;
			   if (load) begin
			      // This is stupid, but compatible...
			      dma_a_reg <= dma_a_save;
			      ram_a_reg <= ram_a_save;
			      tcnt <= tcnt_save;
			   end
			end // else: !if(dma_q == ram_d_reg)
		  endcase // case (state)
	       end // if (active_channel == chan)
	    end // else: !if(reset)
	 end // always @ (posedge clk)

	 always @(a[3:0]) begin

	    case (a[3:0])
	      4'h0: begin
		 d_q_val = { irq_pending, irq_eob, irq_fault, exp_512k, version };
	      end
	      4'h1: d_q_val = { execute, 1'b0, load, ff00, 2'b00, ttype };
	      4'h2: d_q_val = dma_a_reg[7:0];
	      4'h3: d_q_val = dma_a_reg[15:8];
	      4'h4: d_q_val = ram_a_reg[7:0];
	      4'h5: d_q_val = ram_a_reg[15:8];
	      4'h6: d_q_val = (ram_a_reg_bits >= 24?
			       ram_a_reg[23:16] :
			       { def_ram_addr[23:ram_a_reg_bits],
				 ram_a_reg[(ram_a_reg_bits-1):16] });
	      4'h7: d_q_val = tcnt[7:0];
	      4'h8: d_q_val = tcnt[15:8];
	      4'h9: d_q_val = { irq_enable, im_eob, im_fault, 5'b11111 };
	      4'ha: d_q_val = { fix_dma_a, fix_ram_a, 6'b111111 };
	      4'hb: d_q_val = { constrate, constdelay, 6'b111111 };
	      4'hc: d_q_val = delay[7:0];
	      4'hd: d_q_val = delay[15:8];
	      4'he: d_q_val = subdelay;
	      default: d_q_val = 8'hFF;
	    endcase // case (a[3:0])
	 end // always @ (a[3:0])

      end // block: CHANNEL
   endgenerate

   assign     irq = |irqs;

   reg [3:0]  state  = 4'b0000;

   reg [4:0]  robin_cnt = 4'b0000;
   reg [4:0]  robin_channel = 4'b0000;
   reg        found_robin = 1'b0;

   integer    ch;

   always @(posedge clk) begin

      if (reset) begin
	 dma_req_reg <= dma_ack;
	 ram_req_reg <= ram_ack;

	 state <= 4'b0000;

	 robin_cnt <= 4'b0000;
	 robin_channel <= 4'b0000;
	 found_robin <= 1'b0;

      end else begin

	 if (read_strobe) begin
	    d_q_reg <= 8'hFF;
	    for (ch=0; ch<channels; ch=ch+1)
	      if (a[7:4] == ch)
		d_q_reg <= dqs[ch];
	 end

	 if (~found_robin && |runnings) begin
	    if ((state == 4'b0000 || robin_cnt != active_channel) &&
		runnings[robin_cnt]) begin
	       robin_channel <= robin_cnt;
	       found_robin <= 1'b1;
	    end else
	      if (robin_cnt == (channels - 1))
		robin_cnt <= 0;
	      else
		robin_cnt <= robin_cnt + 1;
	 end

	 channel_selected <= 1'b0;
	 case (state)
	   4'b0000: begin
	      if (found_robin)
		 found_robin <= 1'b0;
	      if (found_robin && runnings[robin_channel]) begin
		 active_channel <= robin_channel;
		 dma_a_out_reg <= dma_a_regs[robin_channel];
		 ram_a_out_reg <= ram_a_regs[robin_channel][(ram_a_bits-1):0];
		 if (ttypes[robin_channel][0]) begin
		    ram_req_reg <= ~ram_req_reg;  // read RAM first
		    ram_we_reg <= 1'b0;
		 end else begin
		    dma_req_reg <= ~dma_req_reg;  // read DMA first
		    dma_rw_reg <= 1'b0;
		 end
		 state <= {1'b1, ttypes[robin_channel], 1'b0};
		 channel_selected <= 1'b1;
	      end // if (found_robin && runnings[robin_channel])
	   end // case: 4'b0000
	   4'b0001: begin
	      if (found_robin)
		 found_robin <= 1'b0;
	      if (found_robin && runnings[robin_channel]) begin
		 active_channel <= robin_channel;
		 dma_a_out_reg <= dma_a_regs[robin_channel];
		 ram_a_out_reg <= ram_a_regs[robin_channel][(ram_a_bits-1):0];
		 if (ttypes[robin_channel][0]) begin
		    ram_req_reg <= ~ram_req_reg;  // read RAM first
		    ram_we_reg <= 1'b0;
		 end else begin
		    dma_req_reg <= ~dma_req_reg;  // read DMA first
		    dma_rw_reg <= 1'b0;
		 end
		 state <= {1'b1, ttypes[robin_channel], 1'b0};
		 channel_selected <= 1'b1;
	      end else
	      if (last_transfer[active_channel] || ~runnings[active_channel]) begin
		 state <= 4'b0000;
	      end else begin
		 dma_a_out_reg <= dma_a_regs[active_channel];
		 ram_a_out_reg <= ram_a_regs[active_channel][(ram_a_bits-1):0];
		 if (ttypes[active_channel][0]) begin
		    ram_req_reg <= ~ram_req_reg;  // read RAM first
		    ram_we_reg <= 1'b0;
		 end else begin
		    dma_req_reg <= ~dma_req_reg;  // read DMA first
		    dma_rw_reg <= 1'b0;
		 end
		 state <= {1'b1, ttypes[active_channel], 1'b0};
		 channel_selected <= 1'b1;
	      end
	   end
	   4'b1000: // C64 -> RAM step 1
	     if (dma_req_reg == dma_ack) begin
		ram_d_reg <= dma_q;
		ram_we_reg <= 1'b1;
		ram_req_reg <= ~ram_req_reg;
		state <= 4'b1001;
	     end
	   4'b1001: // C64 -> RAM step 2
	     if (ram_req_reg == ram_ack) begin
		state <= 4'b0001;
	     end
	   4'b1010: // C64 <- RAM step 1
	     if (ram_req_reg == ram_ack) begin
		dma_d_reg <= ram_q;
		dma_rw_reg <= 1'b1;
		dma_req_reg <= ~dma_req_reg;
		state <= 4'b1011;
	     end
	   4'b1011: // C64 <- RAM step 2
	     if (dma_req_reg == dma_ack) begin
		state <= 4'b0001;
	     end
	   4'b1100: // swap step 1
	     if (dma_req_reg == dma_ack) begin
		ram_d_reg <= dma_q;
		ram_we_reg <= 1'b0;
		ram_req_reg <= ~ram_req_reg;
		state <= 4'b1101;
	     end
	   4'b1101: // swap step 2
	     if (ram_req_reg == ram_ack) begin
		dma_d_reg <= ram_q;
		dma_rw_reg <= 1'b1;
		dma_req_reg <= ~dma_req_reg;
		state <= 4'b0100;
	     end
	   4'b0100: // swap step 3
	     if (dma_req_reg == dma_ack) begin
		ram_we_reg <= 1'b1;
		ram_req_reg <= ~ram_req_reg;
		state <= 4'b0101;
	     end
	   4'b0101: // swap step 4
	     if (ram_req_reg == ram_ack) begin
		state <= 4'b0001;
	     end
	   4'b1110: // verify step 1
	     if (ram_req_reg == ram_ack) begin
		ram_d_reg <= ram_q;
		dma_rw_reg <= 1'b0;
		dma_req_reg <= ~dma_req_reg;
		state <= 4'b1111;
	     end
	   4'b1111: // verify step 2
	     if (dma_req_reg == dma_ack) begin
		if (dma_q == ram_d_reg) begin
		   state <= 4'b0001;
		end else begin
		   state <= 4'b0000;
		end
	     end

	 endcase // case (state)

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // dma_engine
