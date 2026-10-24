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

static void c_trim(char *s)
{
	register char *dst, *src;

	dst = s;
	src = s;
	while(*src == ' ' || *src == '\t')
		src++;
	while(*src)
		*dst++ = *src++ & 0177;
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
	self->promp = "% ";
	if(getuid() == 0)
		self->promp = "# ";
	if(!isatty(0))
		self->promp = NULL;
loop:
	if(self->promp != NULL)
		[self printString: self->promp];
	if(!self->peekc)
		self->peekc = [self getCharacter: DOLREPL];
	if(self->peekc == '\n' || self->peekc == 0) {
		if(self->peekc == 0) exit(0);
		self->peekc = 0;
		goto loop;
	}
	[self main1];
	goto loop;
}

/* Resolve a name: variable > class > object */
- (id) resolveName: (const char *) name
{
	id val;

	val = [self getVariable: name];
	if(val != nil)
		return val;

	Class cls = [self getClass: name];
	if(cls != Nil)
		return (id) cls;

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
	register id ret;
	register int i;

	cp1 = &avs[0];
	while(cp1 < ave && **cp1 == '\n')
		cp1++;
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

	/* Smalltalk symbol literal #symbol (self-evaluating) */
	if((*cp1)[0] == '#')
	{
		id sym = [self internSymbol: *cp1 + 1];
		[self printString: "#"];
		[self printString: ((struct Symbol *)sym)->name];
		[self putCharacter: '\n'];
		self->output_done = 1;
		return nil;
	}

	/* String literal */
	if([self scan: *cp1])
		return [self stringAvs: cp1 ave: ave];

	/* Check for missing message (bare name) */
	if(cp1 + 1 >= ave || [self equalString: cp1[1] to: "\n"])
	{
		ret = [self resolveName: *cp1];
		if(ret != nil)
			return ret;
		if(cp1 + 1 >= ave)
			[self error: "missing message" code: 255];
		return nil;
	}

	/* Resolve receiver name */
	[self syntaxAvs: cp1 ave: ave];
	ret = [self resolveName: *cp1];
	if(ret == nil)
		return nil;

	return [self execute1: ret msg: [self syntax2: ave - 1 cp1: cp1 len1: [self syntax1: cp1 ave: ave]]];
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
	for(argnew = self->argdef.next; argnew != &self->argdef; argnew = argnew->next)
		i++;
	if(i > 9)
	{
		[self error: "too many arguments" code: 255];
		return nil;
	}
	i = 0;
	for(argnew = self->argdef.next; argnew != &self->argdef; argnew = argnew->next)
		arr[i++] = [self getObject: (const char *) argnew->arg];
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
	register char **cp1;
	int had_args;

	[self syntaxAvs: avs ave: ave];
	had_args = (self->argdef.next != &self->argdef);
	if(!had_args)
	{
		/* Find last non-newline word */
		char **last = ave - 1;
		while(last > avs && **last == '\n')
			last--;
		if(last == avs)
		{
			/* Single bare string: print content without quotes */
			register char *s = *avs;
			while(*s)
			{
				if(*s != '\'')
					[self putCharacter: *s & 0177];
				s++;
			}
			self->output_done = 1;
			return nil;
		}
		return [self execute1: nil msg: *avs];
	}
	cp1 = avs;
	return [self execute1: nil msg: [self syntax2: ave - 1 cp1: cp1 len1: [self syntax1: cp1 ave: ave]]];
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
			argnew->next = &self->argdef;
			argnew->prev = self->argdef.prev;
			argnew->arg = av1[1];
			self->argdef.prev->next = argnew;
			self->argdef.prev = argnew;
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

	self->argp = self->args;
	self->eargp = self->args + ARGSIZ - 1;
	self->linep = self->line;
	self->elinep = self->line + LINSIZ - 1;
	self->error = 0;
	self->gflg = 0;
	self->output_done = 0;
	[self freeArgument: self->argdef.next];
	do {
		cp = self->linep;
		[self word];
	} while(*cp != '\n');
	if(self->gflg == 0) {
		if(self->error != 0)
			[self error: "syntax error" code: 255];
		else
		{
			register id obj;

			if(self->argp > self->args)
			{
				obj = [self executeAvs: self->args ave: self->argp];
				if(!self->output_done)
					[self describeObject: obj];
				self->output_done = 0;
			}
		}
	}
}

/* Smalltalk symbol literal #symbol */
- (int) scan: (const char *) name
{
	return((*name & QUOTE) != 0);
}

- (void) word
{
	register int c, c1;

	*self->argp++ = self->linep;

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
				self->error++;
				self->peekc = c;
				return;
			}
			*self->linep++ = c | QUOTE;
		}
		goto pack;

	case '#':
		*self->linep++ = c;
		c = [self getCharacter: DOLREPL];
		while(c != ' ' && c != '\t' && c != '\n' && c != ':' &&
		      c != ';' && c != '&' && c != '|' && c != '<' &&
		      c != '>' && c != '(' && c != ')' && c != '^') {
			*self->linep++ = c;
			c = [self getCharacter: DOLREPL];
		}
		[self ungetCharacter: c];
		*self->linep++ = '\0';
		return;

	case ':':
		c1 = [self getCharacter: DOLREPL];
		if(c1 == '=') {
			*self->linep++ = ':';
			*self->linep++ = '=';
			*self->linep++ = '\0';
			return;
		}
		[self ungetCharacter: c1];
		*self->linep++ = c;
		*self->linep++ = '\0';
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
		*self->linep++ = c;
		*self->linep++ = '\0';
		return;
	}

	self->peekc = c;

pack:
	for(;;) {
		c = [self getCharacter: DOLREPL];
		if([self anyCharacter: c in: " '\"\t;&<>()|^\n:"]) {
			self->peekc = c;
			if([self anyCharacter: c in: "\"'"])
				goto loop;
			if(c == ':')
				*self->linep++ = [self getCharacter: !DOLREPL];
			*self->linep++ = '\0';
			return;
		}
		*self->linep++ = c;
	}
}

@end

@implementation Shell
@end
