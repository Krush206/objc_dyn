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

char *promp;
char *linep;
char *elinep;
char **argp;
char **eargp;
int peekc;
int gflg;
int error;
int dolc;
int idolp;
char pidp[NUMSIZ];
char *dolp;
char **dolv;
char seta[26][EXPSIZ];
int treec;
char line[LINSIZ];
char *args[ARGSIZ];
struct Tree trebuf[TRESIZ];
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
	id shell;

	shell = class_create_instance(self);
	[shell loadClass: "Object"];
	objdef = [shell getObjectList];
	argdef = [shell getArgumentList];
	(void) strcpy(pidp, [shell integerToASCII: getpid()]);
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = NULL;
loop:
	if(promp != NULL)
		[shell printString: promp];
	peekc = [shell getCharacter: !DOLREPL];
	[shell main];
	goto loop;
	object_dispose(shell);
	return 0;
}

- (id) execute: (id) obj message: (const char *) msg
{
	int i;
	register SEL sel;
	register IMP imp;
	void *arr[10];
	Method_t met;
	Class cls;
	register struct ArgumentList *argnew;

	i = 0;
	for(argnew = argdef->next; argnew != argdef; argnew = argnew->next)
		i++;
	if(i > 9)
	{
		[self error: "too many arguments" code: 255];
		return nil;
	}
	i = 0;
	for(argnew = argdef->next; argnew != argdef; argnew = argnew->next)
		arr[i++] = [self getObject: argnew->arg];
	sel = sel_register_name(msg);
	cls = object_get_class(obj);
	met = class_get_instance_method(cls, sel);
	if(met == METHOD_NULL) {
		[self printString: "@"];
		[self error: ERR_BADMSG code: 255];
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
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4],
								     arr[5]);
	case 7:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4],
								     arr[5],
								     arr[6]);
	case 8:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4],
								     arr[5],
								     arr[6],
								     arr[7]);
	case 9:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4],
								     arr[5],
								     arr[6],
								     arr[7],
								     arr[8]);
	case 10:
		return imp(obj, sel, arr[0], arr[1], arr[2], arr[3], arr[4],
								     arr[5],
								     arr[6],
								     arr[7],
								     arr[8],
								     arr[9]);
	}
	return nil;
}

- (char *) buildArguments: (char **) word
{
	register struct ArgumentList *new;
	register char **wp;
	char *sel;
	register char *cur;
	size_t len;

	if(word[0] == NULL)
		return NULL;
	len = 0;
	for(wp = word; *wp; wp++)
		if([self lastCharacter: *wp] == ':') {
			if(wp[1] == NULL) {
				[self printString: "@"];
				[self error: ERR_BADMSG code: 255];
				return NULL;
			}
			len += strlen(*wp);
			new = malloc(sizeof *new);
			new->arg = wp[1];
			new->next = argdef;
			new->prev = argdef->prev;
			argdef->prev->next = new;
			argdef->prev = new;
		}
	if(len == 0)
		return strcpy(malloc(strlen(word[0]) + 1), word[0]);
	sel = malloc(len + 1);
	cur = sel;
	for(wp = word; *wp; wp++)
		if([self lastCharacter: *wp] == ':') {
			len = strlen(*wp);
			(void) memcpy(cur, *wp, len);
			cur += len;
		}
	*cur = '\0';
	return sel;
}

- (void) word
{
	register char c, c1;
	register dolflag;

	*argp++ = linep;

loop:
	switch(c = [self getCharacter: DOLREPL]) {

	case ' ':
	case '\t':
		goto loop;

	case '\'':	/* '...' : what you see is what you get */
	case '"':	/* "..." : \", \$, $ substitution */
		c1 = c;
		dolflag = (c == '"' && !dolp) ? DOLREPQ : !DOLREPL;
		while((c=[self getCharacter: dolflag]) != c1) {
			if(c == '\n') {
				error++;
				peekc = c;
				return;
			}
			if (c1 == '"' &&
			    c == '\\' &&
			    ((peekc = [self getCharacter: !DOLREPL]) == '$' ||
			     peekc == '"')) {
				c = peekc;
				peekc = 0;
			}
			*linep++ = c|QUOTE;
		}
		goto pack;

	case '&':
	case '|':
		*linep++ = c;
		if((peekc=[self getCharacter: DOLREPL]) == c)
			peekc = 0;
		else
			linep--;
	case ';':
	case '<':
	case '>':
	case '(':
	case ')':
	case '^':
	case '\n':
		*linep++ = c;
		*linep++ = '\0';
		return;
	case '\\':
		if ((c=[self getCharacter: !DOLREPL])=='\n') goto loop;
		else {
			c |= QUOTE;
			break;
		}
	}

	peekc = c;

pack:
	for(;;) {
		if ((c = [self getCharacter: DOLREPL])=='\\') {
			if ((c=[self getCharacter: !DOLREPL])=='\n') c = ' ';
			else c |= QUOTE;
		}
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

- (void) expand: (int) i value: (char *) na
{
	register char *st, *np;
	char c;

	st = seta[i];
	np = na;
	if(np == NULL)
		goto null;
	for (;;) {
		c = *np++ & 0177;
		*st++ = c;
		if(c=='\n' || c=='\0') break;
	}
	if(c=='\n') st++;
null:
	*st = '\0';
}

- (void) main
{
	register char  *cp;
	register struct Tree *t;

	argp = args;
	eargp = args+ARGSIZ-1;
	linep = line;
	elinep = line+LINSIZ-1;
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
			t = [self syntax: args end: argp];
		}
		if(error != 0)
			[self error: ERR_SYNTAX code: 255]; else
			[self execute: t input: NULL output: NULL];
	}
}

