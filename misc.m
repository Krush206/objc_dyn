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

@implementation Shell (Miscellaneous)
- (int) readCharacter
{
	int rdstat;
	char cc;

	if((rdstat = read(0, &cc, (size_t) 1)) != 1) {
		if(rdstat == 0) exit(0); /* end of file */
		else exit(255); /* error */
	}
	return(cc);
}

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

	if ((a = n / 10))
		[self printNumber: a];
	[self putCharacter: n % 10 + '0'];
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
	if(self->promp == NULL) {
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

- (int) getCharacter: (int) flag
{
	register char c;

	if(self->peekc) {
		c = self->peekc;
		self->peekc = 0;
		return(c);
	}

	/* Support ungetCharacter via ungetc_buf */
	if(self->ungetc_buf) {
		c = self->ungetc_buf;
		self->ungetc_buf = 0;
		return(c);
	}

	if(self->argp > self->eargp) {
		self->argp -= 10;
		while((c = [self getCharacter: !DOLREPL]) != '\n');
		self->argp += 10;
		[self error: ERR_ARGS code: 255];
		self->gflg++;
		return(c);
	}
	if(self->linep > self->elinep) {
		self->linep -= 10;
		while((c = [self getCharacter: !DOLREPL]) != '\n');
		self->linep += 10;
		[self error: ERR_CHAR code: 255];
		self->gflg++;
		return(c);
	}
getd:
	if(self->dolp) {
		if ((c = *self->dolp++)) {
			if (flag == DOLREPQ)
				c |= QUOTE;
			return c;
		}
		if (self->idolp && ++self->idolp < self->dolc) {
			self->dolp = self->dolv[self->idolp];
			return(' ');
		}
		self->dolp = 0;
	}
	c = [self readCharacter];
	if(c == self->subchar && flag) {
		c = [self readCharacter];
		if(c >= '0' && c <= '9') {
			if(c - '0' < self->dolc)
				self->dolp = self->dolv[c - '0'];
			goto getd;
		}
		else if(c >= 'a' && c <= 'z') {
			self->dolp = self->seta[c - 'a'];
			goto getd;
		}
		else if(c == '$') {
			self->dolp = self->pidp;
			goto getd;
		}
		/* $* = $1 $2 .... */
		else if (c == '*') {
			if (self->dolc > 1) {
				self->idolp = 1;
				self->dolp = self->dolv[1];
			}
			goto getd;
		}
		else
			if(c != '\n')  c = [self readCharacter];
	}
	return(c & 0177);
}

- (void) ungetCharacter: (int) c
{
	self->ungetc_buf = c;
}

- (char *) integerToASCII: (int) n
{
	register int j;
	register char *cp;
	static char str[NUMSIZ];

	j = n;
	cp = &str[sizeof str - 1];
	for (;;) {
		*cp = j % 10 + '0';
		j /= 10;
		if(j == 0)
			return cp;
		cp--;
	}
	return NULL;
}

- (id) describeObject: (id) obj
{
	if(obj == nil)
		[self printString: "nil"];
	else if(obj == Nil)
		[self printString: "Nil"];
	else
	{
		[self printString: class_get_class_name(object_get_class(obj))];
		(void) printf(" <%p>", obj);
	}
	[self putCharacter: '\n'];
	return obj;
}
@end
