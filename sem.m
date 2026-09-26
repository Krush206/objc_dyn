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

@implementation Shell (Semantic)
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
		if((f&FINT) == 0 && setintr) {
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
@end
