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

@implementation Shell (Execute)
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
