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

struct Object {
  id obj;
  const char *name;
  struct Object *next;
  struct Object *prev;
};

extern void loadClass(const char *);
extern void setClass(struct Class *);
extern Class getClass(const char *);
extern void setRootClass(const char *);
extern id getObject(const char *);
extern struct Object *getObjectList(void);
#endif /* !OBJC_DYN */
