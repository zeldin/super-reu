module address_decoder(
		       input[(a_bits-1):0] a,
		       input read_strobe,
		       input write_strobe,
		       output[(D-1):0] read_data,

		       output[(devices-1):0] read_strobes,
		       output[(devices-1):0] write_strobes,
		       input[(D*devices-1):0] read_datas
		       );

   parameter D = 8;   // data width
   parameter B = 16;  // base address width
   parameter A = 4;   // aperture size width

   parameter a_bits = B;
   parameter devices;

   parameter [(devices*B-1):0] base_addresses;
   parameter [(devices*A-1):0] aperture_widths;

   // Note: If no apertures match, no strobes will fire and read_data
   // will be 0xff.  If multiple apertures match, all relevant strobes
   // will fire and read_data will be the AND of all relevant read_datas

   genvar dev;
   generate
      for (dev=0; dev<devices; dev=dev+1) begin : DEVICE

	 localparam [(B-1):0] base_address = base_addresses[(dev*B+B-1):(dev*B)];
	 localparam aperture_width = aperture_widths[(dev*A+A-1):(dev*A)];

	 wire chip_select;
	 assign chip_select = a[a_bits-1:aperture_width] == base_address[a_bits-1:aperture_width];

	 assign read_strobes[dev] = read_strobe & chip_select;
	 assign write_strobes[dev] = write_strobe & chip_select;

	 wire [(D-1):0] read_data_in;
	 wire [(D-1):0] read_data_out;
	 assign read_data_out = (read_datas[(dev*D+D-1):(dev*D)] | {D{~chip_select}}) & read_data_in;
      end // block: DEVICE
   endgenerate

   generate
      for (dev=1; dev<devices; dev=dev+1) begin : CHAINING
	 assign DEVICE[dev-1].read_data_in = DEVICE[dev].read_data_out;
      end
   endgenerate
   assign DEVICE[devices-1].read_data_in = {D{1'b1}};
   assign read_data = DEVICE[0].read_data_out;

endmodule // address_decoder
