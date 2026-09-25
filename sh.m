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

static void texec(struct Tree *);
static void main1(void);
static void word(void);
static void execute(struct Tree *, int *, int *);
static id execute1(id, const char *);
static id assign(char **, char **);
static struct Tree *syntax(char **, char **);
static struct Tree *syn1(char **, char **);
static struct Tree *syn2(char **, char **);
static struct Tree *syn3(char **, char **);
static struct Tree *tree(void);
static void pwait(int);

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

static int treec;

static char line[LINSIZ];
static char *args[ARGSIZ];

static struct Object *objdef;

static struct Argument *argdef;

static struct Tree trebuf[TRESIZ];

static jmp_buf jmp;

int
main(void)
{
	loadClass("Object");
	objdef = getObjectList();
	argdef = getArgumentList();
	(void) strcpy(pidp, itoa(getpid()));
	promp = "% ";
	if(getuid() == 0)
		promp = "# ";
	if(!isatty(0))
		promp = NULL;
loop:
	if(promp != NULL)
		prs(promp);
	peekc = getc(!DOLREPL);
	main1();
	goto loop;
}

static id
execute1(id obj, const char *msg)
{
	int i;
	SEL sel;
	IMP imp;
	void *arr[10];
	struct Argument *argnew;

	i = 0;
	for(argnew = argdef->next; argnew != argdef; argnew = argnew->next)
		i++;
	if(i > 9)
	{
		err("too many arguments", 255);
		return nil;
	}
	i = 0;
	for(argnew = argdef->next; argnew != argdef; argnew = argnew->next)
		arr[i++] = getObject(argnew->arg);
	sel = sel_register_name(msg);
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

static void
word(void)
{
	register char c, c1;
	register dolflag;

	*argp++ = linep;

loop:
	switch(c = getc(DOLREPL)) {

	case ' ':
	case '\t':
		goto loop;

	case '\'':	/* '...' : what you see is what you get */
	case '"':	/* "..." : \", \$, $ substitution */
		c1 = c;
		dolflag = (c == '"' && !dolp) ? DOLREPQ : !DOLREPL;
		while((c=getc(dolflag)) != c1) {
			if(c == '\n') {
				error++;
				peekc = c;
				return;
			}
			if (c1 == '"' && c == '\\' &&
				((peekc = getc(!DOLREPL)) == '$' ||
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
		if((peekc=getc(DOLREPL)) == c)
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
		if ((c=getc(!DOLREPL))=='\n') goto loop;
		else {
			c |= QUOTE;
			break;
		}
	}

	peekc = c;

pack:
	for(;;) {
		if ((c = getc(DOLREPL))=='\\') {
			if ((c=getc(!DOLREPL))=='\n') c = ' ';
			else c |= QUOTE;
		}
		if(any(c, " '\"\t;&<>()|^\n:")) {
			peekc = c;
			if(any(c, "\"'"))
				goto loop;
			if(c == ':')
				*linep++ = getc(!DOLREPL);
			*linep++ = '\0';
			return;
		}
		*linep++ = c;
	}
}

static void
rdval(int i, char *na)
{
	register char *st, *np;
	char c;

	st = seta[i];
	np = na;
	if(np == 0)
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

static void
main1(void)
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
		word();
	} while(*cp != '\n');
	treec = 0;
	if(gflg == 0) {
		if(error == 0) {
			setjmp(jmp);
			if (error)
				return;
			t = syntax(args, argp);
		}
		if(error != 0)
			err(ERR_SYNTAX, 255); else
			execute(t, 0, 0);
	}
}

static void
execute(struct Tree *t, int *pf1, int *pf2)
{
	int i, f, pv[2];
	register struct Tree *t1;
	register char *cp1, *cp2;

	if(t == 0)
		return;
	switch(t->DTYP) {
		int p;

	case TCOM:
		cp1 = t->DARR[0];
		cp2 = t->DARR[1];
		if(equal(cp1, "=")) {
			if(cp2 == 0) {
				err(ERR_EQUALS, 255);
				break;
			}
			i = *cp2 - 'a';
			if(i>25 || i<0) {
				err(ERR_EQUALS, 255);
				break;
			}
			rdval(i, t->DARR[2]);
			break;
		}
		if(equal(cp1, "chdir")) {
			if(t->DARR[1] != 0) {
				if(chdir(t->DARR[1]) < 0) {
					prs(cp1);
					err(ERR_BADDIR, 255);
				}
				break;
			}
			prs(cp1);
			err(ERR_COUNT, 255);
			break;
		}
		if(equal(cp1, "shift")) {
			if(dolc < 1) {
				prs("shift: no args\n");
				break;
			}
			dolv[1] = dolv[0];
			dolv++;
			dolc--;
			break;
		}
		if(equal(cp1, "login")) {
			if(promp != 0) {
				execv("/bin/login", t->DARR);
			}
			prs("login: cannot execute\n");
			break;
		}
		if(equal(cp1, "newgrp")) {
			if(promp != 0) {
				execv("/bin/newgrp", t->DARR);
			}
			prs("newgrp: cannot execute\n");
			break;
		}
		if(equal(cp1, "wait")) {
			pwait(-1);
			break;
		}
		if(equal(cp1, ":"))
			break;

	case TPAR:
		f = t->DFLG;
		i = 0;
		if((f&FPAR) == 0)
			i = fork();
		if(i == -1) {
			err(ERR_AGAIN, 255);
			break;
		}
		if(i != 0) {
			if((f&FPIN) != 0) {
				close(pf1[0]);
				close(pf1[1]);
			}
			if((f&FPRS) != 0) {
				prn(i);
				prs("\n");
			}
			if((f&FAND) != 0)
				break;
			if((f&FPOU) == 0)
				pwait(i);
			break;
		}
		if(t->DLEF != 0) {
			close(0);
			i = open(t->DLPT, 0);
			if(i < 0) {
				prs(t->DLPT);
				err(ERR_OPEN, 255);
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
				prs(t->DRPT);
				err(ERR_CREATE, 255);
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
			execute(t1, pf1, pf2);
			exit(255);
		}
		gflg = 0;
		scan(t, tglob);
		if(gflg) {
			t->DSPT = "/etc/glob";
			execv(t->DSPT, &t->DSPT);
			prs("glob: cannot execute\n");
			exit(255);
		}
		scan(t, trim);
		*linep = 0;
		texec(t);
		prs(t->DARR[0]);
		err(ERR_FOUND, 255);
		exit(255);

	case TFIL:
		f = t->DFLG;
		pipe(pv);
		t1 = t->DLEF;
		t1->DFLG |= FPOU | (f&(FPIN|FINT|FPRS));
		execute(t1, pf1, pv);
		t1 = t->DRIT;
		t1->DFLG |= FPIN | (f&(FPOU|FINT|FAND|FPRS));
		execute(t1, pv, pf2);
		break;

	case TLST:
		f = t->DFLG&FINT;
		if((t1 = t->DLEF))
			t1->DFLG |= f;
		execute(t1, pf1, pf2);
		if((t1 = t->DRIT))
			t1->DFLG |= f;
		execute(t1, pf1, pf2);
	}
}

/*
 * syntax
 *	empty
 *	syn1
 */

static struct Tree *
syntax(char **p1, char **p2)
{
	while(p1 != p2) {
		if(any(**p1, ";&\n"))
			p1++; else
			return(syn1(p1, p2));
	}
	return(0);
}

/*
 * syn1
 *	syn2
 *	syn2 & syntax
 *	syn2 ; syntax
 */

static struct Tree *
syn1(char **p1, char **p2)
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
			t = tree();
			t->DTYP = TLST;
			t->DLEF = syn2(p1, p);
			t->DFLG = 0;
			if(l == '&') {
				t1 = t->DLEF;
				t->DFLG |= FAND|FPRS|FINT;
			}
			if((t1 = syntax(p+1, p2)))
				t->DRIT = t1; else
				t->DRIT = 0;
			return(t);
		}
	}
	if(l == 0)
		return(syn2(p1, p2));
	error++;
	return(0);
}

/*
 * syn2
 *	syn3
 *	syn3 | syn2
 */

static struct Tree *
syn2(char **p1, char **p2)
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
			t = tree();
			t->DTYP = TFIL;
			t->DLEF = syn3(p1, p);
			t->DRIT = syn2(p+1, p2);
			t->DFLG = 0;
			return(t);
		}
	}
	return(syn3(p1, p2));
}

