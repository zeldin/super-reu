SRCDIR = source
OBJDIR = obj

OBJS =  $(OBJDIR)/main.o
OBJS += $(OBJDIR)/imgconv.o

DEFS = -DUSE_THREADS=1
LIBS = -lpthread

all : $(OBJDIR)/m64conv

$(OBJDIR)/%.o : $(SRCDIR)/%.c | $(OBJDIR)
	$(CC) $(DEFS) -c -o $@ $<

$(OBJDIR)/m64conv : $(OBJS)
	$(CC) -o $@ $^ $(LIBS)

$(OBJDIR) :
	mkdir $@

clean :
	-rm -rf $(OBJDIR)

