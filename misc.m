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

@implementation Shell (Miscellaneous)
- (void) printString: (const char *) as
{
	register const char *s;

	s = as;
	while(*s)
		[self putCharacter: *s++];
}

- (void) putCharacter: (int) c
{
	char cc;

	cc = c;
	write(2, &cc, (size_t) 1);
}

- (void) printNumber: (int) n
{
	register int a;

	if ((a = n/10))
		[self printNumber: a];
	[self putCharacter: n%10 + '0'];
}

- (int) anyCharacter: (int) c in: (const char *) as
{
	register const char *s;

	s = as;
	while(*s)
		if(*s++ == c)
			return(1);
	return(0);
}

- (int) equalString: (const char *) as1 to: (const char *) as2
{
	register const char *s1, *s2;

	s1 = as1;
	s2 = as2;
	while(*s1++ == *s2)
		if(*s2++ == '\0')
			return(1);
	return(0);
}

- (void) error: (const char *) s code: (int) exitno
{
	[self printString: s];
	[self printString: "\n"];
	if(*promp == NULL) {
		lseek(0, (off_t) 0, SEEK_END);
		exit(exitno);
	}
}

- (int) lastCharacter: (char *) cp
{
	register int c;

	c = cp[0];
	if(c == 0)
		return c;
	while((c = cp[1]) != 0)
		cp++;
	return c = cp[0];
}

- (void) scan: (struct Tree *) at selector: (SEL) sel
{
	typedef int (*method_t)(id, SEL, int);
	register char *p, **t, c;
	void *imp;

	t = at->DARR;
	imp = objc_msg_lookup(self, sel);
	while((p = *t++))
		while((c = *p))
			*p++ = (*(method_t) imp)(self, sel, c);
}

- (int) glob: (int) c
{
	if([self anyCharacter: c in: "[?*"])
		*gflg = 1;
	return(c);
}

- (int) trim: (int) c
{
	return(c&0177);
}

- (char *) integerToASCII: (int) n
{
	register int i;
	register char *cp;
	static char str[NUMSIZ];

	i = n;
	cp = &str[sizeof str - 1];
	for (;;) {
		*cp = i % 10 + '0';
		i /= 10;
		if(i == 0)
			return cp;
		cp--;
	}
	return NULL;
}

- (char *) getPIDPointer
{
	return pidp;
}

- (void) setPIDPointer: (char *) ptr
{
	(void) memcpy(pidp, ptr, sizeof pidp);
}

- (struct Tree *) getTreeBuffer
{
	return trebuf;
}

- (void) setTreeBuffer: (struct Tree *) ptr
{
	(void) memcpy(trebuf, ptr, sizeof trebuf);
}

- (char **) getArguments
{
	return args;
}

- (void) setArguments: (char **) ptr
{
	(void) memcpy(args, ptr, sizeof args);
}

- (char (*)[]) getSetASCII
{
	return seta;
}

- (void) setSetASCII: (char (*)[]) ptr
{
	(void) memcpy(seta, ptr, sizeof seta);
}

- (char *) getMessage
{
	return msg;
}

- (void) setMessage: (char *) ptr
{
	(void) memcpy(msg, ptr, sizeof msg);
}

- (char *) getLine
{
	return line;
}

- (void) setLine: (char *) ptr
{
	(void) memcpy(line, ptr, sizeof line);
}

- (struct Argument *) getArgumentBuffer
{
	return argbuf;
}

- (void) setArgumentBuffer: (struct Argument *) ptr
{
	(void) memcpy(argbuf, ptr, sizeof argbuf);
}

- (id) getFunction
{
	return func;
}

- (void) setFunction: (id) ptr
{
	func = ptr;
}

- (int *) getTreeCount
{
	static int ret;

	return treec = &ret;
}

- (int *) getErrorValue
{
	static int ret;

	return errval = &ret;
}

- (int *) getCurrentDollarPointer
{
	static int ret;

	return idolp = &ret;
}

- (char **) getDollarPointer
{
	static char *ret;

	return dolp = &ret;
}

- (char ***) getDollarVector
{
	static char **ret;

	return dolv = &ret;
}

- (int *) getDollarCount
{
	static int ret;

	return dolc = &ret;
}

- (char **) getPrompt
{
	static char *ret;

	return promp = &ret;
}

- (char **) getLinePointer
{
	static char *ret;

	return linep = &ret;
}

- (char **) getEndLinePointer
{
	static char *ret;

	return elinep = &ret;
}

- (char ***) getArgumentPointer
{
	static char **ret;

	return argp = &ret;
}

- (char ***) getEndArgumentPointer
{
	static char **ret;

	return eargp = &ret;
}

- (int *) getPeekCharacter
{
	static int ret;

	return peekc = &ret;
}

- (int *) getGlobFlag
{
	static int ret;

	return gflg = &ret;
}

- (int *) getError
{
	static int ret;

	return error = &ret;
}

- (int *) getUserID
{
	static int ret;

	return uid = &ret;
}

- (int *) getSetInterrupt
{
	static int ret;

	return setintr = &ret;
}

- (char **) getArgumentInput
{
	static char *ret;

	return arginp = &ret;
}

- (int *) getOneLineFlag
{
	static int ret;

	return onelflg = &ret;
}

- (int *) getStopError
{
	static int ret;

	return stoperr = &ret;
}

- (int *) getExecuteFlag
{
	static int ret;

	return execflg = &ret;
}

- (jmp_buf *) getJumpBuffer
{
	static jmp_buf ret;

	return jmp = &ret;
}

- (struct Argument *) getArgumentDefinition
{
	static struct Argument ret;

	return argdef = &ret;
}
@end