/*
 * syn3
 *	( syn1 ) [ < in  ] [ > out ]
 *	word word* [ < in ] [ > out ]
 */

static struct Tree *
syn3(char **p1, char **p2)
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
			if(any(**p, "<>("))
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
		t = tree();
		t->DTYP = TPAR;
		t->DSTR = syn1(lp, rp);
		goto out;
	}
	if(n == 0)
		error++;
	p1[n++] = 0;
	t = tree();
	t->DTYP = TCOM;
	for(l=0; l<n; l++)
		t->DARR[l] = p1[l];
out:
	t->DFLG = flg;
	t->DLPT = i;
	t->DRPT = o;
	return(t);
}

static struct Tree *
tree(void)
{
	if(treec == TRESIZ) {
		prs("Command line overflow\n");
		error++;
		longjmp(jmp, 1);
	}
	return(&trebuf[treec++]);
}

static void
pwait(int i)
{
	register int p, e;
	int s;

	for(;;) {
		p = wait(&s);
		if(p == -1)
			break;
		e = s&0177;
		if(e>=NSIG) {
			if(p != i) {
				prn(p);
				prs(": ");
			}
			prs("Signal ");
			prn(e);
			if(s&0200)
				prs(" -- Core dumped");
		}
		else
			prs(strsignal(e));
		if(e)
			err("", (s>>8)|e);
	}
}

static void
texec(struct Tree *at)
{
	register char *cp;
	register char *sp;
	register const char *path;
	char cmd[CMDSIZ];

	if(at->DARR[0] == NULL || at->DARR[0][0] == '\0')
		return;
	if(strchr(at->DARR[0], '/') != NULL) {
		execv(at->DARR[0], at->DARR);
		return;
	}
	path = getenv("PATH");
	if(path == NULL)
		path = "/bin:/usr/bin";
	for(;;) {
		cp = cmd;
		while(*path != '\0' && *path != ':') {
			if(cp == &cmd[CMDSIZ-2]) {
				errno = ENAMETOOLONG;
				return;
			}
			*cp++ = *path++;
		}
		if(cp == cmd)
			*cp++ = '.';
		*cp++ = '/';
		for(sp = at->DARR[0]; *sp; sp++) {
			if(cp == &cmd[CMDSIZ-1]) {
				errno = ENAMETOOLONG;
				return;
			}
			*cp++ = *sp;
		}
		*cp = '\0';
		execv(cmd, at->DARR);
		if(errno == ENOEXEC) {
			at->DPTR = cmd;
			at->DSPT = "/bin/osh";
			execv(at->DSPT, &at->DSPT);
			prs("No shell!\n");
			exit(255);
		}
		if(*path == '\0')
			return;
		path++;
	}
}
