#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <signal.h>
#import <setjmp.h>
#import <errno.h>
#import <fcntl.h>
#import <sys/wait.h>
#import <objc/objc-api.h>

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

#define DOLREPL 1
#define DOLREPQ 2

struct Class {
	Class cls;
	Class super;
	Class root;
	MetaClass meta;
	const char *name;
	struct Class *next;
	struct Class *prev;
};

struct Root {
	Class cls;
	Class meta;
	const char *name;
	struct Root *next;
	struct Root *prev;
};

struct Object {
	id obj;
	char *name;
	struct Object *next;
	struct Object *prev;
};

struct Argument {
	const char *arg;
	struct Argument *next;
	struct Argument *prev;
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

@interface Shell
{
@public
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
	struct Object objdef;
	struct Argument argdef;
	struct Class clsdef;
	struct Root rootdef;
	char *clsroot;
	struct Tree trebuf[TRESIZ];
	jmp_buf jmp;
}
+ (int) argc: (int) argc argv: (char *[]) argv;
- (void) main;
- (id) execute: (id) object message: (const char *) message;
- (void) word;
- (void) expand: (int) index value: (char *) value;
- (void) execute: (struct Tree *) tree front: (int *) input back: (int *) output;
- (struct Tree *) syntax: (char **) first end: (char **) last;
- (struct Tree *) syn1: (char **) first end: (char **) last;
- (struct Tree *) syn2: (char **) first end: (char **) last;
- (struct Tree *) syn3: (char **) first end: (char **) last;
- (struct Tree *) tree;
- (void) wait: (int) process;
- (void) execute: (char *) file tree: (struct Tree *) tree;
@end

@interface Shell (Runtime)
- (Class) getRootClass: (Class) cls;
- (void) loadClass: (const char *) rootname;
- (Class) getClass: (const char *) name;
- (void) setRootClass: (const char *) name;
- (id) getObject: (const char *) name;
- (struct Object *) getObjectList;
- (struct Object *) getObjectRecord: (const char *) name;
- (struct Class *) getClassRecord: (const char *) name;
- (void) freeArgument: (struct Argument *) argument;
- (struct Argument *) getArgumentList;
- (void) resolveLinks;
@end

@interface Shell (Miscellaneous)
- (int) readc;
- (int) getc: (int) flag;
- (void) err: (const char *) message exit: (int) status;
- (void) prs: (const char *) string;
- (void) putc: (int) character;
- (void) prn: (int) number;
- (int) any: (int) character in: (const char *) string;
- (int) equal: (const char *) first second: (const char *) second;
- (int) lastchr: (char *) string;
- (void) scan: (struct Tree *) tree function: (int (*)(int)) function;
- (int) tglob: (int) character;
- (int) trim: (int) character;
- (char *) itoa: (int) number;
@end
#endif /* !OBJC_DYN */