- (void) execute: (struct Tree *) t input: (int *) pf1 output: (int *) pf2
{
	int i, f, pv[2];
	register struct Tree *t1;
	register char *cp1, *cp2;

	if(t == NULL)
		return;
	switch(t->DTYP) {

	case TCOM:
		cp1 = t->DARR[0];
		cp2 = t->DARR[1];
		if([self equalString: cp1 to: "@"]) {
			char *msg;

			if(cp2 == NULL) {
				[self printString: cp1];
				[self error: ERR_BADMSG code: 255];
				break;
			}
			msg = [self buildArguments: &t->DARR[1]];
			if(msg == NULL)
				break;
			[self execute: self message: msg];
			free(msg);
			break;
		}
		if([self equalString: cp1 to: "="]) {
			if(cp2 == NULL) {
				[self error: ERR_EQUALS code: 255];
				break;
			}
			i = *cp2 - 'a';
			if(i>25 || i<0) {
				[self error: ERR_EQUALS code: 255];
				break;
			}
			[self expand: i value: t->DARR[2]];
			break;
		}
		if([self equalString: cp1 to: "chdir"]) {
			if(t->DARR[1] != 0) {
				if(chdir(t->DARR[1]) < 0) {
					[self printString: cp1];
					[self error: ERR_BADDIR code: 255];
				}
				break;
			}
			[self printString: cp1];
			[self error: ERR_COUNT code: 255];
			break;
		}
		if([self equalString: cp1 to: "shift"]) {
			if(dolc < 1) {
				[self printString: "shift: no args\n"];
				break;
			}
			dolv[1] = dolv[0];
			dolv++;
			dolc--;
			break;
		}
		if([self equalString: cp1 to: "login"]) {
			if(promp != 0) {
				execv("/bin/login", t->DARR);
			}
			[self printString: "login: cannot execute\n"];
			break;
		}
		if([self equalString: cp1 to: "newgrp"]) {
			if(promp != 0) {
				execv("/bin/newgrp", t->DARR);
			}
			[self printString: "newgrp: cannot execute\n"];
			break;
		}
		if([self equalString: cp1 to: "wait"]) {
			[self wait: -1];
			break;
		}
		if([self equalString: cp1 to: ":"])
			break;

	case TPAR:
		f = t->DFLG;
		i = 0;
		if((f&FPAR) == 0)
			i = fork();
		if(i == -1) {
			[self error: ERR_AGAIN code: 255];
			break;
		}
		if(i != 0) {
			if((f&FPIN) != 0) {
				close(pf1[0]);
				close(pf1[1]);
			}
			if((f&FPRS) != 0) {
				[self printNumber: i];
				[self printString: "\n"];
			}
			if((f&FAND) != 0)
				break;
			if((f&FPOU) == 0)
				[self wait: i];
			break;
		}
		if(t->DLEF != 0) {
			close(0);
			i = open(t->DLPT, 0);
			if(i < 0) {
				[self printString: t->DLPT];
				[self error: ERR_OPEN code: 255];
				exit(255);
			}
		}
		if(t->DRIT != 0) {
			if((f&FCAT) != 0) {
				i = open(t->DRPT, 1);
				if(i >= 0) {
					lseek(i, 0L, 2);
					goto f1;
				}
			}
			i = creat(t->DRPT, 0666);
			if(i < 0) {
				[self printString: t->DRPT];
				[self error: ERR_CREATE code: 255];
				exit(255);
			}
f1:
			close(1);
			dup(i);
			close(i);
		}
		if((f&FPIN) != 0) {
			close(0);
			dup(pf1[0]);
			close(pf1[0]);
			close(pf1[1]);
		}
		if((f&FPOU) != 0) {
			close(1);
			dup(pf2[1]);
			close(pf2[0]);
			close(pf2[1]);
		}
		if((f&FINT)!=0 && t->DLEF==0 && (f&FPIN)==0) {
			close(0);
			open("/dev/null", 0);
		}
		if((f&FINT) == 0) {
			signal(SIGINT, SIG_IGN);
			signal(SIGQUIT, SIG_IGN);
		}
		if(t->DTYP == TPAR) {
			if((t1 = t->DSTR))
				t1->DFLG |= f&FINT;
			[self execute: t input: pf1 output: pf2];
			exit(255);
		}
		gflg = 0;
		for(i = 0; (cp1 = t->DARR[i]) != NULL; i++)
			for(cp2 = cp1; *cp2; cp2++) {
				if([self anyCharacter: *cp2 in: "[?*"])
					gflg = 1;
				*cp2 &= 0177;
			}
		if(gflg) {
			t->DARR[0] = "/etc/glob";
			t->DARR[1] = NULL;
			execv(t->DARR[0], t->DARR);
			[self printString: "glob: cannot execute\n"];
			exit(255);
		}
		*linep = 0;
		[self execute: t->DARR[0] tree: t];
		[self printString: t->DARR[0]];
		[self error: ERR_FOUND code: 255];
		exit(255);

	case TFIL:
		f = t->DFLG;
		pipe(pv);
		t1 = t->DLEF;
		t1->DFLG |= FPOU | (f&(FPIN|FINT|FPRS));
		[self execute: t1 input: pf1 output: pv];
		t1 = t->DRIT;
		t1->DFLG |= FPIN | (f&(FPOU|FINT|FAND|FPRS));
		[self execute: t1 input: pv output: pf2];
		break;

	case TLST:
		f = t->DFLG&FINT;
		if((t1 = t->DLEF))
			t1->DFLG |= f;
		[self execute: t1 input: pf1 output: pf2];
		if((t1 = t->DRIT))
			t1->DFLG |= f;
		[self execute: t1 input: pf1 output: pf2];
	}
}

