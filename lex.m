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

static int last_tok = 0;
static int have_tok = 0;

@implementation Shell (Lexer)

- (int) getToken
{
	if(have_tok) {
		have_tok = 0;
		return last_tok;
	}
	[self word];
	return TOK_WORD;
}

- (int) peekToken
{
	[self word];
	last_tok = TOK_WORD;
	have_tok = 1;
	return last_tok;
}

- (void) ungetToken: (int) tok
{
	last_tok = tok;
	have_tok = 1;
}

- (int) wordToken
{
	[self word];
	return TOK_WORD;
}

- (void) word
{
	register int c, c1;

	*self->argp++ = self->linep;

loop:
	switch(c = [self getCharacter: DOLREPL]) {

	case ' ':
	case '\t':
		goto loop;

	case '\'':
	case '"':
		c1 = c;
		while((c = [self getCharacter: !DOLREPL]) != c1) {
			if(c == '\n') {
				self->error++;
				self->peekc = c;
				return;
			}
			*self->linep++ = c | QUOTE;
		}
		goto pack;

	case '#':
		/* Smalltalk symbol literal */
		*self->linep++ = c;
		c = [self getCharacter: DOLREPL];
		while(c != ' ' && c != '\t' && c != '\n' && c != ':' &&
		      c != ';' && c != '&' && c != '|' && c != '<' &&
		      c != '>' && c != '(' && c != ')' && c != '^') {
			*self->linep++ = c;
			c = [self getCharacter: DOLREPL];
		}
		[self ungetCharacter: c];
		*self->linep++ = '\0';
		return;

	case ':':
		/* Could be := or selector : */
		c1 = [self getCharacter: DOLREPL];
		if(c1 == '=') {
			*self->linep++ = ':';
			*self->linep++ = '=';
			*self->linep++ = '\0';
			return;
		}
		[self ungetCharacter: c1];
		*self->linep++ = c;
		*self->linep++ = '\0';
		return;

	case '&':
	case ';':
	case '<':
	case '>':
	case '(':
	case ')':
	case '|':
	case '^':
	case '\n':
		*self->linep++ = c;
		*self->linep++ = '\0';
		return;
	}

	self->peekc = c;

pack:
	for(;;) {
		c = [self getCharacter: DOLREPL];
		if([self anyCharacter: c in: " '\"\t;&<>()|^\n:"]) {
			self->peekc = c;
			if([self anyCharacter: c in: "\"'"])
				goto loop;
			if(c == ':')
				*self->linep++ = [self getCharacter: !DOLREPL];
			*self->linep++ = '\0';
			return;
		}
		*self->linep++ = c;
	}
}

/* Smalltalk symbol literal #symbol */
- (int) scan: (const char *) name
{
	return((*name & QUOTE) != 0);
}

@end
