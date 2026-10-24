/*
 * Copyright (C) Caldera International Inc.  2001-2002.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code and documentation must retain the above
 *    copyright notice, this list of conditions and this disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and this disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed or owned by Caldera
 *    International, Inc.
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

@interface Shell (Private)
- (void) main;
- (id) assignVar: (const char *) name value: (id) val;
- (id) executeAvs: (char **) avs ave: (char **) ave;
- (id) execute1: (id) obj msg: (const char *) msg;
- (id) stringAvs: (char **) avs ave: (char **) ave;
- (void) syntaxAvs: (char **) avs ave: (char **) ave;
- (int) syntax1: (char **) avs ave: (char **) ave;
- (char *) syntax2: (char **) avs cp1: (char **) cp1 len1: (int) len;
- (void) main1;
- (void) word;
- (int) scan: (const char *) name;
- (id) resolveName: (const char *) name;
@end

char *promp;
char *linep;
char *elinep;
char **argp;
char **eargp;
int peekc;
int gflg;
int error;

char line[LINSIZ];
char *args[ARGSIZ];

char pidp[NUMSIZ];
char seta[26][EXPSIZ];
char *dolp;
int dolc;
char **dolv;
int idolp;
int treec;
jmp_buf jmp;

static void c_trim(char *s)
{
	register char *dst, *src;

	dst = s;
	src = s;
	while(*src == ' ' || *src == '\t')
		src++;
	while(*src)
		*dst++ = *src++;
	*dst = '\0';
	while(dst > s && (dst[-1] == ' ' || dst[-1] == '\t'))
		dst--;
	*dst = '\0';
}

int
main(void)
{
	id shell = [Shell new];
	[shell main];
	return 0;
}

@implementation Shell (Private)

- (void) main
{
	[self loadClass: "Object"];
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = NULL;
loop:
	if(promp != NULL)
		[self printString: promp];
	if(!peekc)
		peekc = [self getCharacter: DOLREPL];
	if(peekc == '\n' || peekc == 0) {
		/* End of input or empty line - reset and continue */
		if(peekc == 0) exit(0);
		peekc = 0;
		goto loop;
	}
	[self main1];
	goto loop;
}

/* Resolve a name: variable > class > object */
- (id) resolveName: (const char *) name
{
	id val;

	/* Check variable first */
	val = [self getVariable: name];
	if(val != nil)
		return val;

	/* Check class */
	Class cls = [self getClass: name];
	if(cls != Nil)
		return (id) cls;

	/* Check object */
	id obj = [self getObject: name];
	if(obj != nil)
		return obj;

	return nil;
}

/* Smalltalk assignment: var := value */
- (id) assignVar: (const char *) name value: (id) val
{
	if([self getClass: name] != Nil)
	{
		[self error: "cannot reassign a class" code: 255];
		return nil;
	}
	return [self setVariable: name value: val];
}

- (id) executeAvs: (char **) avs ave: (char **) ave
{
	register char **cp1;
	register char **cp2;
	register id ret;
	register int i;

	cp1 = &avs[0];
	if(cp1 == ave)
		return nil;

	/* Scan for Smalltalk assignment: var := expr */
	for(i = 0; cp1 + i < ave; i++)
	{
		if([self equalString: cp1[i] to: ":="])
		{
			if(cp1 + i + 1 == ave || cp1 + i + 2 > ave)
			{
				[self error: "invalid assignment" code: 255];
				return nil;
			}
			return [self assignVar: cp1[i-1] value: [self executeAvs: cp1 + i + 1 ave: ave]];
		}
	}

	/* Check for missing message */
	if([self equalString: cp1[1] to: "\n"])
	{
		/* Bare name: resolve and print */
		ret = [self resolveName: *cp1];
		if(ret != nil)
		{
			[self describeObject: ret];
			return ret;
		}
		[self error: "missing message" code: 255];
		return nil;
	}

	/* String literal */
	if([self scan: *cp1])
		return [self stringAvs: cp1 ave: ave];

	/* Resolve receiver name */
	[self syntaxAvs: cp1 ave: ave];
	ret = [self resolveName: *cp1];
	if(ret == nil)
		return nil;

	/* Build keyword selector from arguments with : */
	return [self execute1: ret msg: [self syntax2: ave cp1: cp1 len1: [self syntax1: cp1 ave: ave]]];
}

- (id) execute1: (id) obj msg: (const char *) msg
{
	int i;
	void *arr[10];
	struct ArgumentList *argnew;
	SEL sel;
	IMP imp;
	Method_t met;
	Class cls;

	i = 0;
	for(argnew = argdef.next; argnew != &argdef; argnew = argnew->next)
		i++;
	if(i > 9)
	{
		[self error: "too many arguments" code: 255];
		return nil;
	}
	i = 0;
	for(argnew = argdef.next; argnew != &argdef; argnew = argnew->next)
		arr[i++] = [self getObject: argnew->arg];
	sel = sel_register_name(msg);
	cls = object_get_class(obj);
	met = class_get_instance_method(cls, sel);
	if(met == METHOD_NULL)
	{
		[self printString: "@"];
		[self error: ": bad message" code: 255];
		return nil;
	}
	imp = objc_msg_lookup(obj, sel);
	switch(i)
	{
	case 0:
		return imp(obj, sel);
	case 1:
		return imp(obj, sel, arr[0]);
	case 2:
		return imp(obj, sel, arr[0], arr[1]);
	case 3:
		return imp(obj, sel, arr[0], arr[1], arr[2]);
	case 4:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3]);
	case 5:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4]);
	case 6:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4], arr[5]);
	case 7:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6]);
	case 8:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7]);
	case 9:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8]);
	case 10:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8], arr[9]);
	}
	return nil;
}

