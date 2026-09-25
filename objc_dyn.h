#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <signal.h>
#import <setjmp.h>
#import <errno.h>
#import <objc/objc-api.h>

#define getc Getc
#define putc Putc

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
extern char pidp[];
extern char *dolp;
extern char **dolv;
extern char seta[][EXPSIZ];

extern void loadClass(const char *);
extern void setClass(struct Class *);
extern Class getClass(const char *);
extern void setRootClass(const char *);
extern id getObject(const char *);
extern struct Object *getObjectList(void);
extern struct Object *getObjectRecord(const char *);
extern int getc(int);
extern int readc(void);
extern void prs(const char *);
extern void putc(int);
extern void prn(int);
extern int any(int, const char *);
extern int equal(const char *, const char *);
extern void err(const char *, int);
extern int lastchr(char *);
extern void freeArgument(struct Argument *);
extern struct Argument *getArgumentList(void);
extern struct Class *getClassRecord(const char *);
extern int trim(int);
extern int tglob(int);
extern void scan(struct Tree *, int (*)(int));
extern int length(char *);
extern char *itoa(int);
#endif /* !OBJC_DYN */
