
SUBDIRS = tools core rom

.DEFAULT_GOAL:=dummy

SLOT?=2

%:
	@for dir in $(SUBDIRS); do $(MAKE) -C $$dir $(if $(MAKECMDGOALS),$@,) ; done

flash: all
	chacocmd --flashrbf $(SLOT) core/super_reu_project/output_files/super_reu.rbf rom/obj/super_reu.bin
