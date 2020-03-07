QUARTUS_SH = /opt/intelFPGA_lite/18.0/quartus/bin/quartus_sh 

TARGET ?= chameleon2

SRCDIR = source
C2_RTLPATH = ../chameleon-support/rtl
C2_TCLPATH = ../chameleon-support/quartus

PROJECT_PATH = $(TARGET)_project
PROJECT_NAME = super_reu

TCL_SCRIPT = quartus.tcl

C2_TCL_INCLUDES  = $(C2_TCLPATH)/chameleon2_fpga_settings.tcl
C2_TCL_INCLUDES += $(C2_TCLPATH)/chameleon2_synthesis_settings.tcl
C2_TCL_INCLUDES += $(C2_TCLPATH)/chameleon2_pins.tcl


# C64 bus
PROJECT_FILES := $(SRCDIR)/bus_manager.v

# Cartridge "ROM"
PROJECT_FILES += $(SRCDIR)/cart_bram.v

# I/O registers
PROJECT_FILES += $(SRCDIR)/address_decoder.v
PROJECT_FILES += $(SRCDIR)/system_registers.v
PROJECT_FILES += $(SRCDIR)/mmc64.v
PROJECT_FILES += $(SRCDIR)/dma_engine.v

# Support
PROJECT_FILES += $(SRCDIR)/phi_recovery.v


# Chameleon entities
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_1mhz.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_1khz.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_buttons.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_led.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_phi_clock_a.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_phi_clock_e.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_old_sdram.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_spi_flash.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon_usb.vhd

# Chameleon2 edition specific
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon2_io_shiftreg.vhd
C2_RTLFILES += $(C2_RTLPATH)/chameleon/chameleon2_spi.vhd

# Generic support entities
C2_RTLFILES += $(C2_RTLPATH)/general/gen_pipeline.vhd
C2_RTLFILES += $(C2_RTLPATH)/general/gen_reset.vhd
C2_RTLFILES += $(C2_RTLPATH)/general/gen_usart.vhd


chameleon2_SOURCE_FILES := $(C2_TCL_INCLUDES)
chameleon2_SOURCE_FILES += $(SRCDIR)/super_reu_chameleon2.v
chameleon2_SOURCE_FILES += $(SRCDIR)/super_reu_chameleon2.sdc
chameleon2_SOURCE_FILES += $(SRCDIR)/pll50.vhd
chameleon2_SOURCE_FILES += $(PROJECT_FILES) $(C2_RTLFILES)
chameleon2_TOP_LEVEL_ENTITY = chameleon2


RBF_FILE = $(PROJECT_PATH)/output_files/$(PROJECT_NAME).rbf

all : $(RBF_FILE)

$(RBF_FILE): $(TCL_SCRIPT) $($(TARGET)_SOURCE_FILES)
	$(QUARTUS_SH) -t $(TCL_SCRIPT) $(PROJECT_PATH) $(PROJECT_NAME) $($(TARGET)_TOP_LEVEL_ENTITY) $($(TARGET)_SOURCE_FILES)

clean :
	-rm -rf $(PROJECT_PATH)

ifeq ($(TARGET),chameleon2)

SLOT?=2

flash: $(RBF_FILE) $(ROM_FILE)
	chacocmd --flashrbf $(SLOT) $(RBF_FILE) $(ROM_FILE)

else

flash:
	@echo No flash method available
	@false

endif
