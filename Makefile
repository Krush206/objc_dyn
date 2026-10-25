CC = gcc
CFLAGS = -Wall -O2 -I/usr/local/GNUstep/Local/Library/Headers
LDIR = /usr/local/GNUstep/Local/Library/Libraries
LIBOBJC = -lobjc
LIBBASE = -lgnustep-base

OBJS = sh.o objc_dyn.o misc.o lex.o parse.o

sh: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -L$(LDIR) -Wl,--no-as-needed $(LIBBASE) $(LIBOBJC) -Wl,-rpath,$(LDIR)

%.o: %.m objc_dyn.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f sh *.o

.PHONY: clean
