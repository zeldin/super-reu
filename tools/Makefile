SRCDIR = source
OBJDIR = obj

OBJS =  $(OBJDIR)/main.o
OBJS += $(OBJDIR)/imgconv.o


all : $(OBJDIR)/m64conv

$(OBJDIR)/%.o : $(SRCDIR)/%.c | $(OBJDIR)
	$(CC) -c -o $@ $<

$(OBJDIR)/m64conv : $(OBJS)
	$(CC) -o $@ $^

$(OBJDIR) :
	mkdir $@

clean :
	-rm -rf $(OBJDIR)

