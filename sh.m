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

int treec;
int errval;
int idolp;
char *dolp;
char (*pidp)[NUMSIZ];
char **dolv;
int dolc;
char *promp;
char *linep;
char *elinep;
char **argp;
char **eargp;
int peekc;
int gflg;
int error;
int uid;
int setintr;
char *arginp;
int onelflg;
int stoperr;
int execflg;
char (*seta)[26][EXPSIZ];
char (*line)[LINSIZ];
char *(*args)[ARGSIZ];
struct Tree (*trebuf)[TRESIZ];
jmp_buf jmp;

static struct ObjectList *objdef;
static struct ArgumentList *argdef;

int
main(int c, char *av[])
{
	return [Shell argc: c argv: av];
}

@implementation Shell
+ (int) argc: (int) c argv: (char *[]) av
{
	register id shell;
	register char **v;
	register int f;

	shell = class_create_instance(self);
	[shell loadClass: "Object"];
	objdef = [shell getObjectList];
	argdef = [shell getArgumentList];
	pidp = malloc(sizeof *pidp);
	(void) strcpy(*pidp, [shell integerToASCII: getpid()]);
	v = av;
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = NULL;
	stoperr = 0;
	if(c>1 && v[1][0]=='-' && v[1][1]=='e') {
		++stoperr;
		v[1] = v[0];
		++v;
		--c;
	}
	arginp = 0;
	execflg = onelflg = 0;
	if(c > 1) {
		promp = 0;
		if (*v[1]=='-') {
			execflg = 1;
			if (v[1][1]=='c' && c>2)
				arginp = v[2];
			else if (v[1][1]=='t')
				onelflg = 2;
		} else {
			close(0);
			f = open(v[1], 0);
			if(f < 0) {
				[shell printString: v[1]];
				[shell error: ERR_OPEN code: 255];
			}
		}
	}
	setintr = 0;
	if(execflg) {
		signal(SIGQUIT, SIG_DFL);
		signal(SIGINT, SIG_DFL);
		if (arginp==0&&onelflg==0)
			setintr++;
	}
	dolv = v;
	dolc = c;
loop:
	if(promp != NULL)
		[shell printString: promp];
	peekc = [shell getCharacter: !DOLREPL];
	[shell main];
	goto loop;
	return 0;
}

- (void) main
{
	register char  *cp;
	register struct Tree *t;

	args = malloc(sizeof *args);
	line = malloc(sizeof *line);
	seta = malloc(sizeof *seta);
	pidp = malloc(sizeof *pidp);
	trebuf = malloc(sizeof *trebuf);
	argp = *args;
	eargp = *args+ARGSIZ-1;
	linep = *line;
	elinep = *line+LINSIZ-1;
	error = 0;
	gflg = 0;
	do {
		cp = linep;
		[self word];
	} while(*cp != '\n');
	treec = 0;
	if(gflg == 0) {
		if(error == 0) {
			setjmp(jmp);
			if (error)
				return;
			t = [self syntax: *args end: argp];
		}
		if(error != 0)
			[self error: ERR_SYNTAX code: 255]; else
			[self execute: t input: NULL output: NULL];
	}
}

- (struct Tree *) tree
{
	if(treec == TRESIZ) {
		[self printString: "Command line overflow\n"];
		error++;
		longjmp(jmp, 1);
	}
	return(&(*trebuf)[treec++]);
}
@end
