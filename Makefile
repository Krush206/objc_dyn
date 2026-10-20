CC = gcc
CFLAGS = -Wall -O2
LDIR = /usr/local/GNUstep/Local/Library/Libraries
LIBOBJC = $(LDIR)/libobjc.so.1

# Link the classic GNUstep libobjc, which provides the classic GNU
# runtime names natively.  compat.c is only for building against
# GCC's own modern libobjc (make COMPAT=1).
OBJS = json.o llm.o llmobj.o
ifeq ($(COMPAT),1)
OBJS += compat.o
LIBOBJC = -lobjc
endif

llmsh: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -lm -Wl,-rpath,$(LDIR) $(LIBOBJC)

%.o: %.m llm.h json.h
	$(CC) $(CFLAGS) -c $< -o $@

compat.o: compat.c
	$(CC) $(CFLAGS) -c compat.c -o compat.o

clean:
	rm -f llmsh json.o llm.o llmobj.o compat.o

.PHONY: clean