/*
 * syntax
 *	empty
 *	syn1
 */

- (struct Tree *) syntax: (char **) p1 end: (char **) p2
{
	while(p1 != p2) {
		if([self anyCharacter: **p1 in: ";&\n"])
			p1++; else
			return [self syn1: p1 end: p2];
	}
	return(0);
}

/*
 * syn1
 *	syn2
 *	syn2 & syntax
 *	syn2 ; syntax
 */

- (struct Tree *) syn1: (char **) p1 end: (char **) p2
{
	register char **p;
	register struct Tree *t;
	int l;

	l = 0;
	for(p=p1; p!=p2; p++)
	switch(**p) {

	case '(':
		l++;
		continue;

	case ')':
		l--;
		continue;

	case '&':
	case ';':
	case '\n':
		if(l == 0) {
			register struct Tree *t1;

			l = **p;
			t = [self tree];
			t->DTYP = TLST;
			t->DLEF = [self syn2: p1 end: p];
			t->DFLG = 0;
			if(l == '&') {
				t1 = t->DLEF;
				t->DFLG |= FAND|FPRS|FINT;
			}
			if((t1 = [self syntax: p+1 end: p2]))
				t->DRIT = t1; else
				t->DRIT = 0;
			return(t);
		}
	}
	if(l == 0)
		return [self syn2: p1 end: p2];
	error++;
	return(0);
}

/*
 * syn2
 *	syn3
 *	syn3 | syn2
 */

- (struct Tree *) syn2: (char **) p1 end: (char **) p2
{
	register char **p;
	register int l;
	register struct Tree *t;

	l = 0;
	for(p=p1; p!=p2; p++)
	switch(**p) {

	case '(':
		l++;
		continue;

	case ')':
		l--;
		continue;

	case '|':
	case '^':
		if(l == 0) {
			t = [self tree];
			t->DTYP = TFIL;
			t->DLEF = [self syn3: p1 end: p];
			t->DRIT = [self syn2: p+1 end: p2];
			t->DFLG = 0;
			return(t);
		}
	}
	return [self syn3: p1 end: p2];
}

/*
 * syn3
 *	( syn1 ) [ < in  ] [ > out ]
 *	word word* [ < in ] [ > out ]
 */

