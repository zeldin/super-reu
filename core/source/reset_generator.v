module reset_generator(input clk,
		       input ext_reset_n,
		       input int_reset,
		       input soft_reset,

		       output reg reset);

   parameter reset_cycles = 4095;

   function integer log2;  // Actually floor(log2)+1
      input integer value;
      begin
         for (log2=0; value>0; log2=log2+1)
           value = value>>1;
      end
   endfunction

   reg [3:0] ext_reset_n_sync = 4'b0000;
   reg [log2(reset_cycles)-1:0] cnt = 0;

   always @(posedge clk) begin
      ext_reset_n_sync = { ext_reset_n_sync[2:0], ext_reset_n };
      reset <= 1'b1;
      if ((ext_reset_n_sync[3:2] == 2'b10 && !soft_reset) || int_reset)
	cnt <= 0;
      else if(cnt != reset_cycles)
	cnt <= cnt + 1;
      else
	reset <= 1'b0;
   end
      
endmodule // reset_generator
