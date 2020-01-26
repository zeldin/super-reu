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

   // output defaults
   assign ps2iec_sel = 1'b0;
   assign iec_clk_out = 1'b0;
   assign iec_srq_out = 1'b0;
   assign iec_atn_out = 1'b0;
   assign iec_dat_out = 1'b0;
   assign rtc_cs = 1'b0;
   assign clock_ior = 1'b1;
   assign clock_iow = 1'b1;
   assign game_out = 1'b0;
   assign nmi_out = 1'b0;
   assign sa15_out = 1'b0;
   assign red = 5'b00000;
   assign grn = 5'b00000;
   assign blu = 5'b00000;
   assign hsync_n = 1'b0;
   assign vsync_n = 1'b0;
   assign sigma_l = 1'b0;
   assign sigma_r = 1'b0;

   // Clock signals
   wire sysclk;
   wire clk_150;
   wire clk_locked;
   wire ena_1mhz;
   wire ena_1khz;

   // Reset signals
   wire reset;

   // LED signals
   wire green_led;
   wire red_led;


// Clocks

   pll50 pll_inst(.inclk0(clk50m), .c0(sysclk), .c2(clk_150), .c3(ram_clk), .locked(clk_locked));

   chameleon_1mhz #(.clk_ticks_per_usec(100))
   clk1mhz_inst(.clk(sysclk), .ena_1mhz(ena_1mhz));

   chameleon_1khz clk1khz_inst(.clk(sysclk), .ena_1mhz(ena_1mhz), .ena_1khz(ena_1khz));


// PHI2

   wire phi;
   wire end_of_first_halfcycle;

   chameleon_phi_clock #(.phase_shift(8))
   phi_clock_inst(.clk(sysclk), .phi2_n(phi2_n), .phiLocal(phi),
		  .phiPreHalf(end_of_first_halfcycle));

// Reset

   gen_reset #(.resetCycles(131071))
   reset_inst(.clk(sysclk), .button(~reset_btn), .reset(reset));

// IRQ

   reg 	irq_reg;
   assign irq_out = irq_reg;

   always @(posedge sysclk) begin
      irq_reg <= irq_out_dma;
   end


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
   wire        mmc64_spi_req;
   wire        spi_ack;
   wire        spi_speed;
   wire [7:0]  flash_spi_d;
   wire [7:0]  mmc64_spi_d;
   wire [7:0]  spi_q;

   chameleon2_spi #(.clk_ticks_per_usec(100))
   spi_inst(.clk(sysclk), .sclk(spi_clk), .miso(spi_miso), .mosi(spi_mosi),
	    .req(rom_load_done? mmc64_spi_req : flash_spi_req),
	    .ack(spi_ack), .speed(spi_speed),
	    .d(rom_load_done? mmc64_spi_d : flash_spi_d), .q(spi_q));

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
		  .spi_ack(spi_ack), .spi_d(flash_spi_d),
		  .spi_q(spi_q), .req(flash_cart_req),
		  .ack(flash_cart_ack), .a(flash_cart_a), .q(flash_cart_q));

