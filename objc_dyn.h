#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <objc/objc.h>

struct Class {
  Class cls;
  Class super;
  Class root;
  Class meta;
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

extern char *promp;
extern char *linep;
extern char *elinep;
extern char **argp;
extern char **eargp;
extern char peekc;
extern int gflg;
extern int error;

extern void loadClass(const char *);
extern void setClass(struct Class *);
extern Class getClass(const char *);
extern void setRootClass(const char *);
extern id getObject(const char *);
extern struct Object *getObjectList(void);
extern struct Object *getObjectRecord(const char *);
extern int getc(void);
extern int readc(void);
extern void prs(const char *);
extern void putc(int);
extern void prn(int);
extern int any(int, const char *);
extern int equal(const char *, const char *);
extern void err(const char *, int);
extern char lastchr(char *);
extern void freeArgument(struct Argument *);
extern struct Argument *getArgumentList(void);
extern struct Class *getClassRecord(const char *);
#endif /* !OBJC_DYN */