- (struct Tree *) syn3: (char **) p1 end: (char **) p2
{
	register char **p;
	char **lp, **rp, *i, *o;
	register struct Tree *t;
	int n, l, c, flg;

	flg = 0;
	if(**p2 == ')')
		flg |= FPAR;
	lp = 0;
	rp = 0;
	i = 0;
	o = 0;
	n = 0;
	l = 0;
	for(p=p1; p!=p2; p++)
	switch(c = **p) {

	case '(':
		if(l == 0) {
			if(lp != 0)
				error++;
			lp = p+1;
		}
		l++;
		continue;

	case ')':
		l--;
		if(l == 0)
			rp = p;
		continue;

	case '>':
		p++;
		if(p!=p2 && **p=='>')
			flg |= FCAT; else
			p--;

	case '<':
		if(l == 0) {
			p++;
			if(p == p2) {
				error++;
				p--;
			}
			if([self anyCharacter: **p in: "<>("])
				error++;
			if(c == '<') {
				if(i != 0)
					error++;
				i = *p;
				continue;
			}
			if(o != 0)
				error++;
			o = *p;
		}
		continue;

	default:
		if(l == 0)
			p1[n++] = *p;
	}
	if(lp != 0) {
		if(n != 0)
			error++;
		t = [self tree];
		t->DTYP = TPAR;
		t->DSTR = [self syn1: lp end: rp];
		goto out;
	}
	if(n == 0)
		error++;
	p1[n++] = 0;
	t = [self tree];
	t->DTYP = TCOM;
	for(l=0; l<n; l++)
		t->DARR[l] = p1[l];
out:
	t->DFLG = flg;
	t->DLPT = i;
	t->DRPT = o;
	return(t);
}

- (struct Tree *) tree
{
	if(treec == TRESIZ) {
		[self printString: "Command line overflow\n"];
		error++;
		longjmp(jmp, 1);
	}
	return(&trebuf[treec++]);
}

- (void) wait: (int) i
{
	register int p, e;
	int s;

	for(;;) {
		p = wait(&s);
		if(p == -1)
			break;
		e = s&0177;
		if(e) {
			if(e>=NSIG) {
				if(p != i) {
					[self printNumber: p];
					[self printString: ": "];
				}
				[self printString: "Signal "];
				[self printNumber: e];
				if(s&0200)
					[self printString: " -- Core dumped"];
			}
			else
				[self printString: strsignal(e)];
			[self error: "" code: (s>>8)|e];
		}
	}
}

- (void) execute: (char *) f tree: (struct Tree *) at
{
	register char *path;
	register char *cp;
	register char *sp;
	char cmd[CMDSIZ];
	int txe2big;
	int txeacces;
	int txtbsy;

	path = getenv("PATH");
	if(path == NULL)
		path = "/bin:/usr/bin";
	txeacces = txe2big = txtbsy = 0;
	if([self anyCharacter: '/' in: f])
		path = "";
	do {
		cp = cmd;
		while(*path != ':' && *path != '\0') {
			if(cp >= &cmd[CMDSIZ-1])
				goto toolong;
			*cp++ = *path++;
		}
		if(cp != cmd) {
			if(cp >= &cmd[CMDSIZ-1])
				goto toolong;
			*cp++ = '/';
		}
		for(sp = f; *sp; sp++) {
			if(cp >= &cmd[CMDSIZ-1])
				goto toolong;
			*cp++ = *sp;
		}
		*cp = '\0';
		if(*path != '\0')
			path++;
		else
			path = NULL;
retry:
		execv(cmd, at->DARR);
		switch(errno) {
		case ENOEXEC:
			at->DARR[0] = "/bin/osh";
			at->DARR[1] = NULL;
			execv(at->DARR[0], at->DARR);
			[self printString: "No shell!\n"];
			exit(255);
		case EACCES:
			txeacces++;
			break;
		case ENOMEM:
			[self printString: f];
			[self error: ERR_LARGE code: 255];
			exit(255);
		case E2BIG:
			txe2big++;
			break;
		case ETXTBSY:
			if((txtbsy += 10) > 60) {
				[self printString: f];
				[self error: ": text busy" code: 255];
				exit(255);
			}
			sleep(txtbsy);
			goto retry;
		}
	} while(path != NULL);
	if(txe2big) {
		[self printString: f];
		[self error: ": argument list too long" code: 255];
		exit(255);
	}
	if(txeacces) {
		[self printString: f];
		[self error: ": file not executable" code: 255];
		exit(255);
	}
	return;
toolong:
	[self printString: f];
	[self error: ": path too long" code: 255];
	exit(255);
}
@end
