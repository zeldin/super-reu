TARGET ?= orangecart

ifeq ($(origin _),command line)

orangecart_VERILOG_DEFS :=
orangecart_EXTRA_DEPS :=
orangecart_SYNTH := synth_ecp5 -abc9 -top orangecart
orangecart_PNR := ecp5
orangecart_PNR_OPTIONS := --25k --package CABGA256 --speed 6 --freq 80 --seed 6
orangecart_ECPPACK_OPTIONS := --spimode qspi --freq 38.8 --compress
orangecart_LPF := super_reu_orangecart.lpf
orangecart_TARGETS := orangecart.bit
orangecart_SOURCE_FILES := super_reu_orangecart.v
orangecart_SOURCE_FILES += reset_generator.v
orangecart_SOURCE_FILES += phi_recovery.v
orangecart_SOURCE_FILES += bus_manager.v
orangecart_SOURCE_FILES += address_decoder.v
orangecart_SOURCE_FILES += system_registers.v
orangecart_SOURCE_FILES += mmc64.v
orangecart_SOURCE_FILES += dma_engine.v
orangecart_SOURCE_FILES += cart_bram.v
orangecart_SOURCE_FILES += spi_nor_loader.v
orangecart_SOURCE_FILES += generic_spi_master.v
orangecart_SOURCE_FILES += memory_arbitrator.v
orangecart_SOURCE_FILES += hyperram.v
orangecart_SOURCE_FILES += ecp5_hyperphy.v

SRC := $(SRCDIR)source

add-verilog-default = -p 'verilog_defaults -add $(1)'

read-hdl = -p 'read $(if $(filter %.v,$(1)),-vlog2k,-vhdl2k) $(1)'

define yosys-script
  $(call add-verilog-default,-noautowire) \
  $(foreach def,$(1),$(call add-verilog-default,-D$(def))) \
  $(foreach file,$(2),$(call read-hdl,$(file)))
endef

all : $($(TARGET)_TARGETS)

.SECONDARY:

.SECONDEXPANSION:

.DELETE_ON_ERROR:

%.bit : %.config
	ecppack $($(TARGET)_ECPPACK_OPTIONS) --svf $*.svf $< $@

%.config : %.json $$(addprefix $$(SRC)/,$$($$*_LPF))
	nextpnr-$($*_PNR) --json $< $(addprefix --lpf $(SRC)/,$($*_LPF)) --textcfg $@ $($*_PNR_OPTIONS)

%.json : $$($$*_EXTRA_DEPS) $$(addprefix $$(SRC)/,$$($$*_SOURCE_FILES))
	cd "$(SRC)" && yosys -b json -o "$(CURDIR)"/$@ \
	  $(call yosys-script,$($*_VERILOG_DEFS),$($*_SOURCE_FILES)) \
	  -p '$($*_SYNTH)'

else

# Run make in object directory
SRCDIR?=$(dir $(lastword $(MAKEFILE_LIST)))
SUB_SRCDIR:=$(if $(filter /%,$(SRCDIR)),,../)$(SRCDIR)
O=$(TARGET)_obj
BIT_FILE = $O/$(TARGET).bit
.DEFAULT_GOAL:=dummy

%: | $O
	@$(MAKE) --no-print-directory -C $O -f $(SUB_SRCDIR)/symbiflow.mk SRCDIR=$(SUB_SRCDIR) _= $(if $(MAKECMDGOALS),$@,)

clean:
	rm -rf $O

$O:
	mkdir -p $@


ifeq ($(TARGET),orangecart)

flash: $(BIT_FILE) $(ROM_FILE)
	cp $(BIT_FILE) $O/core.dfu
	cp $(ROM_FILE) $O/rom.dfu
	dfu-suffix -v 1209 -p 5a0c -a $O/core.dfu
	dfu-suffix -v 1209 -p 5a0c -a $O/rom.dfu
	dfu-util -a 0 -D $O/core.dfu
	dfu-util -R -a 1 -D $O/rom.dfu

else

flash:
	@echo No flash method available
	@false

endif

endif
