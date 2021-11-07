module orangecart (
// Clocks
	       input clk_48mhz,

// Pushbutton
	       input usr_btn,

// NOR Flash
	       /*output flash_sck, */ /* SCK is MCLK */
	       output flash_cs_n,     /* CS_B */
	       output flash_mosi,     /* SI */
	       input  flash_miso,     /* SO */
	       input  flash_wp,       /* WP_B */
	       input  flash_hold,     /* HOLD_B */

// SD-Card
	       output sdcard_dat3_cd, /* DAT3/CD */
	       output sdcard_cmd,     /* CMD */
	       output sdcard_clk,     /* CLK */
	       input  sdcard_dat0,    /* DAT0 */
	       input  sdcard_dat1,    /* DAT1 */
	       input  sdcard_dat2,    /* DAT2 */
	       input  sdcard_det,

// HyperRAM
	       output ram_cs_n,
	       output ram_reset_n,
	       output ram_ck,
	       output ram_psc,
	       inout ram_rwds,
	       inout [7:0] ram_dq,

// RGB LED
	       output led_r,
	       output led_g,
	       output led_b,

// UART
	       output uart_tx,
	       input uart_rx,
		   
// C64 bus
	       output a_enb_l,
	       output a_enb_h,
	       output a_dir_l,
	       output a_dir_h,
	       inout[15:0] low_a,
	       output d_enb,
	       output d_dir,
	       inout[7:0] low_d,
	       input phi2,
	       input dotclk,
	       input ba,
	       input io1,
	       input io2,
	       input romh,
	       input roml,
	       input rw_in,
	       input reset_in,
	       output rw_out,
	       output reset_out,
	       output game,
	       output exrom,
	       output irq_out,
	       output nmi_out,
	       output dma_out,

// Clockport
	       output ciowr,
	       output ciord,
	       output crtccs,
	       output csparecs
	       );

   assign game = 1'b0;
   assign nmi_out = 1'b0;

   assign uart_tx = 1'b1;
   assign led_r = rom_load_done;
   assign led_g = sdcard_clk;
   assign led_b = 1'b1;

   assign ciord = ~clockport_read;
   assign ciowr = ~clockport_write;
   assign crtccs = 1'b1;
   assign csparecs = ~clockport_enable;

   // Clock signals
   wire 	      sysclk;
   wire 	      sysclk_lock;

   // Reset signals
   wire reset;
 
   assign reset_out = reset | ~rom_load_done | ~hyper_lock;

  
