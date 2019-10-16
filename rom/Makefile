
CA65 = ca65 -t c64
LD65 = ld65

SRCDIR = source
OBJDIR = obj

OBJS =  $(OBJDIR)/entry.o
OBJS += $(OBJDIR)/stream.o
OBJS += $(OBJDIR)/screen.o
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

