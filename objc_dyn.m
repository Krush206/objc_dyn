#import "objc_dyn.h"

static void allocRootClass(struct Root *);
static void forEachRootClass(struct Root *);
static void loadRootClass(struct Root *, struct Class *);
static Class getRootClass(Class);

static struct Class clsdef;
static struct Root rootdef;
static char *clsroot;

static void allocRootClass(struct Root *rootnew)
{
  struct Root *roothead;

  roothead = rootnew;
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

static void forEachRootClass(struct Root *rootnew)
{
  struct Root *roothead;

  if(rootnew == &rootdef)
    return;
  for(roothead = rootnew->next; roothead != rootnew; roothead = roothead->next)
    if(roothead->cls == rootnew->cls)
    {
      rootnew->prev->next = rootnew->next;
      rootnew->next->prev = rootnew->prev;

      break;
    }

  forEachRootClass(rootnew->next);
}

static void loadRootClass(struct Root *rootnew, struct Class *clsnew)
{
  struct Root roothead;

  if(clsnew == &clsdef)
  {
    forEachRootClass(rootdef.next);
    allocRootClass(&rootdef);

    return;
  }
  roothead.next = &rootdef;
  roothead.prev = rootnew;
  roothead.cls = clsnew->root;
  roothead.name = class_getName(clsnew->root);
  rootdef.prev = &roothead;
  rootnew->next = &roothead;

  loadRootClass(&roothead, clsnew->next);
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
  loadRootClass(&rootdef, clsdef.next);
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

struct Class *getClass(const char *clsname)
{
  struct Class *clsnew;

  for(clsnew = clsdef.next; clsnew != &clsdef; clsnew = clsnew->next)
    if(strcmp(clsname, clsnew->name) == 0 &&
       strcmp(clsroot, class_getName(clsnew->root)) == 0)
      return clsnew;

  return NULL;
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

void setClass(struct Class *clsnew)
{
  objc_registerClassPair(clsnew->cls = objc_allocateClassPair(clsnew->super,
                                                              clsnew->name,
                                                              0));
}

static void forEachClass(struct Class *clsnew)
{
  struct Root *clshead;

  if(clsnew == &clsdef)
    return;
  for(clshead = clsnew->next; clshead != clsnew; clshead = clshead->next)
    if(clshead->super == clsnew->super)
    {
      clsnew->prev->next = clsnew->next;
      clsnew->next->prev = clsnew->prev;

      break;
    }

  forEachClass(clsnew->next);
}

void newRoot(struct Class *newroot, struct Class *oldroot, const char *name)
{
  struct Class *clshead;
  struct Class alloc;

  newroot->super = Nil;
  newroot->name = name;
  setClass(newroot);

  clshead = &clsdef;
  while((clshead = clshead->next) != &clsdef)
    if(clshead->cls == oldroot->cls)
      break;
  alloc.super = newroot->cls;
  alloc.name = olroot->name;
  setClass(&alloc);
}
