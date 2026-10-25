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

@implementation Shell (Parser)

/* Resolve a name: variable > class > object */
- (id) resolve: (const char *) name
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
- (id) assignVariable: (const char *) name withValue: (id) newValue
{
	if([self getClass: name] != Nil)
	{
		[self error: "cannot reassign a class" code: 255];
		return nil;
	}
	return [self setVariable: name value: newValue];
}

- (id) execute: (char **) words count: (char **) end
{
	register char **cp1;
	register id ret;
	register int i;

	cp1 = &words[0];
	while(cp1 < end && **cp1 == '\n')
		cp1++;
	if(cp1 == end)
		return nil;

	/* Scan for Smalltalk assignment: var := expr */
	for(i = 0; cp1 + i < end; i++)
	{
		if([self equalString: cp1[i] to: ":="])
		{
			/* Find first non-newline token after := */
			char **after = cp1 + i + 1;
			while(after < end && **after == '\n')
				after++;
			if(after == end)
			{
				[self error: "invalid assignment" code: 255];
				return nil;
			}
			return [self assignVariable: cp1[i-1] withValue: [self execute: after count: end]];
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
		return [self string: cp1 count: end];

	/* Every entry requires a message */
	if(cp1 + 1 >= end)
	{
		[self error: "missing message" code: 255];
		return nil;
	}

	/* Resolve receiver name */
	[self collectArguments: cp1 count: end];
	ret = [self resolve: *cp1];
	if(ret == nil)
	{
		/* Undefined variable: return nil to be printed by describeObject */
		return nil;
	}

	/* If colon-terminated arguments exist, build keyword selector */
	if(self->argdef.next != &self->argdef)
		return [self perform: ret message: [self buildSelector: end - 1 count: cp1 length: [self selectorLength: cp1 count: end]]];

	/* Otherwise, chain each word as a sequential message */
	cp1++;

	/* Every entry requires at least one message */
	if(cp1 >= end || **cp1 == '\n' || **cp1 == '\0')
	{
		[self error: "missing message" code: 255];
		return nil;
	}

	while(cp1 < end && **cp1 != '\n' && **cp1 != '\0')
	{
		ret = [self perform: ret message: *cp1];
		if(ret == nil && self->error)
			return nil;
		cp1++;
	}
	return ret;
}

- (id) perform: (id) obj message: (const char *) msg
{
	int i;
	void *arr[10];
	struct ArgumentList *argnew;
	SEL sel;
	IMP imp;

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

	/* Special case: self returns the receiver */
	if([self equalString: msg to: "self"])
		return obj;

	/* Special case: class declaration "Superclass subclass: #Name" */
	if([self equalString: msg to: "subclass:"] && i == 1)
	{
		struct ArgumentList *a = self->argdef.next;
		const char *name = (const char *) a->arg;
		if(name != NULL && name[0] == '#')
			return [self declareClass: obj name: name + 1];
	}

	/* Special case: alloc/new use class_create_instance directly.
	 * Classic libobjc has no class-creation API, and GNUstep's alloc
	 * crashes on dynamically loaded classes. class_create_instance
	 * works for both statically and dynamically loaded classes. */
	if([self equalString: msg to: "alloc"])
		return class_create_instance((Class)obj);
	if([self equalString: msg to: "new"])
		return class_create_instance((Class)obj);

	/* Look up the method implementation.
	 * Class/meta-class receivers use objc_msg_lookup() — preserves
	 * GNUstep's doesNotRecognize: fallback for unknown selectors
	 * (test expects "does not recognize").  Instance receivers use
	 * class_get_instance_method() — objc_msg_lookup on a class object
	 * only finds class methods, not instance methods. */
	{
		IMP (*old_forward)(SEL) = __objc_msg_forward;
		IMP (*old_forward2)(id, SEL) = __objc_msg_forward2;

		if (class_is_class((Class)obj) || class_is_meta_class((Class)obj))
		{
			__objc_msg_forward = NULL;
			__objc_msg_forward2 = NULL;
			imp = objc_msg_lookup((Class)obj, sel);
			__objc_msg_forward = old_forward;
			__objc_msg_forward2 = old_forward2;
		}
		else
		{
			Method_t m = class_get_instance_method(object_get_class(obj), sel);
			imp = m ? m->method_imp : NULL;
		}
	}
	if(imp == NULL)
	{
		[self printString: "@"];
		[self error: ": bad message" code: 255];
		return nil;
	}

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

- (id) string: (char **) words count: (char **) end
{
	register char **cp1;

	[self collectArguments: words count: end];

	/* If colon-terminated arguments exist, build keyword selector */
	if(self->argdef.next != &self->argdef)
		return [self perform: nil message: [self buildSelector: end - 1 count: words length: [self selectorLength: words count: end]]];

	/* Every string requires a message (like all objects) */
	cp1 = words + 1;
	if(cp1 >= end || **cp1 == '\n' || **cp1 == '\0')
	{
		[self error: "missing message" code: 255];
		return nil;
	}

	/* Chain messages after the string */
	while(cp1 < end && **cp1 != '\n' && **cp1 != '\0')
	{
		return [self perform: nil message: *cp1];
	}
	return nil;
}

- (void) collectArguments: (char **) words count: (char **) end
{
	register struct ArgumentList *argnew;
	register char **av1;
	register char **av2;

	av2 = end;
	for(av1 = words; av1 != av2; av1++)
		if([self lastCharacter: *av1] == ':')
		{
			argnew = malloc(sizeof *argnew);
			argnew->next = &self->argdef;
			argnew->prev = self->argdef.prev;
			argnew->arg = (id)av1[1];
			self->argdef.prev->next = argnew;
			self->argdef.prev = argnew;
		}
}

- (int) selectorLength: (char **) words count: (char **) end
{
	register char **av1;
	register char **av2;

	av1 = words;
	av2 = end;
	if(av1 == av2)
		return 0;
	if([self lastCharacter: *av1] == ':')
		return [self selectorLength: av1 + 1 count: end] + strlen(*av1);
	return [self selectorLength: av1 + 1 count: end];
}

- (char *) buildSelector: (char **) words count: (char **) start length: (int) len
{
	register char **av1;
	register char **av2;
	register int l;

	av1 = words;
	av2 = start;
	l = len;
	if(av1 == av2)
	{
		register char *alloc;

		alloc = malloc(l + 1);
		alloc[0] = '\0';
		return alloc;
	}
	if([self lastCharacter: *av1] == ':')
		return strcat([self buildSelector: av1 - 1 count: start length: l], *av1);
	return [self buildSelector: av1 - 1 count: start length: l];
}

- (void) main
{
	register char *cp;

	[self loadClass: "Object"];
	self->promp = "% ";
	if(getuid() == 0)
		self->promp = "# ";
	if(!isatty(0))
		self->promp = NULL;

loop:
	if(self->promp != NULL)
		[self printString: self->promp];

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
				obj = [self execute: self->args count: self->argp];
				if(!self->output_done)
					[self describeObject: obj];
				self->output_done = 0;
			}
		}
	}
	goto loop;
}
@end
