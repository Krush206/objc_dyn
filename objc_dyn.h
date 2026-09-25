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

extern char *promp;
extern char *linep;
extern char *elinep;
extern char **argp;
extern char **eargp;
extern int peekc;
extern int gflg;
extern int error;
extern int dolc;
extern int idolp;
extern char pidp[NUMSIZ];
extern char *dolp;
extern char **dolv;
extern char seta[][EXPSIZ];
extern int treec;
extern char line[LINSIZ];
extern char *args[ARGSIZ];
extern struct Tree trebuf[TRESIZ];
extern jmp_buf jmp;

extern void loadClass(const char *);
extern void setClass(struct Class *);
extern Class getClass(const char *);
extern void setRootClass(const char *);
extern id getObject(const char *);
extern struct Object *getObjectList(void);
extern struct Object *getObjectRecord(const char *);
extern void freeArgument(struct Argument *);
extern struct Argument *getArgumentList(void);
extern struct Class *getClassRecord(const char *);

@interface Shell
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

@interface Shell (Miscellaneous)
- (int) readCharacter;
- (int) getCharacter: (int) flag;
- (void) error: (const char *) message code: (int) status;
- (void) printString: (const char *) string;
- (void) putCharacter: (int) character;
- (void) printNumber: (int) number;
- (int) anyCharacter: (int) character in: (const char *) string;
- (int) equalString: (const char *) first to: (const char *) second;
- (int) lastCharacter: (char *) string;
- (void) scan: (struct Tree *) tree selector: (SEL) sel;
- (int) glob: (int) character;
- (int) trim: (int) character;
- (char *) integerToASCII: (int) number;
@end
#endif /* !OBJC_DYN */
