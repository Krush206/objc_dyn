/*
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

#import "objc_dyn.h"

#define LINSIZ 1000
#define ARGSIZ 50

static void main1(void);
static void word(void);
static id execute(char **, char **);
static id assign(char **, char **, char **);
static void syntax(char **, char **);

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

static struct Argument *argdef;

int main(void)
{
	loadClass("NSObject");
	objdef = getObjectList();
	argdef = getArgumentList();
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = NULL;
loop:
	if(promp != NULL)
		prs(promp);
	peekc = getc();
	main1();
	goto loop;
}

static id assign(char **ap1, char **ap2, char **ap3)
{
	register struct Object *obj;
	register struct Object *alloc;

	if(ap2++ == ap3)
	{
		err("invalid assignment", 255);
		return nil;
	}
	if(getClass(*ap1) != Nil)
	{
		err("cannot reassign a class class", 255);
		return nil;
	}
	if((obj = getObjectRecord(*ap1)) != NULL)
	{
		obj->prev->next = obj->next;
		obj->next->prev = obj->prev;
		free(obj->name);
		free(obj);
	}
	alloc = malloc(sizeof *alloc);
	alloc->next = objdef;
	alloc->prev = objdef->prev;
	alloc->name = strcpy(malloc(strlen(*ap1) + 1), *ap1);
	objdef->prev->next = alloc;
	objdef->prev = alloc;
	if(ap2 == ap3)
		return alloc->obj = nil;
	return alloc->obj = execute(ap2, ap3);
}

static id execute(char **avs, char **ave)
{
	register char **cp1;
	register char **cp2;
	register id ret;

	if(avs == ave)
		return nil;
	cp1 = &avs[0];
	cp2 = &avs[1];
	if(equal(*cp1, "@"))
		return assign(cp1 + 1, cp2, ave);
	syntax(cp1, ave);
	ret = [getClass(*cp1) performSelector: sel_registerName(*cp2)];
	if(ret == nil)
		ret = [getObject(*cp1) performSelector: sel_registerName(*cp2)];
	return ret;
}

static void syntax(char **avs, char **ave)
{
	register struct Argument *argnew;
	register char **av;

	for(av = avs; av != ave; av++)
	{
		printf("%s\n", *av);
		if(lastchr(*av) == ':')
		{
			argnew = malloc(sizeof *argnew);
			argnew->next = argdef;
			argnew->prev = argdef->prev;
			argnew->arg = *(av + 1);
			argdef->prev->next = argnew;
			argdef->prev = argnew;
		}
	}
}

static void main1(void)
{
	register char *cp;

	argp = args;
	eargp = args+ARGSIZ-1;
	linep = line;
	elinep = line+LINSIZ-1;
	error = 0;
	gflg = 0;
	freeArgument(argdef->next);
	do {
		cp = linep;
		word();
	} while(*cp != '\n');
	if(gflg == 0) {
		if(error != 0)
			err("syntax error", 255);
		else
		{
			const char *name;
			id obj;

			obj = execute(args, argp - 1);
			name = class_getName([obj class]);
			(void) printf("%s <%p>\n", name, obj);
		}
	}
}

static void word(void)
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
		*linep++ = c1;
		while((c=readc()) != c1) {
			if(c == '\n') {
				error++;
				peekc = c;
				return;
			}
			*linep++ = c;
		}
		*linep++ = c1;
		goto pack;

	case ':':
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
		return;
	}

	peekc = c;

pack:
	for(;;) {
		c = getc();
		if(any(c, " :'\"\t;&<>()|^\n")) {
			peekc = c;
			if(any(c, "\"'"))
				goto loop;
			if(c == ':')
				*linep++ = getc();
			*linep++ = '\0';
			return;
		}
		*linep++ = c;
	}
}
