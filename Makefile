
SUBDIRS = tools core rom

.DEFAULT_GOAL:=dummy

%:
	@for dir in $(SUBDIRS); do $(MAKE) -C $$dir $(if $(MAKECMDGOALS),$@,) ; done

flash: all
	@make -C core ROM_FILE=../rom/obj/super_reu.bin flash