// Clocks

   // ecppll -i 48 -o 80
   EHXPLLL #(.PLLRST_ENA("DISABLED"), .INTFB_WAKE("DISABLED"),
             .STDBY_ENABLE("DISABLED"), .DPHASE_SOURCE("DISABLED"),
             .OUTDIVIDER_MUXA("DIVA"), .OUTDIVIDER_MUXB("DIVB"),
             .OUTDIVIDER_MUXC("DIVC"), .OUTDIVIDER_MUXD("DIVD"),
	     .CLKI_DIV(3), .CLKOP_ENABLE("ENABLED"), .CLKOP_DIV(7),
             .CLKOP_CPHASE(3), .CLKOP_FPHASE(0), .FEEDBK_PATH("CLKOP"), 
             .CLKFB_DIV(5))
   sysclkpll(.RST(1'b0), .STDBY(1'b0), .CLKI(clk_48mhz), .CLKOP(sysclk),
	     .CLKFB(sysclk), .CLKINTFB(), .PHASESEL0(1'b0), .PHASESEL1(1'b0),
	     .PHASEDIR(1'b1), .PHASESTEP(1'b1), .PHASELOADREG(1'b1),
	     .PLLWAKESYNC(1'b0), .ENCLKOP(1'b0), .LOCK(sysclk_lock));

// PHI2

   wire phi;
   wire phi_lock;
   wire end_of_first_halfcycle;

   phi_recovery #(.phase_shift(8))
   phi_recovery_inst(.clk(sysclk), .phi2_in(phi2),
		     .phi2_out(phi), .phi2_out_lock(phi_lock),
		     .half_m2(end_of_first_halfcycle));


// Reset

   reset_generator #(.reset_cycles(4095))
   reset_generator_inst(.clk(sysclk), .ext_reset_n(reset_in),
			.int_reset(~usr_btn || ~sysclk_lock || ~phi_lock),
			.reset(reset));
   
   
// IRQ

   reg 	irq_reg;
   assign irq_out = irq_reg;

   always @(posedge sysclk) begin
      irq_reg <= irq_out_dma;
   end


// NOR flash

   wire flash_spi_req;
   wire flash_spi_ack;
   wire [7:0] flash_spi_d;
   wire [7:0] flash_spi_q;

   wire [13:0] flash_cart_a;
   wire [7:0]  flash_cart_q;
   wire        rom_load_done;

   wire        sck;

   USRMCLK mclk(.USRMCLKI(sck), .USRMCLKTS(1'b0), .USRMCLKO());

   generic_spi_master
     #(.clk_speed(80), .sck_speed(20))
   rom_spi_inst(.clk(sysclk), .reset(reset),
		.sclk(sck), .miso(flash_miso), .mosi(flash_mosi),
		.req(flash_spi_req), .ack(flash_spi_ack),
		.d(flash_spi_d), .q(flash_spi_q));

   spi_nor_loader
     #(.mem_addr(16'h8000), .length('h4000))
   nor_loader(.clk(sysclk), .reset(reset),
	      .spi_addr(24'h100000),
	      .spi_req(flash_spi_req), .spi_ack(flash_spi_ack),
	      .spi_d(flash_spi_d), .spi_q(flash_spi_q), .spi_cs_n(flash_cs_n),
	      .mem_a(flash_cart_a), .mem_q(flash_cart_q),
	      .mem_strobe(cart_write_strobe), .done(rom_load_done));


// SDcard

   wire        sdcard_spi_req;
   wire        sdcard_spi_ack;
   wire        sdcard_spi_speed;
   wire [7:0]  sdcard_spi_d;
   wire [7:0]  sdcard_spi_q;

   generic_spi_master
     #(.clk_speed(80000), .sck_speed(250), .sck_fast_speed(8000))
   mmc_spi_inst(.clk(sysclk), .reset(reset),
		.sclk(sdcard_clk), .miso(sdcard_dat0), .mosi(sdcard_cmd),
		.req(sdcard_spi_req), .ack(sdcard_spi_ack),
		.fast_speed_en(sdcard_spi_speed),
		.d(sdcard_spi_d), .q(sdcard_spi_q));


// HyperRAM

   wire        hram_req;
   wire        hram_ack;
   wire        hram_we;
   wire [23:0] hram_a;
   wire [7:0]  hram_d;
   wire [7:0]  hram_q;

   wire        hram_req2;
   wire        hram_ack2;
   wire        hram_we2;
   wire [23:0] hram_a2;
   wire [7:0]  hram_d2;
   wire [7:0]  hram_q2;

   wire        hram_arb_req;
   wire        hram_arb_ack;
   wire        hram_arb_we;
   wire [23:0] hram_arb_a;
   wire [7:0]  hram_arb_d;
   wire [7:0]  hram_arb_q;

   memory_arbitrator
     #(.masters(2), .abits(24), .dbits(8))
   hyper_ram_arbitrator(.clk(sysclk), .reset(reset),
			.m_req({hram_req2, hram_req}),
			.m_ack({hram_ack2, hram_ack}),
			.m_we({hram_we2, hram_we}),
			.m_a({hram_a2, hram_a}),
			.m_d({hram_d2, hram_d}),
			.m_q({hram_q2, hram_q}),
			.s_req(hram_arb_req), .s_ack(hram_arb_ack),
			.s_we(hram_arb_we), .s_a(hram_arb_a),
			.s_d(hram_arb_d), .s_q(hram_arb_q));

   wire hyper_rwds_oe;
   wire hyper_dq_oe;
   wire hyper_ck;
   wire hyper_lock;
   wire [1:0] hyper_rwds_d;
   wire [1:0] hyper_rwds_q;
   wire [15:0] hyper_dq_d;
   wire [15:0] hyper_dq_q;
   wire [15:0] hram_arb_wq;

   assign hram_arb_q = (hram_arb_a[0]? hram_arb_wq[15:8] : hram_arb_wq[7:0]);
   
   hyperram #(.CLK_HZ(80000000),.DUAL_DIE(1), .FIXED_LATENCY_ENABLE(1))
     hyperram_inst(.clk(sysclk), .reset(reset), .pll_locked(hyper_lock),
		   .req(hram_arb_req), .ack(hram_arb_ack),
		   .as(0), .linear_burst(0),
		   .we(hram_arb_we), .a(hram_arb_a[23:1]),
		   .d({hram_arb_d, hram_arb_d}),
		   .ds(hram_arb_a[0]? 2'b10 : 2'b01), .q(hram_arb_wq),
		   .rwds_oe(hyper_rwds_oe), .dq_oe(hyper_dq_oe),
		   .ck(hyper_ck), .cs_b(ram_cs_n),
		   .ram_reset_b(ram_reset_n),
		   .rwds_in(hyper_rwds_q), .rwds_out(hyper_rwds_d),
		   .dq_in(hyper_dq_q), .dq_out(hyper_dq_d));

   ecp5_hyperphy #(.CLK_HZ(80000000))
     hyperphy(.clk(sysclk), .reset(reset),
	      .clk_enable(hyper_ck), .pll_locked(hyper_lock),
	      .rwds_da(hyper_rwds_d[1]), .rwds_db(hyper_rwds_d[0]),
	      .rwds_qa(hyper_rwds_q[1]), .rwds_qb(hyper_rwds_q[0]),
	      .dq_da(hyper_dq_d[15:8]), .dq_db(hyper_dq_d[7:0]),
	      .dq_qa(hyper_dq_q[15:8]), .dq_qb(hyper_dq_q[7:0]),
	      .rwds_oe(hyper_rwds_oe), .dq_oe(hyper_dq_oe),
	      .ck(ram_ck), .psc(ram_psc), .rwds(ram_rwds), .dq(ram_dq));

// Bus

   wire        bus_ds_dir;
   wire        bus_ds_en_n;
   wire [0:7]  bus_d_q;
   wire        bus_d_oe;
   wire        bus_as_dir;
   wire        bus_as_en_n;
   wire [0:15] bus_a_q;
   wire        bus_a_oe;

   assign d_dir = bus_ds_dir;
   assign d_enb = bus_ds_en_n;
   assign low_d = bus_d_oe ? bus_d_q : 8'bZZZZZZZZ;

   assign a_dir_l = bus_as_dir;
   assign a_dir_h = bus_as_dir;
   assign a_enb_l = bus_as_en_n;
   assign a_enb_h = bus_as_en_n;
   assign low_a = bus_a_oe? bus_a_q : 16'bZZZZZZZZZZZZZZZZ;

   wire        clockport_enable;
   wire        clockport_read;
   wire        clockport_write;

   bus_manager bus_manager_inst(.clk(sysclk), .reset(reset), .phi(phi),
				.ds_dir(bus_ds_dir), .ds_en_n(bus_ds_en_n),
				.d_d(low_d), .d_q(bus_d_q), .d_oe(bus_d_oe),
				.as_dir(bus_as_dir), .as_en_n(bus_as_en_n),
				.a_d(low_a), .a_q(bus_a_q), .a_oe(bus_a_oe),
				.ba(ba), .ioef(~io1|~io2), .romlh(~roml|~romh),
				.rw_in(rw_in), .rw_out(rw_out), .dma(dma_out),
				.romlhdata(cart_read_data),
				.romlh_r_strobe(cart_read_strobe),
				.ioefdata(io_read_data),
				.ioef_r_strobe(io_read_strobe),
				.ioef_w_strobe(io_write_strobe),
				.ff00_w_strobe(ff00_write_strobe),
				.dma_a(io_dma_a), .dma_d(io_dma_d),
				.dma_q(io_dma_q), .dma_rw(io_dma_rw),
				.dma_req(io_dma_req), .dma_ack(io_dma_ack),
				.dma_alloc(io_dma_alloc),
				.clockport_enable(clockport_enable),
				.clockport_read(clockport_read),
				.clockport_write(clockport_write));


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
   wire        io_dma_alloc;

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

   system_registers system_registers_inst(.clk(sysclk), .reset(reset),
					  .a(low_a[3:0]),
					  .d_d(low_d), .d_q(io_read_data_sys),
					  .read_strobe(io_read_strobe_sys),
					  .write_strobe(io_write_strobe_sys),
					  .clockport_enable(clockport_enable));

   mmc64 #(.ram_a_bits(24))
   mmc64_inst(.clk(sysclk), .reset(reset), .a(low_a[3:0]), .d_d(low_d),
		    .d_q(io_read_data_mmc64), .read_strobe(io_read_strobe_mmc64),
		    .write_strobe(io_write_strobe_mmc64),
		    .spi_q(sdcard_spi_q), .spi_d(sdcard_spi_d), .spi_req(sdcard_spi_req),
		    .spi_speed(sdcard_spi_speed), .spi_ack(sdcard_spi_ack), .wp(1'b0),
		    .cd(sdcard_det), .spi_cs(sdcard_dat3_cd),
		    .exrom(~exrom), .game(~game),
	            .disable_exrom(disable_exrom),
		    .ram_a(hram_a2), .ram_d(hram_d2), .ram_q(hram_q2[7:0]),
		    .ram_we(hram_we2), .ram_req(hram_req2), .ram_ack(hram_ack2));

   dma_engine #(.ram_a_bits(24), .channels(4))
   dma_engine_inst(.clk(sysclk), .reset(reset), .irq(irq_out_dma),
		   .a(low_a[7:0]), .d_d(low_d), .d_q(io_read_data_dma),
		   .read_strobe(io_read_strobe_dma),
		   .write_strobe(io_write_strobe_dma),
		   .ff00_strobe(ff00_write_strobe),
		   .dma_a(io_dma_a), .dma_d(io_dma_d),
		   .dma_q(io_dma_q), .dma_rw(io_dma_rw),
		   .dma_req(io_dma_req), .dma_ack(io_dma_ack),
		   .dma_alloc(io_dma_alloc),
		   .ram_a(hram_a), .ram_d(hram_d), .ram_q(hram_q),
		   .ram_we(hram_we), .ram_req(hram_req), .ram_ack(hram_ack),
		   .phi2tick(end_of_first_halfcycle));
  

// EXROM

   assign exrom = ~disable_exrom;

   wire [7:0] cart_read_data;
   wire	      cart_read_strobe;
   wire       cart_write_strobe;

   cart_bram #(.a_bits(14))
   cart_bram_inst(.clk(sysclk), .read_addr(low_a), .write_addr(flash_cart_a),
		  .read_data(cart_read_data), .write_data(flash_cart_q),
		  .read_strobe(cart_read_strobe),
		  .write_strobe(cart_write_strobe));   

   
endmodule // orangecart
