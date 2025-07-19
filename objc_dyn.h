#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <objc/objc.h>

void loadClass(void);
Class getClass(const char *, const char *);
Class getRootClass(Class);

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
