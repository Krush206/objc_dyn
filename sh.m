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
static id execute1(id, const char *);
static id assign(char **, char **);
static void syntax(char **, char **);
static int syntax1(char **, char **);
static char *syntax2(char **, char **, int);
static id string(char **, char **);

char *promp;
char *linep;
char *elinep;
char **argp;
char **eargp;
int peekc;
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

static id assign(char **ap1, char **ap2)
{
	register struct Object *obj;
	register struct Object *alloc;
	register char **ap;

	ap = ap1;
	if(ap++ == ap2)
	{
		err("invalid assignment", 255);
		return nil;
	}
	if(getClass(*ap1) != Nil)
	{
		err("cannot reassign a class", 255);
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
	if(ap == ap2)
		return alloc->obj = nil;
	return alloc->obj = execute(ap, ap2);
}

static id execute(char **avs, char **ave)
{
	register char **cp1;
	register char **cp2;
	register id ret;

	cp1 = avs;
	if(cp1 == ave)
		return nil;
	if(equal(*(cp1 + 1), "\n"))
	{
		err("missing message", 255);
		return nil;
	}
	cp2 = avs + 1;
	if(equal(*cp1, "="))
		return assign(cp2, ave);
	if(scan(*cp1))
		return string(cp1, ave);
	syntax(cp1, ave);
	ret = getClass(*cp1);
	if(ret == nil)
		ret = getObject(*cp1);
	if(ret == nil)
		return nil;
	if(argdef->next == argdef)
		return execute1(ret, *cp2);
	return execute1(ret, syntax2(ave, cp1, syntax1(cp1, ave)));
}

static id execute1(id obj, const char *msg)
{
	int i;
	void *arr[10];
	struct Argument *argnew;

	i = 0;
	for(argnew = argdef->next; argnew != argdef; argnew = argnew->next)
		i++;
	if(i > 9)
	{
		err("too many arguments", 255);
		return nil;
	}
	i = 0;
	for(argnew = argdef->next; argnew != argdef; argnew = argnew->next)
		*(arr + i++) = getObject(argnew->arg);
	switch(i)
	{
	case 0:
		return objc_msgSend(obj, sel_registerName(msg));
	case 1:
		return objc_msgSend(obj, sel_registerName(msg), *arr);
	case 2:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1));
	case 3:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2));
	case 4:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3));
	case 5:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3),
								*(arr + 4));
	case 6:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3),
								*(arr + 4),
								*(arr + 5));
	case 7:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3),
								*(arr + 4),
								*(arr + 5),
								*(arr + 6));
	case 8:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3),
								*(arr + 4),
								*(arr + 5),
								*(arr + 6),
								*(arr + 7));
	case 9:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3),
								*(arr + 4),
								*(arr + 5),
								*(arr + 6),
								*(arr + 7),
								*(arr + 8));
	case 10:
		return objc_msgSend(obj, sel_registerName(msg), *arr,
								*(arr + 1),
								*(arr + 2),
								*(arr + 3),
								*(arr + 4),
								*(arr + 5),
								*(arr + 6),
								*(arr + 7),
								*(arr + 8),
								*(arr + 9));
	}
	return nil;
}

static id string(char **avs, char **ave)
{
	register char *alloc;
	register int len;
	register id obj;

	len = length(*avs);
	alloc = malloc(len + 1);
	(void) memcpy(alloc, *avs, len);
	trim(alloc);
	obj = [getClass("NSString") stringWithCString: alloc];
	free(alloc);
	syntax(avs, ave);
	if(argdef->next == argdef)
		return execute1(obj, *(avs + 1));
	return execute1(obj, syntax2(ave, avs, syntax1(avs, ave)));
}

static void syntax(char **avs, char **ave)
{
	register struct Argument *argnew;
	register char **av1;
	register char **av2;

	av2 = ave;
	for(av1 = avs; av1 != av2; av1++)
		if(lastchr(*av1) == ':')
		{
			argnew = malloc(sizeof *argnew);
			argnew->next = argdef;
			argnew->prev = argdef->prev;
			argnew->arg = *(av1 + 1);
			argdef->prev->next = argnew;
			argdef->prev = argnew;
		}
}

static int syntax1(char **avs, char **ave)
{
	register char **av1;
	register char **av2;

	av1 = avs;
	av2 = ave;
	if(av1 == av2)
		return 0;
	if(lastchr(*av1) == ':')
		return syntax1(av1 + 1, av2) + strlen(*av1);
	return syntax1(av1 + 1, av2);
}

static char *syntax2(char **avs, char **ave, int len)
{
	register char **av1;
	register char **av2;
	register int l;

	av1 = avs;
	av2 = ave;
	l = len;
	if(av1 == av2)
	{
		register char *alloc;

		alloc = malloc(l + 1);
		*alloc = '\0';
		return alloc;
	}
	if(lastchr(*av1) == ':')
		return strcat(syntax2(av1 - 1, av2, l), *av1);
	return syntax2(av1 - 1, av2, l);
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
			register const char *name;
			register id obj;

			obj = execute(args, argp - 1);
			name = class_getName([obj class]);
			(void) printf("%s <%p>\n", name, obj);
		}
	}
}

static void word(void)
{
	register int c, c1;

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
				return;
			}
			*linep++ = c|QUOTE;
		}
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
