
SUBDIRS = core rom

.DEFAULT_GOAL:=dummy

%:
	@for dir in $(SUBDIRS); do $(MAKE) -C $$dir $(if $(MAKECMDGOALS),$@,) ; done
