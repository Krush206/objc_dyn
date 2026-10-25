#ifndef OBJC_DYN
#define OBJC_DYN 1

#import <stdlib.h>
#import <string.h>
#import <stdio.h>
#import <unistd.h>
#import <signal.h>
#import <setjmp.h>
#import <errno.h>
#import "/usr/local/include/objc/Object.h"
#import "/usr/local/include/objc/objc-api.h"

#define QUOTE 0200
#define FAND 1
#define FCAT 2
#define FPIN 4
#define FPOU 8
#define FPAR 16
#define FINT 32
#define FPRS 64
#define TCOM 1
#define TPAR 2
#define TFIL 3
#define TLST 4
#define DTYP t_dtyp
#define DLEF t_dlef.t_dltr
#define DRIT t_drit.t_drtr
#define DFLG t_dflg
#define DARR t_dcom.t_darr
#define DPTR t_dcom.t_dptr
#define DSPT t_dspr.t_dptr
#define DSTR t_dspr.t_dtre
#define DLPT t_dlef.t_dlpt
#define DRPT t_drit.t_drpt

#define LINSIZ 1000
#define ARGSIZ 50
#define EXPSIZ 1000
#define TRESIZ 100
#define NUMSIZ 12
#define CMDSIZ 100

#define ERR_SYNTAX "syntax error"
#define ERR_EQUALS "'=' error"
#define ERR_BADDIR ": bad directory"
#define ERR_COUNT ": arg count"
#define ERR_AGAIN "try again"
#define ERR_OPEN ": cannot open"
#define ERR_CREATE ": cannot create"
#define ERR_FOUND ": not found"
#define ERR_LARGE ": too large"
#define ERR_CHAR "Too many characters"
#define ERR_ARGS "Too many args"
#define ERR_BADMSG ": bad message"

#define DOLREPL 1
#define DOLREPQ 2

/* Smalltalk syntax tokens */
#define TOK_ASSIGN  0x8000  /* := */
#define TOK_SYMBOL  0x8001  /* #symbol */
#define TOK_STRING  0x8002  /* "string" */
#define TOK_WORD    0x8003  /* ordinary word */

struct ClassList {
	Class cls;
	Class super;
	Class root;
	MetaClass meta;
	const char *name;
	struct ClassList *next;
	struct ClassList *prev;
};

struct RootList {
	Class cls;
	Class meta;
	const char *name;
	struct RootList *next;
	struct RootList *prev;
};

struct ObjectList {
	id obj;
	char *name;
	struct ObjectList *next;
	struct ObjectList *prev;
};

struct Symbol {
	char *name;
	struct Symbol *next;
};

struct ArgumentList {
	id arg;
	struct ArgumentList *next;
	struct ArgumentList *prev;
};

struct Tree {
	int t_dtyp;
	int t_dflg;
	union {
		struct Tree *t_dltr;
		char *t_dlpt;
	} t_dlef;
	union {
		struct Tree *t_drtr;
		char *t_drpt;
	} t_drit;
	union {
		char *t_dptr;
		struct Tree *t_dtre;
	} t_dspr;
	union {
		char *t_dptr;
		char *t_darr[ARGSIZ];
	} t_dcom;
};

/* Shell instance variables - all shell state moved from globals to ivars */
@interface Shell: Object
{
@private
	char *promp;
	char *linep;
	char *elinep;
	char **argp;
	char **eargp;
	int peekc;
	int gflg;
	int error;
	char line[LINSIZ];
	char *args[ARGSIZ];
	char pidp[NUMSIZ];
	char seta[26][EXPSIZ];
	char *dolp;
	int dolc;
	char **dolv;
	int idolp;
	int treec;
	jmp_buf jmp;
	struct ObjectList objdef;
	struct ArgumentList argdef;
	struct ClassList clsdef;
	struct RootList rootdef;
	char *clsroot;
	char subchar;
	char ungetc_buf;
	int output_done;
}

+ (int) argc: (int) c argv: (char *[]) av;
@end

@interface Shell (Miscellaneous)
- (int) readCharacter;
- (void) printString: (const char *) as;
- (void) putCharacter: (int) c;
- (void) printNumber: (int) n;
- (int) anyCharacter: (int) c in: (const char *) as;
- (int) equalString: (const char *) as1 to: (const char *) as2;
- (void) error: (const char *) s code: (int) exitno;
- (int) lastCharacter: (char *) cp;
- (int) getCharacter: (int) flag;
- (void) ungetCharacter: (int) c;
- (char *) integerToASCII: (int) n;
- (id) describeObject: (id) obj;
@end

@interface Shell (Runtime)
- (void) allocRootClass: (struct RootList *) rootnew;
- (void) forEachRootClass: (struct RootList *) rootnew;
- (void) loadRootClass: (struct RootList *) rootnew
	 class: (struct ClassList *) clsnew;
- (void) loadClass: (const char *) rootname;
- (Class) getRootClass: (Class) cls;
- (Class) getClass: (const char *) clsname;
- (id) getObject: (const char *) objname;
- (struct ObjectList *) getObjectRecord: (const char *) objname;
- (struct ClassList *) getClassRecord: (const char *) clsname;
- (void) setRootClass: (const char *) new;
- (struct ObjectList *) getObjectList;
- (struct ArgumentList *) getArgumentList;
- (void) freeArgument: (struct ArgumentList *) argnew;
- (void) resolveLinks;
/* Variable assignment and lookup */
- (id) setVariable: (const char *) name value: (id) val;
- (id) getVariable: (const char *) name;
/* Symbol support */
- (id) internSymbol: (const char *) name;
@end

@interface Shell (Lexer)
- (void) word;
- (int) getToken;
- (int) peekToken;
- (void) ungetToken: (int) tok;
- (int) scan: (const char *) name;
@end

@interface Shell (Parser)
- (void) main;
- (id) assignVariable: (const char *) name withValue: (id) newValue;
- (id) execute: (char **) words count: (char **) end;
- (id) perform: (id) obj message: (const char *) msg;
- (id) string: (char **) words count: (char **) end;
- (void) collectArguments: (char **) words count: (char **) end;
- (int) selectorLength: (char **) words count: (char **) end;
- (char *) buildSelector: (char **) words count: (char **) end length: (int) len;
- (id) resolve: (const char *) name;
@end
#endif /* !OBJC_DYN */
