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
- (id) assignAp1: (char **) ap1 ap2: (char **) ap2;
- (id) executeAvs: (char **) avs ave: (char **) ave;
- (id) execute1: (id) obj msg: (const char *) msg;
- (id) stringAvs: (char **) avs ave: (char **) ave;
- (void) syntaxAvs: (char **) avs ave: (char **) ave;
- (int) syntax1: (char **) avs ave: (char **) ave;
- (char *) syntax2: (char **) avs cp1: (char **) cp1 len1: (int) len;
- (void) main1;
- (void) word;
- (int) scan: (const char *) name;
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
	[self loadClass: "NSObject"];
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = NULL;
loop:
	if(promp != NULL)
		[self printString: promp];
	peekc = [self getCharacter: DOLREPL];
	[self main1];
	goto loop;
}

- (id) assignAp1: (char **) ap1 ap2: (char **) ap2
{
	register struct ObjectList *obj;
	register struct ObjectList *alloc;
	register char **ap;

	ap = ap1;
	if(ap++ == ap2)
	{
		[self error: "invalid assignment" code: 255];
		return nil;
	}
	if([self getClass: *ap1] != Nil)
	{
		[self error: "cannot reassign a class" code: 255];
		return nil;
	}
	if((obj = [self getObjectRecord: *ap1]) != NULL)
	{
		obj->prev->next = obj->next;
		obj->next->prev = obj->prev;
		free(obj->name);
		free(obj);
	}
	alloc = malloc(sizeof *alloc);
	alloc->next = &objdef;
	alloc->prev = objdef.prev;
	alloc->name = strcpy(malloc(strlen(*ap1) + 1), *ap1);
	objdef.prev->next = alloc;
	objdef.prev = alloc;
	if(ap == ap2)
		return alloc->obj = nil;
	return alloc->obj = [self executeAvs: ap ave: ap2];
}

- (id) executeAvs: (char **) avs ave: (char **) ave
{
	register char **cp1;
	register char **cp2;
	register id ret;

	cp1 = &avs[0];
	if(cp1 == ave)
		return nil;
	if([self equalString: cp1[1] to: "\n"])
	{
		[self error: "missing message" code: 255];
		return nil;
	}
	cp2 = &avs[1];
	if([self equalString: *cp1 to: "="])
		return [self assignAp1: cp2 ap2: ave];
	if([self scan: *cp1])
		return [self stringAvs: cp1 ave: ave];
	[self syntaxAvs: cp1 ave: ave];
	ret = [self getClass: *cp1];
	if(ret == nil)
		ret = [self getObject: *cp1];
	if(ret == nil)
		return nil;
	if(argdef.next == &argdef)
		return [self execute1: ret msg: *cp2];
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
			register const char *name;
			register id obj;

			obj = [self executeAvs: args ave: argp - 1];
			name = class_get_class_name(object_get_class(obj));
			(void) printf("%s <%p>\n", name, obj);
		}
	}
}

- (int) scan: (const char *) name
{
	return(*name == '\'' || *name == '"');
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
		c = [self getCharacter: DOLREPL];
		if([self anyCharacter: c in: " '\"\t;&<>()|^\n"]) {
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