- (id) stringAvs: (char **) avs ave: (char **) ave
{
	register char *alloc;
	register int len;
	register id obj;

	len = strlen(avs[0]);
	alloc = malloc(len + 1);
	(void) memcpy(alloc, avs[0], len);
	c_trim(alloc);
	obj = [[self getClass: "NSString"] stringWithCString: alloc];
	free(alloc);
	[self syntaxAvs: avs ave: ave];
	if(argdef.next == &argdef)
		return [self execute1: obj msg: avs[1]];
	return [self execute1: obj msg: [self syntax2: ave cp1: avs len1: [self syntax1: avs ave: ave]]];
}

- (void) syntaxAvs: (char **) avs ave: (char **) ave
{
	register struct ArgumentList *argnew;
	register char **av1;
	register char **av2;

	av2 = ave;
	for(av1 = avs; av1 != av2; av1++)
		if([self lastCharacter: *av1] == ':')
		{
			argnew = malloc(sizeof *argnew);
			argnew->next = &argdef;
			argnew->prev = argdef.prev;
			argnew->arg = av1[1];
			argdef.prev->next = argnew;
			argdef.prev = argnew;
		}
}

- (int) syntax1: (char **) avs ave: (char **) ave
{
	register char **av1;
	register char **av2;

	av1 = avs;
	av2 = ave;
	if(av1 == av2)
		return 0;
	if([self lastCharacter: *av1] == ':')
		return [self syntax1: av1 + 1 ave: av2] + strlen(*av1);
	return [self syntax1: av1 + 1 ave: av2];
}

- (char *) syntax2: (char **) avs cp1: (char **) cp1 len1: (int) len
{
	register char **av1;
	register char **av2;
	register int l;

	av1 = avs;
	av2 = cp1;
	l = len;
	if(av1 == av2)
	{
		register char *alloc;

		alloc = malloc(l + 1);
		alloc[0] = '\0';
		return alloc;
	}
	if([self lastCharacter: *av1] == ':')
		return strcat([self syntax2: av1 - 1 cp1: cp1 len1: l], *av1);
	return [self syntax2: av1 - 1 cp1: cp1 len1: l];
}

- (void) main1
{
	register char *cp;

	argp = args;
	eargp = args+ARGSIZ-1;
	linep = line;
	elinep = line+LINSIZ-1;
	error = 0;
	gflg = 0;
	[self freeArgument: argdef.next];
	do {
		cp = linep;
		[self word];
	} while(*cp != '\n');
	if(gflg == 0) {
		if(error != 0)
			[self error: "syntax error" code: 255];
		else
		{
			register id obj;

			/* Only execute if we read at least one word */
			if(argp > args)
			{
				obj = [self executeAvs: args ave: argp - 1];
				[self describeObject: obj];
			}
		}
	}
}

/* Smalltalk symbol literal #symbol */
- (int) scan: (const char *) name
{
	return(*name == '\'' || *name == '"' || *name == '#');
}

- (void) word
{
	register int c, c1;

	*argp++ = linep;

loop:
	switch(c = [self getCharacter: DOLREPL]) {

	case ' ':
	case '\t':
		goto loop;

	case '\'':
	case '"':
		c1 = c;
		while((c = [self getCharacter: !DOLREPL]) != c1) {
			if(c == '\n') {
				error++;
				peekc = c;
				return;
			}
			*linep++ = c | QUOTE;
		}
		goto pack;

	case '#':
		/* Symbol literal */
		*linep++ = c;
		c = [self getCharacter: DOLREPL];
		while(c != ' ' && c != '\t' && c != '\n' && c != ':' &&
		      c != ';' && c != '&' && c != '|' && c != '<' &&
		      c != '>' && c != '(' && c != ')' && c != '^') {
			*linep++ = c;
			c = [self getCharacter: DOLREPL];
		}
		[self ungetCharacter: c];
		*linep++ = '\0';
		return;

	case ':':
		/* Could be := or selector : */
		c1 = [self getCharacter: DOLREPL];
		if(c1 == '=') {
			*linep++ = ':';
			*linep++ = '=';
			*linep++ = '\0';
			return;
		}
		[self ungetCharacter: c1];
		*linep++ = c;
		*linep++ = '\0';
		return;

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
		c = [self getCharacter: DOLREPL];
		if([self anyCharacter: c in: " '\"\t;&<>()|^\n:"]) {
			peekc = c;
			if([self anyCharacter: c in: "\"'"])
				goto loop;
			if(c == ':')
				*linep++ = [self getCharacter: !DOLREPL];
			*linep++ = '\0';
			return;
		}
		*linep++ = c;
	}
}

@end

@implementation Shell
@end
