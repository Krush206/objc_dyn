#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
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

extern void loadClass(const char *);
extern void setClass(struct Class *);
extern Class getClass(const char *);
extern void setRootClass(const char *);
#endif /* !OBJC_DYN */
