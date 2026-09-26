#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <signal.h>
#import <setjmp.h>
#import <errno.h>
#import <sys/wait.h>
#import <fcntl.h>

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

struct ArgumentList {
	const char *arg;
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

extern int treec;
extern int errval;
extern int idolp;
extern char *dolp;
extern char (*pidp)[];
extern char **dolv;
extern int dolc;
extern char *promp;
extern char *linep;
extern char *elinep;
extern char **argp;
extern char **eargp;
extern int peekc;
extern int gflg;
extern int error;
extern int uid;
extern int setintr;
extern char *arginp;
extern int onelflg;
extern int stoperr;
extern int execflg;
extern char (*seta)[][EXPSIZ];
extern char (*line)[];
extern char *(*args)[];
extern struct Tree (*trebuf)[];
extern jmp_buf jmp;
extern struct ObjectList *objdef;
extern struct ArgumentList *argdef;

@interface Shell: Object
+ (int) argc: (int) c argv: (char *[]) av;
- (void) main;
@end

@interface Shell (Semantic)
- (void) execute: (struct Tree *) t input: (int *) pf1 output: (int *) pf2;
@end

@interface Shell (Process)
- (void) wait: (int) i;
@end

@interface Shell (Execute)
- (id) execute: (id) obj message: (const char *) msg;
- (char *) buildArguments: (char **) line;
- (void) execute: (char *) f tree: (struct Tree *) at;
@end

@interface Shell (Lexer)
- (void) word;
- (void) expand: (int) i value: (char *) na;
- (int) readCharacter;
- (int) getCharacter: (int) flag;
@end

@interface Shell (Parser)
- (struct Tree *) syntax: (char **) p1 end: (char **) p2;
- (struct Tree *) syn1: (char **) p1 end: (char **) p2;
- (struct Tree *) syn2: (char **) p1 end: (char **) p2;
- (struct Tree *) syn3: (char **) p1 end: (char **) p2;
- (struct Tree *) tree;
@end

@interface Shell (Miscellaneous)
- (void) printString: (const char *) as;
- (void) putCharacter: (int) c;
- (void) printNumber: (int) n;
- (int) anyCharacter: (int) c in: (const char *) as;
- (int) equalString: (const char *) as1 to: (const char *) as2;
- (void) error: (const char *) s code: (int) exitno;
- (int) lastCharacter: (char *) cp;
- (void) scan: (struct Tree *) at selector: (SEL) sel;
- (int) glob: (int) c;
- (int) trim: (int) c;
- (char *) integerToASCII: (int) n;
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
@end
#endif /* !OBJC_DYN */
