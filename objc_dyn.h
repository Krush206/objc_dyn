#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <objc/objc.h>

void loadClass(const char *);
struct Class *getClass(const char *);
void inheritCopy(Class, Class);
void setRootClass(const char *);

struct Class {
  Class cls, super, root;
  const char *name;
  struct Class *next,
	       *prev;
};

struct Root {
  Class cls;
  const char *name;
  struct Root *next,
	      *prev;
};
#endif /* !OBJC_DYN */
