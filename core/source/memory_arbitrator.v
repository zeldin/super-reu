module memory_arbitrator
  #(parameter masters=1,
    parameter abits=32,
    parameter dbits=32)
   (input clk,
    input reset,

    input [(masters-1):0] m_req,
    output reg [(masters-1):0] m_ack,
    input [(masters-1):0] m_we,
    input [(masters*abits-1):0] m_a,
    input [(masters*dbits-1):0] m_d,
    output [(masters*dbits-1):0] m_q,

    output reg s_req,
    input s_ack,
    output reg s_we,
    output reg [(abits-1):0] s_a,
    output reg [(dbits-1):0] s_d,
    input [(dbits-1):0] s_q);

   function integer log2;  // Actually floor(log2)+1
      input integer value;
      begin
         for (log2=0; value>0; log2=log2+1)
           value = value>>1;
      end
   endfunction

   reg [(masters-1):0] m_ack_next;
   reg [log2(masters-1)-1:0] robin;
   reg busy;

   assign m_q = {masters{s_q}};

   genvar m;
   generate
      for (m=masters; m>=0; m=m-1) begin : MASTER
	 wire [log2(masters-1)-1:0] robin_out;
	 wire [(masters-1):0] ack_next_out;
	 wire we_out;
	 wire [(abits-1):0] a_out;
	 wire [(dbits-1):0] d_out;
	 wire select;
	 wire prio;

	 if (m == masters) begin
	    assign robin_out = robin;
	    assign ack_next_out = m_ack_next;
	    assign we_out = 1'b0;
	    assign a_out = {abits{1'b0}};
	    assign d_out = {dbits{1'b0}};
	    assign select = 1'b0;
	    assign prio = 1'b0;
	 end else begin
	    assign select = (m_req[m] != m_ack_next[m]) &&
			    (m > robin || !MASTER[m+1].prio);

	    assign robin_out = (select? m : MASTER[m+1].robin_out);
	    assign ack_next_out = (select? m_ack_next ^ (1 << m) : MASTER[m+1].ack_next_out);
	    assign we_out = (select? m_we[m] : MASTER[m+1].we_out);
	    assign a_out = (select? m_a[((m+1)*abits-1):(m*abits)] : MASTER[m+1].a_out);
	    assign d_out = (select? m_d[((m+1)*dbits-1):(m*dbits)] : MASTER[m+1].d_out);
	    assign prio = (select && m > robin? 1'b1 : MASTER[m+1].prio);
	 end // else: !if(m == masters)
      end // block: MASTER
   endgenerate

   always @(posedge clk)
     if (reset) begin
	m_ack <= {masters{1'b0}};
	m_ack_next <= {masters{1'b0}};
	s_req <= 1'b0;
	s_we <= 1'b0;
	s_a <= {abits{1'b0}};
	s_d <= {dbits{1'b0}};
	robin <= 0;
	busy <= 1'b0;
     end else if (s_ack == s_req) begin
	if (busy) begin
	   m_ack <= m_ack_next;
	   busy <= 1'b0;
	end
	if (|(m_req ^ m_ack_next)) begin
	   robin <= MASTER[0].robin_out;
	   m_ack_next <= MASTER[0].ack_next_out;
	   s_we <= MASTER[0].we_out;
	   s_a <= MASTER[0].a_out;
	   s_d <= MASTER[0].d_out;
	   s_req <= ~s_req;
	   busy <= 1'b1;
	end
     end

endmodule // memory_arbitrator
