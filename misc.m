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
	c = readc();
	if(c == '\\') {
		c = readc();
		if(c == '\n')
			return(' ');
		return(c|QUOTE);
	}
	return(c&0177);
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

void prs(char *as)
{
	register char *s;

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

int any(int c, char *as)
{
	register char *s;

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

void err(char *s, int exitno)
{

	prs(s);
	prs("\n");
	if(promp == 0) {
		lseek(0, 0L, 2);
		exit(exitno);
	}
}

int trim(int c)
{

	return(c&0177);
}
