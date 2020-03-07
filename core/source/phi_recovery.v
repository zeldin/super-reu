// This is a simplified (no internal speed, no docking station detection)
// version of chameleon_phi_clock by Peter Wendrich

module phi_recovery
  ( input clk,
    input phi2_in,

    output reg phi2_out,
    output phi2_out_lock,

    output reg full_m2, /* 2nd to last cycle before neg edge */
    output reg full_m1, /* last cycle before neg edge */
    output reg full_p0, /* first cycle after neg edge */
    output reg full_p1, /* 2nd cycle after neg edge */

    output reg half_m2, /* 2nd to last cycle before pos edge */
    output reg half_m1, /* last cycle before pos edge */
    output reg half_p0, /* first cycle after pos edge */
    output reg half_p1  /* 2nd cycle after pos edge */
    );

   parameter phase_shift = 8;
   parameter guard_bits = 4;

   reg [3:0]   phi2_in_shiftreg = 4'b0000;
   reg 	       phi2_in_sync = 1'b0;
   reg [7:0]   in_cnt = 8'h00;

   reg [7:0] 		divider = 8'h00;
   reg [guard_bits-1:0] frac_divider = 0;
   reg [guard_bits+7:0] new_divider = 0;
   reg [8:0] 		div_adjust = 9'h000;

   reg [7:0] 		out_cnt = 8'h00;
   reg [guard_bits-1:0] frac_cnt = 0;
   reg [guard_bits:0] 	new_frac = 0;

   reg [3:0] 		lock_cnt = 4'h0;

   assign phi2_out_lock = lock_cnt[3];

   
   // PHI2 input
   always @(posedge clk) begin
      phi2_in_shiftreg <= { phi2_in_shiftreg[2:0], phi2_in };
      phi2_in_sync <= (phi2_in_shiftreg == 4'b1110 ? 1'b1 : 1'b0);
      if (phi2_in_sync)
	in_cnt <= 8'h00;
      else if (in_cnt != 8'hff)
	in_cnt <= in_cnt + 1;
   end

   // NCO control
   always @(posedge clk) begin
      new_divider = { divider, frac_divider } +
		    { {(8+guard_bits-9){div_adjust[8]}}, div_adjust };
      divider <= new_divider[guard_bits+7:guard_bits];
      frac_divider <= new_divider[guard_bits-1:0];
      if (phi2_in_sync)
	div_adjust <= in_cnt - divider;
      else
	div_adjust <= 0;
   end

   // PHI2 output
   always @(posedge clk) begin
      if (full_m1) begin
	 new_frac = { 1'b0, frac_cnt } + { 1'b0, ~frac_divider };
	 frac_cnt <= new_frac[guard_bits-1:0];
	 out_cnt <= in_cnt + {7'h00, new_frac[guard_bits]};
      end else if (out_cnt >= divider)
	out_cnt <= 0;
      else
	out_cnt <= out_cnt + 1;

      if (full_m1)
	phi2_out <= 1'b0;
      else if(half_m1)
	phi2_out <= 1'b1;

      full_m2 <= (out_cnt + phase_shift == divider ? 1'b1 : 1'b0);
      half_m2 <= (out_cnt + phase_shift == {1'b0, divider[7:1]} ? 1'b1 : 1'b0);

      full_m1 <= full_m2;
      full_p0 <= full_m1;
      full_p1 <= full_p0;

      half_m1 <= half_m2;
      half_p0 <= half_m1;
      half_p1 <= half_p0;
   end

   // Lock check
   always @(posedge clk) begin
      if (|div_adjust[8:2] && |(~div_adjust[8:2]))
	lock_cnt <= 0;
      else if(phi2_in_sync && !phi2_out_lock)
	lock_cnt <= lock_cnt + 1;
   end   
   
endmodule // phi_recovery
