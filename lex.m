#import "objc_dyn.h"

static char subchar = '$';

@implementation Shell (Lexer)
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

	st = (*seta)[i];
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

/*	flag: !DOLREPL ==> no substitution, DOLREPL ==> substitute,
	DOLREPQ ==> quoted substitution: "$1" = value of $1 for sure */
- (int) getCharacter: (int) flag
{
	register char c;

	if(peekc) {
		c = peekc;
		peekc = 0;
		return(c);
	}
	if(argp > eargp) {
		argp -= 10;
		while((c=[self getCharacter: !DOLREPL]) != '\n');
		argp += 10;
		[self error: ERR_ARGS code: 255];
		gflg++;
		return(c);
	}
	if(linep > elinep) {
		linep -= 10;
		while((c=[self getCharacter: !DOLREPL]) != '\n');
		linep += 10;
		[self error: ERR_CHAR code: 255];
		gflg++;
		return(c);
	}
getd:
	if(dolp) {
		if (c = *dolp++) {
			if (flag == DOLREPQ)
				c |= QUOTE;
			return c;
		}
		if (idolp && ++idolp < dolc) {
			dolp = dolv[idolp];
			return(' ');
		}
		dolp = 0;
	}
	c = [self readCharacter];
	if(c == subchar && flag) {
		c = [self readCharacter];
		if(c>='0' && c<='9') {
			if(c-'0' < dolc)
				dolp = dolv[c-'0'];
			goto getd;
		}
		else if(c>='a' && c<='z') {
			dolp = (*seta)[c-'a'];
			goto getd;
		}
		else if(c == '$') {
			dolp = *pidp;
			goto getd;
		}
		/* $* = $1 $2 .... */
		else if (c == '*') {
			if (dolc > 1) {
				idolp = 1;
				dolp = dolv[1];
			}
			goto getd;
		}
		else
			if(c != '\n')  c = [self readCharacter];
	}
	return(c&0177);
}

- (int) readCharacter
{
	int rdstat;
	char cc;
	register int c;

	if (arginp) {
		if (*arginp == 1)
			exit(errval);
		if ((c = *arginp++) == 0) {
			*arginp = 1;
			c = '\n';
		}
		return(c);
	}
	if (onelflg==1)
		exit(255);
	if((rdstat = read(0, &cc, 1)) != 1) {
		if(rdstat==0) exit(errval); /* end of file*/
		else exit(255); /* error */
	}
	if (cc=='\n' && onelflg)
		onelflg--;
	return(cc);
}
@end
