# Object-oriented shell — classic libobjc + GNUstep Base
#
# Builds `sh` from Objective-C sources against the classic GNUstep
# libobjc runtime with GNUstep Base 1.18.0 force-linked.

CC       = gcc
CPPFLAGS = -I/usr/local/GNUstep/Local/Library/Headers
CFLAGS   = -Wall -O2
LDFLAGS  = -L/usr/local/GNUstep/Local/Library/Libraries \
           -Wl,-rpath,/usr/local/GNUstep/Local/Library/Libraries \
           -Wl,--no-as-needed \
           -Wl,-u,GSAllocMethodList
LDLIBS   = -lgnustep-base -lobjc -lm

SRC = sh.m objc_dyn.m misc.m lex.m parse.m
OBJ = $(SRC:.m=.o)
HDR = objc_dyn.h

all: sh

sh: $(OBJ)
	$(CC) $(CFLAGS) -o $@ $(OBJ) $(LDFLAGS) $(LDLIBS)

%.o: %.m $(HDR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

test: sh
	bash test.sh
	bash test_gst.sh

clean:
	rm -f sh $(OBJ)

.PHONY: all test clean
