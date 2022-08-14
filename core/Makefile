chameleon2_MAKEFILE := quartus.mk
orangecart_MAKEFILE := symbiflow.mk

.DEFAULT_GOAL:=dummy

ifeq ($(TARGET),)
$(error TARGET must be set)
endif

ifeq ($($(TARGET)_MAKEFILE),)
$(error Unknown target $(TARGET))
endif

%:
	@$(MAKE) --no-print-directory -f $($(TARGET)_MAKEFILE) TARGET=$(TARGET) $(if $(MAKECMDGOALS),$@,)
