module bus_manager (
		    input clk,
		    input reset,

		    // Recovered clock
		    input phi,

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
		    output ioef_w_strobe,

		    // DMA
		    input[15:0] dma_a,
		    input[7:0]  dma_d,
		    output[7:0] dma_q,
		    input dma_rw,
		    input dma_req,
		    output dma_ack,
		    input dma_alloc,

		    // FF00 special
		    output ff00_w_strobe,

		    // Clockport
		    input clockport_enable,
		    output reg clockport_read,
		    output reg clockport_write
		    );

   parameter CLOCKPORT_START = 16'hde02;
   parameter CLOCKPORT_END   = 16'hde10;

   reg 	     ds_dir_reg = 1'b0;
   reg 	     ds_en_n_reg = 1'b1;
   reg 	     d_oe_reg = 1'b0;
   reg [7:0] d_q_reg;

   reg 	      ds_dir_dma = 1'b0;
   reg 	      ds_en_n_dma = 1'b1;
   reg 	      d_oe_dma = 1'b0;
   reg        rw_out_dma = 1'b0;
   reg 	      as_dir_dma = 1'b0;
   reg 	      as_en_n_dma = 1'b0;
   reg 	      a_oe_dma = 1'b0;
   reg 	      as_dir_reg = 1'b0;
   reg 	      as_en_n_reg = 1'b0;
   reg 	      a_oe_reg = 1'b0;
   reg [15:0] a_q_reg;
   reg 	      dma_reg = 1'b0;
   reg [7:0]  dma_q_reg;
   reg        dma_ack_reg = 1'b0;
   reg        dma_dummy_cycle = 1'b0;

   assign ds_dir  = ds_dir_reg;
   assign ds_en_n = ds_en_n_reg;
   assign d_oe    = d_oe_reg;
   assign d_q     = d_q_reg;

   assign as_dir  = as_dir_reg;
   assign as_en_n = as_en_n_reg;
   assign a_oe    = a_oe_reg;
   assign a_q     = a_q_reg;

   assign rw_out  = rw_out_dma;
   assign dma     = dma_reg;
   assign dma_q   = dma_q_reg;
   assign dma_ack = dma_ack_reg;

   reg [1:0] ba_filter;
   reg [1:0] romlh_filter;
   reg [7:0] ioef_filter;
   reg [1:0] ba_counter = 2'b00;
   reg [1:0] rw_in_log = 2'b11;
   reg 	     ff00_w_strobe_reg;

   assign romlh_r_strobe = romlh_filter == 2'b01;
   assign ioef_r_strobe = (rw_in == 1'b1) & (ioef_filter[1:0] == 2'b01) & ~clockport_active;
   assign ioef_w_strobe = (rw_in == 1'b0) & (ioef_filter == 8'b01111111) & ~clockport_active;
   assign ff00_w_strobe = ff00_w_strobe_reg;

   wire      ba_asserted;
   wire      cpu_stopped_by_ba;
   wire      read_follows_write;
   assign    ba_asserted = ba_filter == 2'b00;
   assign    cpu_stopped_by_ba = ba_counter == 2'b11;
   assign    read_follows_write = rw_in_log == 2'b01;

   wire      can_request_dma;
   assign    can_request_dma = cpu_stopped_by_ba | read_follows_write;

   reg       clockport_range;
   wire      clockport_active;
   assign    clockport_active = clockport_enable && clockport_range;

   reg [3:0] state = 4'd0;
   reg [3:0] dma_delay = 4'd0;

   always @(posedge clk) begin

      ba_filter = { ba_filter[0:0], ba };

      // EXROM and IO timing just follows the ROML/H and IO signals

      romlh_filter = { romlh_filter[0:0], romlh };
      ioef_filter = { ioef_filter[6:0], ioef };

      clockport_read <= 0;
      clockport_write <= 0;
      clockport_range <= (a_d[8:0] >= CLOCKPORT_START[8:0] && a_d[8:0] < CLOCKPORT_END[8:0]);

      if (reset) begin
	 ds_dir_reg <= 1'b0;
	 ds_en_n_reg <= 1'b1;
	 d_oe_reg <= 1'b0;
	 as_dir_reg <= 1'b0;
	 as_en_n_reg <= 1'b1;
	 a_oe_reg <= 1'b0;
      end else if (romlh_filter == 2'b11) begin
	 ds_dir_reg  <= 1'b1;
	 ds_en_n_reg <= 1'b0;
	 d_oe_reg    <= 1'b1;
	 if (rw_in)
	   d_q_reg   <= romlhdata;
	 as_dir_reg  <= 1'b0;
	 as_en_n_reg <= 1'b0;
	 a_oe_reg    <= 1'b0;
	 if (dma_reg) begin
	    as_dir_reg  <= as_dir_dma;
	    as_en_n_reg <= as_en_n_dma;
	    a_oe_reg    <= a_oe_dma;
	    ds_dir_reg  <= ds_dir_dma;
	    ds_en_n_reg <= 1'b1;
	 end
      end else if (ioef_filter[1:0] == 2'b11) begin
	 if (clockport_active) begin
	    ds_dir_reg  <= 1'b0;
	    ds_en_n_reg <= 1'b0;
	    d_oe_reg    <= 1'b0;
	    clockport_read <= rw_in;
	    clockport_write <= ~rw_in;
	 end else begin
	    ds_dir_reg  <= rw_in;
	    ds_en_n_reg <= 1'b0;
	    d_oe_reg    <= rw_in;
	 end
	 if (rw_in)
	   d_q_reg   <= ioefdata;
	 as_dir_reg  <= 1'b0;
	 as_en_n_reg <= 1'b0;
	 a_oe_reg    <= 1'b0;
	 if (dma_reg) begin
	    as_dir_reg  <= as_dir_dma;
	    as_en_n_reg <= as_en_n_dma;
	    a_oe_reg    <= a_oe_dma;
	    ds_dir_reg  <= ds_dir_dma;
	    if (clockport_active) begin
	       ds_en_n_reg <= ds_en_n_dma;
	       d_oe_reg    <= d_oe_dma;
	    end else begin
	       ds_en_n_reg <= 1'b1;
	       d_oe_reg    <= 1'b1;
	    end
	 end
      end else begin
	 ds_dir_reg  <= ds_dir_dma;
	 ds_en_n_reg <= ds_en_n_dma;
	 d_oe_reg    <= d_oe_dma;
	 as_dir_reg  <= as_dir_dma;
	 as_en_n_reg <= as_en_n_dma;
	 a_oe_reg    <= a_oe_dma;
      end


      // DMA timing is generated based on PHI2

      state <= 4'd0;
      case (state & {4{~reset}})
	4'd0: // Reset
	  begin
	     ds_dir_dma <= 1'b0;
	     ds_en_n_dma <= 1'b1;
	     d_oe_dma <= 1'b0;
	     as_dir_dma <= 1'b0;
	     as_en_n_dma <= 1'b0;
	     a_oe_dma <= 1'b0;
             rw_out_dma <= 1'b0;
	     dma_reg <= 1'b0;
	     dma_dummy_cycle <= 1'b0;

	     if (phi)
	       state <= 4'd1;
	     else
	       state <= 4'd0;
	  end
	4'd1: // Wait PHI0
	  if (phi)
	    state <= 4'd1;
	  else
	    state <= 4'd2;
	4'd2: // 0_00
	  begin
	     if ((rw_in == 1'b0) & (a_d == 16'hff00))
	       ff00_w_strobe_reg <= 1'b1;
	     rw_in_log <= { rw_in_log[0:0], rw_in | dma_reg };
	     state <= 4'd3;
	  end
	4'd3: // 0_01
	  begin
	     ff00_w_strobe_reg <= 1'b0;
	     state <= 4'd4;
	  end
	4'd4: // 0_02
	  begin
	     ds_en_n_dma <= 1'b1;
	     d_oe_dma <= 1'b0;
	     as_en_n_dma <= 1'b1;
	     a_oe_dma <= 1'b0;

	     state <= 4'd5;
	  end
	4'd5: // 0_03
	  begin
	     ds_dir_dma <= 1'b0;
	     as_dir_dma <= 1'b0;
             rw_out_dma <= 1'b0;
	     dma_delay <= 4'd15;

	     state <= 4'd13;
	  end
	4'd13:
	  begin
	     if (|dma_delay) begin
	       dma_delay <= dma_delay - 1;
		state <= 4'd13;
	     end else begin
		if (dma_req == dma_ack_reg && !dma_alloc)
		  dma_reg <= 1'b0;
		else if (can_request_dma)
		  dma_reg <= 1'b1;

		state <= 4'd6;
	     end
	  end
	4'd6: // Wait PHI1
	  begin
	     as_en_n_dma <= 1'b0;
	     if (phi)
	       state <= 4'd7;
	     else
	       state <= 4'd6;
	  end
	4'd7: // 1_00
	  begin
	     if (~ba_asserted)
	       ba_counter <= 2'b00;
	     else if(~cpu_stopped_by_ba)
	       ba_counter <= ba_counter + 1;

	     if (dma_reg & ~ba_asserted) begin
		as_en_n_dma <= 1'b1;
		
		state <= 4'd8;
	     end else
	       state <= 4'd1;
	  end
	4'd8: // 1_01
	  begin
	     if (dma_req != dma_ack_reg) begin
		dma_dummy_cycle <= 1'b0;
		a_q_reg <= dma_a;
		d_q_reg <= dma_d;
		ds_dir_dma <= dma_rw;
	     end else begin
		dma_dummy_cycle <= 1'b1;
		// Read address 0
		a_q_reg <= 0;
	     end
	     as_dir_dma <= 1'b1;
	     state <= 4'd9;
	  end
	4'd9: // 1_02
	  begin
	     as_en_n_dma <= 1'b0;
	     a_oe_dma <= 1'b1;
	     if (!dma_dummy_cycle)
               rw_out_dma <= dma_rw;

	     state <= 4'd10;
	  end
	4'd10: // 1_03
	  begin
	     if (rw_out_dma)
	       d_oe_dma <= 1'b1;

	     state <= 4'd11;
	  end
	4'd11: // 1_04
	  begin
	     ds_en_n_dma <= 1'b0;

	     state <= 4'd12;
	  end
	4'd12: // Wait PHI0 (DMA)
	  begin
	     if (phi) begin
		dma_q_reg <= d_d;
		state <= 4'd12;
	     end else begin
		if (!dma_dummy_cycle)
		  dma_ack_reg <= dma_req;

		state <= 4'd2;
	     end
	  end
      endcase // case (state)

   end // always @ (posedge clk)

endmodule // bus_manager
