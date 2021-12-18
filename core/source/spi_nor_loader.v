module spi_nor_loader
  #(parameter READ_CMD=8'h03,
    parameter ADDRCNT=3,
    parameter DUMMYCNT=0,
    parameter mem_addr=0,
    parameter length=1)
   (input clk,
    input reset,

    input [(ADDRCNT*8-1):0] spi_addr,

    output reg spi_req = 0,
    input spi_ack,
    output reg [7:0] spi_d = 8'h00,
    input [7:0] spi_q,
    output reg spi_cs_n = 1'b1,

    output reg [log2(mem_addr+length-1)-1:0] mem_a = mem_addr,
    output [7:0] mem_q,
    output reg mem_strobe = 1'b0,

    output reg done = 0);

   function integer log2;  // Actually floor(log2)+1
      input integer value;
      begin
         for (log2=0; value>0; log2=log2+1)
           value = value>>1;
      end
   endfunction

   assign mem_q = spi_q;

   reg [3:0] state = 0;
   reg [log2(length-1)-1:0] cnt = length - 1;

   always @(posedge clk)
     if (reset) begin
	spi_req <= 1'b0;
	spi_d <= 8'h00;
	spi_cs_n <= 1'b1;
	mem_a <= mem_addr;
	mem_strobe <= 1'b0;
	cnt <= length - 1;
	state <= 0;
     end else begin
	if (mem_strobe) begin
	   mem_a <= mem_a + 1;
	   cnt <= cnt - 1;
	end
	mem_strobe <= 1'b0;
	if (!done && spi_req == spi_ack)
	  case (state)
	    4'd0: begin
	       spi_cs_n <= 1'b0;
	       state <= 1;
	    end
	    4'd1: begin
	       spi_d <= READ_CMD;
	       spi_req <= ~spi_req;
	       state <= (ADDRCNT == 4 ? 2 : 3);
	    end
	    4'd2: begin
	       spi_d <= spi_addr[31:24];
	       spi_req <= ~spi_req;
	       state <= 3;
	    end
	    4'd3: begin
	       spi_d <= spi_addr[23:16];
	       spi_req <= ~spi_req;
	       state <= 4;
	    end
	    4'd4: begin
	       spi_d <= spi_addr[15:8];
	       spi_req <= ~spi_req;
	       state <= 5;
	    end
	    4'd5: begin
	       spi_d <= spi_addr[7:0];
	       spi_req <= ~spi_req;
	       state <= 6;
	    end
	    4'd6: begin
	       spi_d <= 8'hff;
	       spi_req <= ~spi_req;
	       state <= (DUMMYCNT == 1 ? 7 : 8);
	    end
	    4'd7: begin
	       spi_req <= ~spi_req;
	       state <= 8;
	    end
	    4'd8: begin
	       mem_strobe <= 1'b1;
	       if (cnt == 0)
		 state <= 9;
	       else
		 spi_req <= ~spi_req;
	    end
	    4'd9: begin
	       spi_cs_n <= 1'b1;
	       done <= 1'b1;
	    end
	  endcase // case (state)
     end // else: !if(reset)

endmodule // spi_nor_loader
