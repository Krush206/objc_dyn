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

int getc(void)
{
	register char c;

	if(peekc) {
		c = peekc;
		peekc = 0;
		return(c);
	}
	if(argp > eargp) {
		argp -= 10;
		while((c=getc()) != '\n');
		argp += 10;
		err("Too many args",255);
		gflg++;
		return(c);
	}
	if(linep > elinep) {
		linep -= 10;
		while((c=getc()) != '\n');
		linep += 10;
		err("Too many characters",255);
		gflg++;
		return(c);
	}
	return c = readc();
}

int readc(void)
{
	int rdstat;
	char cc;

	if((rdstat = read(0, &cc, 1)) != 1) {
		if(rdstat==0) exit(0); /* end of file*/
		else exit(255); /* error */
	}
	return(cc);
}

void prs(const char *as)
{
	register const char *s;

	s = as;
	while(*s)
		putc(*s++);
}

void putc(int c)
{
	char cc;

	cc = c;
	write(2, &cc, 1);
}

void prn(int n)
{
	register int a;

	if ((a = n/10))
		prn(a);
	putc(n%10 + '0');
}

int any(int c, const char *as)
{
	register const char *s;

	s = as;
	while(*s)
		if(*s++ == c)
			return(1);
	return(0);
}

int equal(const char *as1, const char *as2)
{
	register const char *s1, *s2;

	s1 = as1;
	s2 = as2;
	while(*s1++ == *s2)
		if(*s2++ == '\0')
			return(1);
	return(0);
}

void err(const char *s, int exitno)
{

	prs(s);
	prs("\n");
	if(promp == NULL) {
		lseek(0, 0L, 2);
		exit(exitno);
	}
}

char lastchr(char *cp)
{

    if (!cp)
        return (0);
    if (!*cp)
        return (0);
    while (cp[1])
        cp++;
    return (*cp);
}