// SDRAM

   wire        sdram_req;
   wire        sdram_ack;
   wire        sdram_we;
   wire [23:0] sdram_a;
   wire [7:0]  sdram_d;
   wire [7:0]  sdram_q;

   wire        sdram_req2;
   wire        sdram_ack2;
   wire        sdram_we2;
   wire [23:0] sdram_a2;
   wire [7:0]  sdram_d2;
   wire [63:0] sdram_q2;

   chameleon_sdram #(.colAddrBits(9), .rowAddrBits(13),
		     .enable_cpu6510_port("true"),
		     .enable_cache1_port("true"),
                     .casLatency(3), .ras_cycles(2), .precharge_cycles(2),
                     .t_clk_ns(6.7))
   sdram_inst(.clk(clk_150), .reserve(0),
	      .sd_data(ram_d), .sd_addr(ram_a), .sd_we_n(ram_we),
	      .sd_ras_n(ram_ras), .sd_cas_n(ram_cas),
	      .sd_ba_0(ram_ba[0]), .sd_ba_1(ram_ba[1]),
	      .sd_ldqm(ram_ldqm), .sd_udqm(ram_udqm),
	      .cpu6510_req(sdram_req), .cpu6510_ack(sdram_ack),
	      .cpu6510_we(sdram_we), .cpu6510_a({1'b1, sdram_a}),
	      .cpu6510_d(sdram_d), .cpu6510_q(sdram_q),
	      .cache_req(sdram_req2), .cache_ack(sdram_ack2),
	      .cache_we(sdram_we2), .cache_a({1'b1, sdram_a2}),
	      .cache_d({{48{1'b0}}, sdram_d2, sdram_d2}), .cache_q(sdram_q2));


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
   wire        irq_out_dma;

   wire [15:0] io_dma_a;
   wire [7:0]  io_dma_d;
   wire [7:0]  io_dma_q;
   wire        io_dma_rw;
   wire        io_dma_req;
   wire        io_dma_ack;

   wire [7:0]  io_read_data_sys;
   wire [7:0]  io_read_data_mmc64;
   wire [7:0]  io_read_data_dma;
   wire        io_read_strobe_sys;
   wire        io_read_strobe_mmc64;
   wire        io_read_strobe_dma;
   wire        io_write_strobe_sys;
   wire        io_write_strobe_mmc64;
   wire        io_write_strobe_dma;

   wire        disable_exrom;
   
   address_decoder #(.a_bits(9), .devices(3),
		     .base_addresses({16'hde00, 16'hde10, 16'hdf00}),
		     .aperture_widths({4'd4, 4'd4, 4'd8}))
   io_address_decoder_impl(.a(low_a[8:0]), .read_strobe(io_read_strobe),
			   .write_strobe(io_write_strobe), .read_data(io_read_data),
			   .read_strobes({io_read_strobe_sys, io_read_strobe_mmc64, io_read_strobe_dma}),
			   .write_strobes({io_write_strobe_sys, io_write_strobe_mmc64, io_write_strobe_dma}),
			   .read_datas({io_read_data_sys, io_read_data_mmc64, io_read_data_dma}));

   system_registers system_registers_inst(.clk(sysclk), .a(low_a[3:0]),
					  .d_d(low_d), .d_q(io_read_data_sys),
					  .read_strobe(io_read_strobe_sys),
					  .write_strobe(io_write_strobe_sys));

   mmc64 #(.ram_a_bits(24))
   mmc64_inst(.clk(sysclk), .reset(reset), .a(low_a[3:0]), .d_d(low_d),
		    .d_q(io_read_data_mmc64), .read_strobe(io_read_strobe_mmc64),
		    .write_strobe(io_write_strobe_mmc64),
		    .spi_q(spi_q), .spi_d(mmc64_spi_d), .spi_req(mmc64_spi_req),
		    .spi_speed(spi_speed), .spi_ack(spi_ack), .wp(mmc_wp),
		    .cd(mmc_cd), .spi_cs(mmc_cs),
		    .exrom(~exrom_out), .game(~game_out),
	            .disable_exrom(disable_exrom),
		    .ram_a(sdram_a2), .ram_d(sdram_d2), .ram_q(sdram_q2[7:0]),
		    .ram_we(sdram_we2), .ram_req(sdram_req2), .ram_ack(sdram_ack2));

   dma_engine #(.ram_a_bits(24), .channels(4))
   dma_engine_inst(.clk(sysclk), .reset(reset), .irq(irq_out_dma),
		   .a(low_a[7:0]), .d_d(low_d), .d_q(io_read_data_dma),
		   .read_strobe(io_read_strobe_dma),
		   .write_strobe(io_write_strobe_dma),
		   .ff00_strobe(ff00_write_strobe),
		   .dma_a(io_dma_a), .dma_d(io_dma_d),
		   .dma_q(io_dma_q), .dma_rw(io_dma_rw),
		   .dma_req(io_dma_req), .dma_ack(io_dma_ack),
		   .ram_a(sdram_a), .ram_d(sdram_d), .ram_q(sdram_q),
		   .ram_we(sdram_we), .ram_req(sdram_req), .ram_ack(sdram_ack),
		   .phi2tick(end_of_first_halfcycle));


// EXROM

   assign exrom_out = ~disable_exrom;

   wire [7:0] cart_read_data;
   wire	      cart_read_strobe;

   wire        cart_write_strobe;

   reg         flash_cart_req_old = 1'b0;

   assign      cart_write_strobe = (flash_cart_req_old ^ flash_cart_req) & ~rom_load_done;
   assign      flash_cart_ack = flash_cart_req;

   assign      start_flash_load = flash_slot_valid & ~rom_load_done & ~flash_load_busy;

   reg 	       rom_load_started = 1'b0;
   reg 	       rom_load_done = 1'b0;

   assign      green_led = ~spi_clk & ~mmc_cs;
   assign      red_led = ~rom_load_done;


   always @(posedge sysclk) begin
      flash_cart_req_old <= flash_cart_req;
      if (start_flash_load)
	rom_load_started <= 1'b1;
      if (rom_load_started & ~flash_load_busy)
	rom_load_done <= 1'b1;
   end

   cart_bram #(.a_bits(14))
   cart_bram_inst(.clk(sysclk), .read_addr(low_a), .write_addr(flash_cart_a),
		  .read_data(cart_read_data), .write_data(flash_cart_q),
		  .read_strobe(cart_read_strobe),
		  .write_strobe(cart_write_strobe));


endmodule // chameleon2
