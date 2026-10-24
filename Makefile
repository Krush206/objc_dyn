CC = gcc
CFLAGS = -Wall -O2 -I/usr/local/GNUstep/Local/Library/Headers
LDIR = /usr/local/GNUstep/Local/Library/Libraries
LIBOBJC = -lobjc

# The classic GNUstep libobjc provides the GNU runtime names used by
# the sources (objc_next_class, sel_get_uid, ...) natively.
OBJS = sh.o exec.o func.o lex.o misc.o parse.o proc.o sem.o objc_dyn.o gnustep.o

sh: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -L$(LDIR) $(LIBOBJC) -lm -Wl,-rpath,$(LDIR)

%.o: %.m sh.h
	$(CC) $(CFLAGS) -c $< -o $@

test: sh
	sh test.sh

clean:
	rm -f sh *.o

.PHONY: clean test
