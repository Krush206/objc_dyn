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
static int syntax1(char **, char **);
static char *syntax2(char **, char **, int);
static id construct(char **, char **, id);
static id construct1(char *, id, id);
static id construct2(id, SEL);
static void construct3(id, id);
static id invoke(id, id);
static id string(char *);

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
	if(ap2 == ap3)
		return alloc->obj = nil;
	return alloc->obj = execute(ap2, ap3);
}

static id construct(char **avs, char **ave, id obj)
{
	register char *alloc;

	printf("%s\n", *avs);
	alloc = syntax2(ave, avs, syntax1(avs, ave));
	if(alloc[0] != '\0')
		return construct1(alloc, getObject(*avs), obj);
	printf("free\n");
	free(alloc);
	return obj;
}

static id construct1(char *alloc, id var, id obj)
{
	register id sig;
	register id ret;

	printf("obj: %p\n", obj);
	sig = construct2(obj, sel_registerName(alloc));
	printf("sig: %p\n", sig);
	free(alloc);
	ret = [getClass("NSInvocation") invocationWithMethodSignature: sig];
	printf("ret: %p\n", ret);
	construct3(ret, sig);
	return invoke(var, ret);
}

static id construct2(id obj, SEL msg)
{
	register id op;
	register SEL mp;

	op = obj;
	mp = msg;
	if(class_isMetaClass(op = object_getClass(op)))
		return [op instanceMethodSignatureForSelector: mp];
	op = obj;
	return [op methodSignatureForSelector: mp];
}

static void construct3(id obj, id sig)
{
	register int len;
	register int i;
	register struct Argument *argnew;

	len = (int) [sig numberOfArguments];
	for(i = 2, argnew = argdef->next; i < len; i++, argnew = argnew->next)
		[obj setArgument: argnew->arg atIndex: i];
}

static id invoke(id var, id obj)
{
	register id op;
	register intptr_t *ret;

	op = obj;
	[op invokeWithTarget: var];
	ret = malloc(sizeof *ret);
	[op getReturnValue: ret];
	return *(id *) ret;
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
	if((*cp1)[0] == '\'' && lastchr(*cp1) == '\'')
		return string(*cp1);
	if((*cp1)[0] == '"' && lastchr(*cp1) == '"')
		return string(*cp1);
	syntax(cp1, ave);
	ret = getClass(*cp1);
	if(ret == nil)
		ret = getObject(*cp1);
	if(ret == nil)
		return nil;
	return construct(cp1, ave, ret);
}

static id string(char **avs, char **ave)
{
	register char *alloc;
	register int len;
	register id ret;

	len = strlen(*avs);
	alloc = malloc(len - 1);
	(void) strncpy(alloc, *avs + 1, len - 2);
	alloc[len - 2] = '\0';
	ret = [getClass("NSString") stringWithCString: alloc];
	free(alloc);
	return assign(avs, ave);
}

static void syntax(char **avs, char **ave)
{
	register struct Argument *argnew;
	register char **av;

	for(av = avs; av != ave; av++)
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

static int syntax1(char **avs, char **ave)
{
	register char **av;

	av = avs;
	if(av == ave)
		return 0;
	if(lastchr(*av) == ':')
		return syntax1(av + 1, ave) + strlen(*av);
	return syntax1(av + 1, ave);
}

static char *syntax2(char **avs, char **ave, int len)
{
	register char **av;
	register int l;

	av = avs;
	l = len;
	if(av == ave)
	{
		register char *alloc;

		alloc = malloc(l + 1);
		alloc[0] = '\0';
		return alloc;
	}
	if(lastchr(*av) == ':')
		return strcat(syntax2(av - 1, ave, l), *av);
	return syntax2(av - 1, ave, l);
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
