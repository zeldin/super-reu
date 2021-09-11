module hyperram(input clk,
		input reset,

		// DDR PHY interface
		input pll_locked,
		output reg ck = 1'b0,
		input [1:0] rwds_in,
		output reg [1:0] rwds_out,
		input [15:0] dq_in,
		output reg [15:0] dq_out,
		output reg rwds_oe = 1'b0,
		output reg dq_oe = 1'b0,

		// Direct pin interface
		output reg cs_b = 1'b1,
		output reg ram_reset_b = 1'b0,

		// Bus interface
		input as,
		input we,
		input linear_burst,
		input [31:0] a,
		input [15:0] d,
		input [1:0] ds,
		output reg [15:0] q,
		
		input req,
		output reg ack = 1'b0);

   parameter CLK_HZ = 166000000;
   parameter FIXED_LATENCY_ENABLE = 1; // Required on 128 Mbit part
   parameter INITIAL_LATENCY_OVERRIDE = 0;

   generate begin
      if (CLK_HZ > 166000000)
	$error("Clock exceeds 166 MHz");
      if (INITIAL_LATENCY_OVERRIDE &&
	  (INITIAL_LATENCY_OVERRIDE < 3 || INITIAL_LATENCY_OVERRIDE > 6))
	$error("Invalid initial latency override");
   end endgenerate

   localparam RESET_DELAY = CLK_HZ / 5000000 + 1;
   localparam MIN_INITIAL_LATENCY = (CLK_HZ <= 83000000? 3 :
				     (CLK_HZ <= 100000000? 4 :
				      (CLK_HZ <= 133000000? 5 : 6)));
   localparam INITIAL_LATENCY = (INITIAL_LATENCY_OVERRIDE?
				 INITIAL_LATENCY_OVERRIDE : MIN_INITIAL_LATENCY);
   localparam [3:0] IL_CODE = (INITIAL_LATENCY == 3? 4'b1110 :
			       (INITIAL_LATENCY == 4? 4'b1111 :
				(INITIAL_LATENCY == 5? 4'b0000 : 4'b0001)));
   localparam [0:0] FLE_CODE = (FIXED_LATENCY_ENABLE? 1'b1 : 1'b0);

   // Latencies of DDR phy
   localparam TX_LATENCY = 2;
   localparam RX_LATENCY = 1;

   generate begin
      if (INITIAL_LATENCY_OVERRIDE && INITIAL_LATENCY_OVERRIDE < MIN_INITIAL_LATENCY)
	$error("Too low initial latency for this frequency set in override");
      if (2 * INITIAL_LATENCY < 1 + 2 + TX_LATENCY )
	$error("Initial latency too low for this TX_LATENCY");
      if (!FIXED_LATENCY_ENABLE && INITIAL_LATENCY < 1 + 2 + TX_LATENCY )
	$error("Must enable fixed latency with this initial latency");
   end endgenerate

   
   reg [5:0] dlycnt = 6'h3f;
   reg [3:0] state = 4'b1011;
   reg [47:0] ca;
   reg [15:0] data;
   reg [1:0]  ds_int;

   always @(posedge clk)
     if (reset) begin
	ram_reset_b <= 1'b0;
	cs_b <= 1'b1;
	ck <= 1'b0;
	rwds_oe <= 1'b0;
	dq_oe <= 1'b0;
	rwds_out <= 2'b11;
	dq_out <= 16'h0000;
	state <= 4'b1011;
	dlycnt <= RESET_DELAY;
	ack <= 1'b0;
     end else if (dlycnt != 0)
       dlycnt <= dlycnt - 1;
     else if (~ram_reset_b) begin
	state <= 4'b0001;
	ca <= 48'h600001000000; // Write CR0
	data <= { 1'b1, 3'b000, 4'b1111,
		  IL_CODE[3:0], FLE_CODE[0], 1'b1, 2'b11 };
	dlycnt <= RESET_DELAY;
	if (pll_locked)
	   ram_reset_b <= 1'b1;
     end else begin
	state <= state + 1;
	case (state)
	  4'b0001: begin
	     cs_b <= 1'b0;
	     ck <= 1'b1;
	     dq_oe <= 1'b1;
	     dq_out <= ca[47:32];
	     rwds_out <= 2'b11;
	  end
	  4'b0010: dq_out <= ca[31:16];
	  4'b0011: dq_out <= ca[15:0];
	  4'b0100: begin
	     if (ca[47])
	       dq_out <= 16'h0000;
	     else
	       dq_out <= data;
	     if (ca[47] == 1'b1) begin
		// Read operation
		dlycnt <= TX_LATENCY + RX_LATENCY;
		state <= 4'b1001;
	     end else if(ca[46] == 1'b1)
	       // Zero latency write to register
	       state <= 4'b0111;
	     else begin
		// Normal write, wait for RWDS direction change
		dlycnt <= TX_LATENCY;
	     end
	  end
	  4'b0101: begin
	     rwds_oe <= 1'b1;
	     dlycnt <= (!FIXED_LATENCY_ENABLE && ~rwds_in[1]?
			INITIAL_LATENCY - 1 - 2 - TX_LATENCY :
			2 * INITIAL_LATENCY - 1 - 2 - TX_LATENCY);
	  end
	  4'b0110: rwds_out <= ~ds_int;
	  4'b0111: begin
	     ck <= 1'b0;
	     rwds_out <= 2'b11;
	     dlycnt <= TX_LATENCY;
	     state <= 4'b1011;
	  end
      	  4'b1001: begin
	     dq_oe <= 1'b0;
	     dlycnt <= (!FIXED_LATENCY_ENABLE && ~rwds_in[0]?
			INITIAL_LATENCY : 2 * INITIAL_LATENCY);
	  end
	  4'b1010: if (~rwds_in[1])
	    state <= 4'b1010; /* Wait for read ack from RAM */
	  else begin
	     ck <= 1'b0;
	     dlycnt <= TX_LATENCY;
	     q <= dq_in;
	  end
	  4'b1011: begin
	     rwds_oe <= 1'b0;
	     cs_b <= 1'b1;
	     ack <= req;
	  end
	  4'b1100: begin
	     state <= 4'b1100;
	     if (req != ack) begin
		ca <= {~we, as, linear_burst | (as & we),
		       a[31:3], {13{1'b0}}, a[2:0]};
		data <= d;
		ds_int <= ds;
		state <= 4'b0001;
	     end
	  end
	  default: state <= 4'b1011;
	endcase // case (state)

     end
   

endmodule // hyperram
