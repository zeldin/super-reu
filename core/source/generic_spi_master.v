module generic_spi_master
  #(parameter B=8,
    parameter CPOL=0,
    parameter CPHA=0,
    parameter LSB_FIRST=0,
    parameter clk_speed=100000,
    parameter sck_speed=1000,
    parameter sck_fast_speed=0)
   (input clk,
    input reset,

    output sclk,
    input miso,
    output mosi,

    input req,
    output reg ack,
    input fast_speed_en,
    input [B-1:0] d,
    output [B-1:0] q);

   localparam DIVIDER = (sck_speed > 0 && 2*sck_speed < clk_speed ?
			 (clk_speed / (2 * sck_speed)) - 1 : 0);
   localparam FAST_DIVIDER = (sck_fast_speed > 0 && 2*sck_fast_speed < clk_speed ?
			      (clk_speed / (2 * sck_fast_speed)) - 1 : 0);
   localparam MAX_DIVIDER = (DIVIDER > FAST_DIVIDER ? DIVIDER : FAST_DIVIDER);

   localparam LAST_CNT = 2*B-1;
   localparam CSZ = log2(LAST_CNT);
   
   function integer log2;  // Actually floor(log2)+1
      input integer value;
      begin
         for (log2=0; value>0; log2=log2+1)
           value = value>>1;
      end
   endfunction

   reg [log2(MAX_DIVIDER)-1:0] subcnt = 0;

   reg [B-1:0] 	 d_reg = 0;
   reg [B-1:0]   q_reg = 0;
   reg [CSZ-1:0] cnt = 0;
   reg 		 active = 0;
   reg 		 miso_sync;

   assign sclk = cnt[0] ^ CPOL;
   assign mosi = (LSB_FIRST? d_reg[0] : d_reg[B-1]);
   assign q = q_reg;

   always @(posedge clk) begin

      miso_sync <= miso;

      if (reset) begin
	 d_reg <= 0;
	 q_reg <= 0;
	 cnt <= 0;
	 subcnt <= 0;
	 active <= 1'b0;
	 ack <= 1'b0;
      end else if (subcnt != 0)
	subcnt = subcnt - 1;
      else begin
	 subcnt <= (sck_fast_speed != 0 && fast_speed_en == 1'b1 ?
		    FAST_DIVIDER : DIVIDER);
	 if (active)
	   cnt <= cnt + 1;

	 if (active && cnt[0] == CPHA) begin
	    if (LSB_FIRST)
	      q_reg <= { miso_sync, q_reg[B-1:1] };
	    else
	      q_reg <= { q_reg[B-2:0], miso_sync };
	    if (cnt[CSZ-1:1] == LAST_CNT[CSZ-1:1])
	      ack <= req;
	 end

	 if (active && cnt[0] != CPHA) begin
	    if (LSB_FIRST)
	      d_reg <= { 1'b0, d_reg[B-1:1] };
	    else
	      d_reg <= { d_reg[B-2:0], 1'b0 };
	 end

	 if (cnt == LAST_CNT) begin
	    cnt <= 0;
	    active <= 1'b0;
	 end

	 if (!active)
	   d_reg <= 0;

	 if ((!active || (CPHA == 0 && cnt == LAST_CNT)) && req != ack) begin
	    active <= 1'b1;
	    d_reg <= d;
	    if (CPHA == 1)
	      cnt <= 1;
	 end

      end // else: !if(subcnt != 0)
   end // always @ (posedge clk)

endmodule // generic_spi_master
