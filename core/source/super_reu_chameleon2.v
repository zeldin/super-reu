module chameleon2 (
// Clocks
		   input clk50m,
		   input phi2_n,
		   input dotclk_n,

// Buttons
		   input usart_cts,  // Left button
		   input freeze_btn, // Middle button
		   input reset_btn,  // Right

// PS/2, IEC, LEDs
		   input iec_present,

		   output ps2iec_sel,
		   input[3:0] ps2iec,

		   output ser_out_clk,
		   output ser_out_dat,
		   output ser_out_rclk,

		   output iec_clk_out,
		   output iec_srq_out,
		   output iec_atn_out,
		   output iec_dat_out,

// SPI, Flash and SD-Card
		   output flash_cs,
		   output rtc_cs,
		   output mmc_cs,
		   input mmc_cd,
		   input mmc_wp,
		   output spi_clk,
		   input spi_miso,
		   output spi_mosi,

// Clock port
		   output clock_ior,
		   output clock_iow,

// C64 bus
		   input reset_in,

		   input ioef,
		   input romlh,

		   output dma_out,
		   output game_out,
		   output exrom_out,

		   input irq_in,
		   output irq_out,
		   input nmi_in,
		   output nmi_out,
		   input ba_in,
		   input rw_in,
		   output rw_out,

		   output sa_dir,
		   output sa_oe,
		   output sa15_out,
		   inout[15:0] low_a,

		   output sd_dir,
		   output sd_oe,
		   inout[7:0] low_d,

// SDRAM
		   output ram_clk,
		   output ram_ldqm,
		   output ram_udqm,
		   output ram_ras,
		   output ram_cas,
		   output ram_we,
		   output[1:0] ram_ba,
		   output[12:0] ram_a,
		   inout[15:0] ram_d,

// IR eye
		   input ir_data,

// USB micro
		   input usart_clk,
		   input usart_rts,
		   output usart_rx,
		   input usart_tx,

// Video output
		   output[4:0] red,
		   output[4:0] grn,
		   output[4:0] blu,
		   output hsync_n,
		   output vsync_n,

// Audio output
		   output sigma_l,
		   output sigma_r
		   );

   // inout defaults
   assign ram_d = 16'bZZZZZZZZZZZZZZZZ;

   // output defaults
   assign ps2iec_sel = 1'b0;
   assign iec_clk_out = 1'b0;
   assign iec_srq_out = 1'b0;
   assign iec_atn_out = 1'b0;
   assign iec_dat_out = 1'b0;
   assign rtc_cs = 1'b0;
   assign mmc_cs = 1'b1;
   assign clock_ior = 1'b1;
   assign clock_iow = 1'b1;
   assign game_out = 1'b0;
   assign irq_out = 1'b0;
   assign nmi_out = 1'b0;
   assign sa15_out = 1'b0;
   assign ram_ldqm = 1'b0;
   assign ram_udqm = 1'b0;
   assign ram_ras = 1'b0;
   assign ram_cas = 1'b0;
   assign ram_we = 1'b0;
   assign ram_ba = 2'b00;
   assign ram_a = 13'b0000000000000;
   assign red = 5'b00000;
   assign grn = 5'b00000;
   assign blu = 5'b00000;
   assign hsync_n = 1'b0;
   assign vsync_n = 1'b0;
   assign sigma_l = 1'b0;
   assign sigma_r = 1'b0;

   // Clock signals
   wire sysclk;
   wire clk_locked;
   wire ena_1mhz;
   wire ena_1khz;

   // Reset signals
   wire reset;

   // LED signals
   reg 	green_led = 1'b0;


// Clocks

   pll50 pll_inst(.inclk0(clk50m), .c0(sysclk), .c3(ram_clk), .locked(clk_locked));

   chameleon_1mhz #(.clk_ticks_per_usec(100))
   clk1mhz_inst(.clk(sysclk), .ena_1mhz(ena_1mhz));

   chameleon_1khz clk1khz_inst(.clk(sysclk), .ena_1mhz(ena_1mhz), .ena_1khz(ena_1khz));


