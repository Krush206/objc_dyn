/*
 * osh.c - original source code for the V6 Thompson shell as found in V7 UNIX
 *
 *	From: Version 7 (V7) UNIX /usr/src/cmd/osh.c
 *
 *	NOTE: The first 42 lines of this file have been added by
 *	      Jeffrey Allen Neitzel <jan (at) etsh (dot) nl> to comply
 *	      with the license.  The file is otherwise unmodified.
 */
/*-
 * Copyright (C) Caldera International Inc.  2001-2002.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code and documentation must retain the above
 *    copyright notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed or owned by Caldera
 *      International, Inc.
 * 4. Neither the name of Caldera International, Inc. nor the names of other
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * USE OF THE SOFTWARE PROVIDED FOR UNDER THIS LICENSE BY CALDERA
 * INTERNATIONAL, INC. AND CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL CALDERA INTERNATIONAL, INC. BE LIABLE FOR ANY DIRECT,
 * INDIRECT INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 */

#import "objc_dyn.h"

#define LINSIZ 1000
#define ARGSIZ 50

static void main1(void);
static int word(void);
static void execute(char **, char **);
static void assign(char **, char **, char **);

char *promp;
char *linep;
char *elinep;
char **argp;
char **eargp;
char peekc;
int gflg;
int error;

static char line[LINSIZ];
static char *args[ARGSIZ];

static struct Object *objdef;

int main(void)
{
	loadClass("NSObject");
	objdef = getObjectList();
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = 0;
loop:
	if(promp != 0)
		prs(promp);
	peekc = getc();
	main1();
	goto loop;
}

static void assign(char **ap1, char **ap2, char **ap3)
{
	if(ap2 == ap3)
	{
		err("invalid assignment", 255);
		return;
	}
	if(getClass(*ap1) != 0)
	{
		err("cannot assign to a class", 255);
		return;
	}
	if(getObject(*ap1) != 0)
	{
		printf("OK\n");
		return;
	}
	if(ap2 + 1 == ap3)
	{
		struct Object *alloc;

		printf("ap2\n");
		alloc = malloc(sizeof *alloc);
		alloc->next = objdef;
		alloc->prev = objdef->prev;
		alloc->obj = 0;
		alloc->name = strcpy(malloc(strlen(*ap1) + 1), *ap1);
		objdef->prev->next = alloc;
		objdef->prev = alloc;
		printf("%s\n", alloc->name);
		return;
	}
}

static void execute(char **avs, char **ave)
{
	register char **cp1, **cp2;

	if(avs == ave)
		return;
	cp1 = &avs[0];
	cp2 = &avs[1];
	if(equal(*cp1, "@"))
	{
		assign(cp1 + 1, cp2, ave);
		return;
	}
}

static void main1(void)
{
	register char  *cp;

	argp = args;
	eargp = args+ARGSIZ-1;
	linep = line;
	elinep = line+LINSIZ-1;
	error = 0;
	gflg = 0;
	do {
		cp = linep;
		word();
	} while(*cp != '\n');
	if(gflg == 0) {
		if(error != 0)
			err("syntax error", 255);
		else
			execute(args, argp - 1);
	}
}

static int word(void)
{
	register char c, c1;

	*argp++ = linep;

loop:
	switch(c = getc()) {

	case ' ':
	case '\t':
		goto loop;

	case '\'':
	case '"':
		c1 = c;
		while((c=readc()) != c1) {
			if(c == '\n') {
				error++;
				peekc = c;
				return 1;
			}
			*linep++ = c|QUOTE;
		}
		goto pack;

	case '&':
	case ';':
	case '<':
	case '>':
	case '(':
	case ')':
	case '|':
	case '^':
	case '\n':
		*linep++ = c;
		*linep++ = '\0';
		return 1;
	}

	peekc = c;

pack:
	for(;;) {
		c = getc();
		if(any(c, " '\"\t;&<>()|^\n")) {
			peekc = c;
			if(any(c, "\"'"))
				goto loop;
			*linep++ = '\0';
			return 1;
		}
		*linep++ = c;
	}
	return 0;
}
