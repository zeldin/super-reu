
QUARTUS_SH = /opt/intelFPGA_lite/18.0/quartus/bin/quartus_sh 

SRCDIR = source
RTLPATH = ../chameleon-support/rtl
TCLPATH = ../chameleon-support/quartus

PROJECT_PATH = super_reu_project
PROJECT_NAME = super_reu
TOP_LEVEL_ENTITY = chameleon2

TCL_SCRIPT = quartus.tcl

TCL_INCLUDES  = $(TCLPATH)/chameleon2_fpga_settings.tcl
TCL_INCLUDES += $(TCLPATH)/chameleon2_synthesis_settings.tcl
TCL_INCLUDES += $(TCLPATH)/chameleon2_pins.tcl

# Toplevel entities
PROJECT_FILES  = $(SRCDIR)/super_reu_chameleon2.v
PROJECT_FILES += $(SRCDIR)/super_reu_chameleon2.sdc

# PLL50
PROJECT_FILES += $(SRCDIR)/pll50.vhd

# Chameleon entities
RTLFILES += $(RTLPATH)/chameleon/chameleon_1mhz.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_1khz.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_buttons.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_led.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_phi_clock_a.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_phi_clock_e.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_old_sdram.vhd
RTLFILES += $(RTLPATH)/chameleon/chameleon_usb.vhd

# Chameleon2 edition specific
RTLFILES += $(RTLPATH)/chameleon/chameleon2_io_shiftreg.vhd

# Generic support entities
RTLFILES += $(RTLPATH)/general/gen_pipeline.vhd
RTLFILES += $(RTLPATH)/general/gen_reset.vhd
RTLFILES += $(RTLPATH)/general/gen_usart.vhd


SOURCE_FILES =  $(TCL_INCLUDES) $(PROJECT_FILES) $(RTLFILES)

RBF_FILE = $(PROJECT_PATH)/output_files/$(PROJECT_NAME).rbf

all : $(RBF_FILE)

$(RBF_FILE): $(TCL_SCRIPT) $(SOURCE_FILES)
	$(QUARTUS_SH) -t $(TCL_SCRIPT) $(PROJECT_PATH) $(PROJECT_NAME) $(TOP_LEVEL_ENTITY) $(SOURCE_FILES)

clean :
	-rm -rf $(PROJECT_PATH)