// PHI2

   wire phi;

   chameleon_phi_clock #(.phase_shift(8))
   phi_clock_inst(.clk(sysclk), .phi2_n(phi2_n), .phiLocal(phi));

// Reset

   gen_reset #(.resetCycles(131071))
   reset_inst(.clk(sysclk), .button(~reset_btn), .reset(reset));

// LED, PS2 and reset shiftregister

   chameleon2_io_shiftreg shiftreg_inst(.clk(sysclk), .ser_out_clk(ser_out_clk),
					.ser_out_dat(ser_out_dat), .ser_out_rclk(ser_out_rclk),
					.reset_c64(reset | ~rom_load_done),
					.reset_iec(1'b0),
					.ps2_mouse_clk(1'b0), .ps2_mouse_dat(1'b0),
					.ps2_keyboard_clk(1'b0), .ps2_keyboard_dat(1'b0),
					.led_green(green_led), .led_red(red_led));

// USB microcontroller

   wire [3:0]  slot;
   wire        flash_slot_valid;

   chameleon_usb usb_inst(.clk(sysclk), .flashslot({flash_slot_valid, slot}),
			  .reconfig_slot(0), .reconfig(~usart_cts),
			  .serial_clk(usart_clk), .serial_rxd(usart_tx),
			  .serial_txd(usart_rx), .serial_cts_n(usart_rts));

// SPI

   wire        flash_spi_req;
   wire        flash_spi_ack;
   wire [7:0]  flash_spi_d;
   wire [7:0]  flash_spi_q;

   chameleon2_spi #(.clk_ticks_per_usec(100))
   spi_inst(.clk(sysclk), .sclk(spi_clk), .miso(spi_miso), .mosi(spi_mosi),
	    .req(flash_spi_req), .ack(flash_spi_ack), .speed(1'b0),
	    .d(flash_spi_d), .q(flash_spi_q));

// NOR flash

   wire        start_flash_load;
   wire        flash_load_busy;

   wire [13:0] flash_cart_a;
   wire [7:0]  flash_cart_q;
   wire        flash_cart_req;
   wire        flash_cart_ack;

   chameleon_spi_flash #(.a_bits(14))
   spi_flash_inst(.clk(sysclk), .slot(slot), .start(start_flash_load),
		  .start_addr(16'h8000), .flash_offset(0),
		  .amount(16'd8192), .busy(flash_load_busy),
		  .cs_n(flash_cs), .spi_req(flash_spi_req),
		  .spi_ack(flash_spi_ack), .spi_d(flash_spi_d),
		  .spi_q(flash_spi_q), .req(flash_cart_req),
		  .ack(flash_cart_ack), .a(flash_cart_a), .q(flash_cart_q));

// Bus

   wire        bus_ds_dir;
   wire        bus_ds_en_n;
   wire [0:7]  bus_d_q;
   wire        bus_d_oe;
   wire        bus_as_dir;
   wire        bus_as_en_n;
   wire [0:15] bus_a_q;
   wire        bus_a_oe;

   assign sd_dir = bus_ds_dir;
   assign sd_oe = bus_ds_en_n;
   assign low_d = bus_d_oe ? bus_d_q : 8'bZZZZZZZZ;

   assign sa_dir = bus_as_dir;
   assign sa_oe = bus_as_en_n;
   assign low_a = bus_a_oe? bus_a_q : 16'bZZZZZZZZZZZZZZZZ;

   bus_manager bus_manager_inst(.clk(sysclk), .phi(phi),
				.ds_dir(bus_ds_dir), .ds_en_n(bus_ds_en_n),
				.d_d(low_d), .d_q(bus_d_q), .d_oe(bus_d_oe),
				.as_dir(bus_as_dir), .as_en_n(bus_as_en_n),
				.a_d(low_a), .a_q(bus_a_q), .a_oe(bus_a_oe),
				.ba(ba_in), .ioef(ioef), .romlh(romlh),
				.rw_in(rw_in), .rw_out(rw_out), .dma(dma_out),
				.romlhdata(cart_read_data),
				.romlh_r_strobe(cart_read_strobe),
				.ioefdata(io_read_data),
				.ioef_r_strobe(io_read_strobe),
				.ioef_w_strobe(io_write_strobe),
				.ff00_w_strobe(ff00_write_strobe),
				.dma_a(io_dma_a), .dma_d(io_dma_d),
				.dma_q(io_dma_q), .dma_rw(io_dma_rw),
				.dma_req(io_dma_req), .dma_ack(io_dma_ack));

// IO registers

   wire [7:0]  io_read_data;
   wire        io_read_strobe;
   wire        io_write_strobe;
   wire        ff00_write_strobe;

   wire [15:0] io_dma_a;
   wire [7:0]  io_dma_d;
   wire [7:0]  io_dma_q;
   wire        io_dma_rw;
   wire        io_dma_req;
   wire        io_dma_ack;

   wire [7:0]  io_read_data_sys;
   wire [7:0]  io_read_data_dma;
   wire        io_read_stobe_sys;
   wire        io_read_stobe_dma;
   wire        io_write_stobe_sys;
   wire        io_write_stobe_dma;

   assign io_read_data = (low_a[8]? io_read_data_dma : io_read_data_sys);
   assign io_read_strobe_sys = io_read_strobe & ~low_a[8];
   assign io_write_strobe_sys = io_write_strobe & ~low_a[8];
   assign io_read_strobe_dma = io_read_strobe & low_a[8];
   assign io_write_strobe_dma = io_write_strobe & low_a[8];

   system_registers system_registers_inst(.clk(sysclk), .a(low_a[7:0]),
					  .d_d(low_d), .d_q(io_read_data_sys),
					  .read_strobe(io_read_strobe_sys),
					  .write_strobe(io_write_strobe_sys));

   dma_engine #(.ram_a_bits(24))
   dma_engine_inst(.clk(sysclk), .reset(reset),
		   .a(low_a[7:0]), .d_d(low_d), .d_q(io_read_data_dma),
		   .read_strobe(io_read_strobe_dma),
		   .write_strobe(io_write_strobe_dma),
		   .ff00_strobe(ff00_write_strobe),
		   .dma_a(io_dma_a), .dma_d(io_dma_d),
		   .dma_q(io_dma_q), .dma_rw(io_dma_rw),
		   .dma_req(io_dma_req), .dma_ack(io_dma_ack));


// EXROM

   assign exrom_out = 1'b1;

   wire [7:0] cart_read_data;
   wire	      cart_read_strobe;

   wire        cart_write_strobe;

   reg         flash_cart_req_old = 1'b0;

   assign      cart_write_strobe = flash_cart_req_old ^ flash_cart_req;
   assign      flash_cart_ack = flash_cart_req;

   reg         flash_slot_valid_old;
   reg 	       flash_load_busy_old;

   assign      start_flash_load = flash_slot_valid & ~flash_slot_valid_old;

   reg 	       rom_load_done = 1'b0;

   assign      red_led = ~rom_load_done;


   always @(posedge sysclk) begin
      flash_cart_req_old <= flash_cart_req;
      flash_slot_valid_old <= flash_slot_valid;
      flash_load_busy_old <= flash_load_busy;

      if (flash_load_busy_old & ~flash_load_busy)
	rom_load_done <= 1'b1;
   end

   cart_bram #(.a_bits(14))
   cart_bram_inst(.clk(sysclk), .read_addr(low_a), .write_addr(flash_cart_a),
		  .read_data(cart_read_data), .write_data(flash_cart_q),
		  .read_strobe(cart_read_strobe),
		  .write_strobe(cart_write_strobe));



// LED blinking

   reg [8:0] cnt = 9'd0;

   always @(posedge sysclk) begin
      if (ena_1khz) begin
	 if (cnt == 500) begin
	    green_led <= ~green_led;
	    cnt <= 0;
	 end else begin
	    cnt <= cnt+1;
	 end
      end
   end
					

endmodule // chameleon2
