CC = gcc
CFLAGS = -Wall -O2
LDIR = /usr/local/GNUstep/Local/Library/Libraries
LIBOBJC = $(LDIR)/libobjc.so.1

# The classic GNUstep libobjc provides the GNU runtime names used by
# the sources (objc_next_class, sel_get_uid, ...) natively.
OBJS = sh.o exec.o func.o lex.o misc.o parse.o proc.o sem.o objc_dyn.o

sh: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -lm -Wl,-rpath,$(LDIR) $(LIBOBJC)

%.o: %.m sh.h
	$(CC) $(CFLAGS) -I/usr/local/include/objc -c $< -o $@

test: sh
	sh test.sh

clean:
	rm -f sh *.o

.PHONY: clean test
