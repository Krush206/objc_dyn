#import "objc_dyn.h"

static void allocRootClass(struct Root *);
static struct Root *forEachRootClass(struct Root *);
static struct Root *loadRootClass(struct Root *, struct Class *);
static Class getRootClass(Class);

static struct Class clsdef;
static struct Root rootdef;
static char *clsroot;

static void allocRootClass(struct Root *rootnew)
{
  struct Root *roothead;

  roothead = &rootdef;
  while((rootnew = rootnew->next) != &rootdef)
  {
    struct Root *alloc;

    alloc = malloc(sizeof *alloc);
    alloc->next = &rootdef;
    alloc->prev = roothead;
    alloc->cls = rootnew->cls;
    alloc->name = rootnew->name;
    rootdef.prev = alloc;
    roothead->next = alloc;
    roothead = alloc;
  }
}

static struct Root *forEachRootClass(struct Root *rootnew)
{
  struct Root *roothead;

  if(rootnew == &rootdef)
    return rootnew;
  for(roothead = rootnew->next; roothead != rootnew; roothead = roothead->next)
    if(roothead->cls == rootnew->cls)
    {
      rootnew->prev->next = rootnew->next;
      rootnew->next->prev = rootnew->prev;

      return forEachRootClass(rootnew->next);
    }

  return forEachRootClass(rootnew->next);
}

static struct Root *loadRootClass(struct Root *rootnew, struct Class *clsnew)
{
  struct Root roothead;

  if(clsnew == &clsdef)
  {
    allocRootClass(forEachRootClass(rootdef.next));

    return rootnew;
  }
  roothead.next = &rootdef;
  roothead.prev = rootnew;
  roothead.cls = clsnew->root;
  roothead.name = class_getName(clsnew->root);
  rootdef.prev = &roothead;
  rootnew->next = &roothead;

  return loadRootClass(&roothead, clsnew->next);
}

void loadClass(const char *rootname)
{
  unsigned int i;
  Class *cls;
  struct Class *clsnew;
  struct Class *clshead;
  struct Root *rootnew;
  static int loaded;

  if(loaded)
    return;
  cls = objc_copyClassList(&i);
  clsnew = &clsdef;
  clsnew->next = clsnew;
  clsnew->prev = clsnew;
  clshead = clsnew;
  while(i--)
  {
    clsnew = malloc(sizeof *clsnew);
    clsnew->cls = cls[i];
    clsnew->name = class_getName(clsnew->cls);
    clsnew->super = class_getSuperclass(clsnew->cls);
    clsnew->root = getRootClass(clsnew->cls);
    clsnew->next = &clsdef;
    clsnew->prev = clshead;
    clsdef.prev = clsnew;
    clshead->next = clsnew;
    clshead = clsnew;
  }
  free(cls);
  rootnew = &rootdef;
  rootnew->next = rootnew;
  rootnew->prev = rootnew;
  (void) loadRootClass(&rootdef, clsdef.next);
  setRootClass(rootname);
  loaded = 1;
}

static Class getRootClass(Class cls)
{
  Class clsnew;

  do
  {
    clsnew = cls;
    cls = class_getSuperclass(cls);
  }
  while(cls != Nil);

  return clsnew;
}

Class getClass(const char *clsname)
{
  struct Class *clsnew;

  for(clsnew = clsdef.next; clsnew != &clsdef; clsnew = clsnew->next)
    if(strcmp(clsname, clsnew->name) == 0 &&
       strcmp(clsroot, class_getName(clsnew->root)) == 0)
      return clsnew->cls;

  return Nil;
}

void setRootClass(const char *new)
{
  free(clsroot);
  clsroot = strcpy(malloc(strlen(new) + 1), new);
}

void inheritCopy(Class from, Class to)
{
  unsigned int i;
  Method *meth;

  meth = class_copyMethodList(from, &i);
  while(i--)
    (void) class_addMethod(to, method_getName(meth[i]),
			   method_getImplementation(meth[i]),
			   method_getTypeEncoding(meth[i]));
  free(meth);
  meth = class_copyMethodList(object_getClass(from), &i);
  while(i--)
    (void) class_addMethod(to, method_getName(meth[i]),
			   method_getImplementation(meth[i]),
			   method_getTypeEncoding(meth[i]));
  free(meth);
}

void setClass(struct Class *cls)
{
  objc_registerClassPair(cls->cls = objc_allocateClassPair(cls->super,
							   cls->name,
							   0));
}

void newRoot(struct Class *cls)
{
  struct Class *oclsdef, clsnew;

  oclsdef = clsdef;
  do
    if(clsdef->cls == cls->cls)
      break;
  while((clsdef = clsdef->next) != oclsdef);
  clsdef = oclsdef;
  clsnew.cls = cls->cls;
  setClass(cls);
  clsnew.super = cls->cls;
  clsnew.name = clsdef->name;
  clsnew.next = clsnew.prev = clsdef;
  setClass(&clsnew);
  inheritCopy(cls->root, clsnew.cls);
}
