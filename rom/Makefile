
CA65 = ca65 -t c64
LD65 = ld65

SRCDIR = source
OBJDIR = obj

OBJS =  $(OBJDIR)/entry.o
OBJS += $(OBJDIR)/player.o
OBJS += $(OBJDIR)/stream.o
OBJS += $(OBJDIR)/fileselector.o
OBJS += $(OBJDIR)/loader.o
OBJS += $(OBJDIR)/fileindexer.o
OBJS += $(OBJDIR)/index.o
OBJS += $(OBJDIR)/screen.o
OBJS += $(OBJDIR)/fatfs.o
OBJS += $(OBJDIR)/mmc64.o


all : $(OBJDIR)/super_reu.bin

$(OBJDIR)/%.o : $(SRCDIR)/%.s | $(OBJDIR)
	$(CA65) -o $@ $<

$(OBJDIR)/super_reu.bin : $(OBJS)
	$(LD65) -o $@ -m $@.map -C $(SRCDIR)/ld.cfg $^

$(OBJDIR) :
	mkdir $@

clean :
	-rm -rf $(OBJDIR)

