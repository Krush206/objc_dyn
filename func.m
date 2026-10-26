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

#import "sh.h"

@implementation Function
- (struct Pack *) getBuiltin
{
	static struct Builtin bin[] = { { ":", @selector(dozip:) },
					{ "=", @selector(doset:) },
					{ "@", @selector(doobj:) },
					{ "chdir", @selector(dochdir:) },
					{ "login", @selector(dologin:) },
					{ "newgrp", @selector(donewgrp:) },
					{ "shift", @selector(doshift:) },
					{ "wait", @selector(dowait:) } };
	static struct Pack pack = { bin, sizeof bin / sizeof *bin };

	return &pack;
}

- (int) scan: (struct Tree *) t
{
	typedef void (*method_t)(id, SEL, struct Tree *);
	int compare;
	register int first, last, middle;
	void *imp;
	struct Builtin *bp;

	bp = [self getBuiltin]->ptr;
	first = 0;
	last = [self getBuiltin]->count - 1;
	while(first <= last) {
		middle = first + (last - first) / 2;
		compare = strcmp(t->DARR[0], bp[middle].bname);
		if(compare == 0) {
			imp = objc_msg_lookup(self, bp[middle].bfunc);
			(*(method_t) imp)(self, bp[middle].bfunc, t);
			return 1;
		}
		if(compare < 0)
			last = middle - 1;
		else
			first = middle + 1;
	}
	return 0;
}

- (void) dozip: (struct Tree *) t
{
	(void) t;
}

- (void) doset: (struct Tree *) t
{
	register char *name;
	register int i;

	name = t->DARR[1];
	if(name == NULL) {
		[sh error: ERR_EQUALS code: 255];
		return;
	}
	i = *name - 'a';
	if(i>25 || i<0) {
		[sh error: ERR_EQUALS code: 255];
		return;
	}
	[sh setVariable: i value: t->DARR[2]];
}

- (void) doobj: (struct Tree *) t
{
	char *msg;

	if(t->DARR[1] == NULL) {
		[sh printString: "@"];
		[sh error: ERR_BADMSG code: 255];
		return;
	}
	msg = [sh buildArguments: &t->DARR[1]];
	if(msg == NULL)
		return;
	[sh execute: sh message: msg];
}

- (void) dochdir: (struct Tree *) t
{
	if(t->DARR[1] == NULL) {
		[sh printString: "chdir"];
		[sh error: ERR_COUNT code: 255];
		return;
	}
	if(chdir(t->DARR[1]) < 0) {
		[sh printString: "chdir"];
		[sh error: ERR_BADDIR code: 255];
	}
}

- (void) dologin: (struct Tree *) t
{
	if(*[sh getPrompt])
		execv("/bin/login", t->DARR);
	[sh printString: "login: cannot execute\n"];
}

- (void) donewgrp: (struct Tree *) t
{
	if(*[sh getPrompt])
		execv("/bin/newgrp", t->DARR);
	[sh printString: "newgrp: cannot execute\n"];
}

- (void) doshift: (struct Tree *) t
{
	(void) t;
	if(*[sh getDollarCount] < 1) {
		[sh printString: "shift: no args\n"];
		return;
	}
	(*[sh getDollarVector])[1] = (*[sh getDollarVector])[0];
	(*[sh getDollarVector])++;
	(*[sh getDollarCount])--;
}

- (void) dowait: (struct Tree *) t
{
	(void) t;
	[sh wait: -1];
}

- (id) getShell
{
	return sh;
}

- (void) setShell: (id) ptr
{
	sh = ptr;
}
@end
