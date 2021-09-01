/*

 The following DDR PHY has built-in latencies.  The time from dq_d being
 sampled to it appearing on dq is 2 clocks for A data and 2.5 clocks for
 B data.  The same applies to rwds.  The following wavedrom diagram shows
 the exact timing:

 {signal: [
  {name: 'clk', wave: 'P......', period: 2},
  {name: 'dq_da', wave: 'x35x...', period: 2, data: ["D0A", "D1A"], node:'..A'},
  {name: 'dq_db', wave: 'x47x...', period: 2, data: ["D0B", "D1B"]},
  {name: 'clk_enable', wave: '01.0...', period: 2},
  {},
  {name: 'dq', wave: 'x.......3457x.', data: ["D0A", "D0B", "D1A", "D1B"], node:'........BC'},
  {name: 'ck', wave: '0........HLHL.', phase: 0.5},
  {node: '....D...E'},
  {node: '....F....G'}],
  edge: ['A-F', 'B-E', 'C-G', 'D<-|->E 2 Tclk', 'F<-|->G 2.5 Tclk']}

 For input, the corresponding latencies is 1.5 clocks for A data and
 1 clock for B data, as shown in the following diagram:
 
 {signal: [
  {name: 'clk', wave: 'P....', period: 2},
  {name: 'clk_enable', wave: '10...', period: 2},
  {},
  {name: 'ck', wave: 'lHLHLHLHL.', phase: 0.5},
  {name: 'dq', wave: 'x3457x....', phase: 0.5, data: ["D0A", "D0B", "D1A", "D1B"]},
  {node: '.AB.C'},
  {name: 'dq_qa', wave: 'x.35x', period: 2, data: ["D0A", "D1A"]},
  {name: 'dq_qb', wave: 'x.47x', period: 2, data: ["D0B", "D1B"]},
  {node: '..D.E'},
  {node: '.F..G'}],
  edge: ['A-F', 'B-D', 'C-G', 'D<-|->E 1 Tclk', 'F<-|->G 1.5 Tclk']}
   
 */

module ecp5_hyperphy (input clk,
		      input reset,
		      input clk_enable,
		      output pll_locked,

		      input rwds_da,
		      input rwds_db,
		      output rwds_qa,
		      output rwds_qb,
		      input [7:0] dq_da,
		      input [7:0] dq_db,
		      output [7:0] dq_qa,
		      output [7:0] dq_qb,
		      input rwds_oe,
		      input dq_oe,

		      output ck,
		      output psc,
		      inout rwds,
		      inout [7:0] dq);

   parameter CLK_HZ = 100000000;

   localparam CLK_DIV = 550000000 / CLK_HZ;
   localparam OP_PHASE_X8 = CLK_DIV * 4;
   localparam OS_PHASE_X8 = CLK_DIV * 6;

   generate
      if (CLK_DIV > 128)
	$error("Clock too slow, can't generate EHXPLLL");
   endgenerate

   wire phi90;
   wire fb;

   wire [8:0] pins;
   wire [8:0] oe;
   wire [8:0] rx_q0;
   wire [8:0] rx_q1;
   wire [8:0] tx_d0;
   wire [8:0] tx_d1;

   assign pins = { rwds, dq };
   assign oe = { rwds_oe, {8{dq_oe}} };
   assign rwds_qa = rx_q0[8];
   assign rwds_qb = rx_q1[8];
   assign dq_qa = rx_q0[7:0];
   assign dq_qb = rx_q1[7:0];
   assign tx_d0 = { rwds_da, dq_da };
   assign tx_d1 = { rwds_db, dq_db };

   assign psc = 1'b0; /* Assume PSC is not needed (non DCARS part) */
   
   reg clk_enable_dly;

   always @(posedge phi90)
     clk_enable_dly <= clk_enable;


   EHXPLLL #(.PLLRST_ENA("ENABLED"), .INTFB_WAKE("DISABLED"),
             .STDBY_ENABLE("DISABLED"), .DPHASE_SOURCE("DISABLED"),
             .OUTDIVIDER_MUXA("DIVA"), .OUTDIVIDER_MUXB("DIVB"),
             .OUTDIVIDER_MUXC("DIVC"), .OUTDIVIDER_MUXD("DIVD"),
	     .CLKOP_ENABLE("DISABLED"), .CLKOS_ENABLE("ENABLED"),
	     .CLKOP_DIV(CLK_DIV), .CLKOP_CPHASE(OP_PHASE_X8 >> 3),
	     .CLKOP_FPHASE(OP_PHASE_X8 & 3'b111),
	     .CLKOS_DIV(CLK_DIV), .CLKOS_CPHASE(OS_PHASE_X8 >> 3),
	     .CLKOS_FPHASE(OS_PHASE_X8 & 3'b111),
             .FEEDBK_PATH("INT_OP"), .CLKFB_DIV(1), .CLKI_DIV(1))
   ddrpll (.RST(reset), .STDBY(1'b0), .CLKI(clk), .CLKOP(), .CLKOS(phi90),
           .CLKFB(fb), .CLKINTFB(fb), .PHASESEL0(1'b0), .PHASESEL1(1'b0),
           .PHASEDIR(1'b1), .PHASESTEP(1'b1),  .PHASELOADREG(1'b1),
           .PLLWAKESYNC(1'b0), .ENCLKOP(1'b0), .LOCK(pll_locked));

   // Clock output is delayed 90 degrees to convert TX aligned and RX
   // centered into TX centered and RX aligned from the perspective of
   // the external slave

   ODDRX1F clk_output(.SCLK(phi90), .RST(reset),
		      .D0(clk_enable_dly), .D1(1'b0), .Q(ck));
 
   genvar i;
   generate
      for (i=0; i<9; i=i+1)
	begin : DDR

	   wire d, q;

	   BB bidir(.I(q), .T(~oe[i]), .O(d), .B(pins[i]));
	   
	   IDDRX1F rx(.SCLK(clk), .RST(reset),
		      .D(d), .Q0(rx_q0[i]), .Q1(rx_q1[i]));

	   ODDRX1F tx(.SCLK(clk), .RST(reset),
		      .D0(tx_d0[i]), .D1(tx_d1[i]), .Q(q));
	   
	end
   endgenerate


endmodule // ecp5_hyperphy
