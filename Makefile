CC = gcc
CFLAGS = -Wall -O2
LDIR = /usr/local/GNUstep/Local/Library/Libraries
LIBOBJC = $(LDIR)/libobjc.so.1

# The classic GNUstep libobjc provides the GNU runtime names used by
# the sources (objc_next_class, sel_get_uid, ...) natively.
OBJS = json.o llm.o llmobj.o

llmsh: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -lm -Wl,-rpath,$(LDIR) $(LIBOBJC)

%.o: %.m llm.h json.h
	$(CC) $(CFLAGS) -c $< -o $@

test: llmsh
	sh test.sh

clean:
	rm -f llmsh json.o llm.o llmobj.o

.PHONY: clean test
