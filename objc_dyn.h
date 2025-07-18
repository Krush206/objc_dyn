#ifndef OBJC_DYN
#define OBJC_DYN 1
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <objc/objc.h>

void loadClass(void);
Class getClass(const char *);

struct Class {
  Class *cls;
  const char *name;
  struct Class *next,
	       *prev;
};
#endif
