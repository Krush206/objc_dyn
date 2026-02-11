#import "objc_dyn.h"

static struct Class clsdef;
static struct Root rootdef;
static char *clsroot;

static void loadRootClass(struct Class *clsnew)
{
  struct Root *rootnew;
  struct Root *roothead;

  if(clsnew != &clsdef)
    loadRootClass(clsnew->next);
  rootnew = rootdef.next;
  while(rootnew != &rootdef)
  {
    if(rootnew->cls == clsnew->root)
      return;
    rootnew = rootnew->next;
  }
  roothead = rootnew;
  rootnew = malloc(sizeof *rootnew);
  rootnew->next = &rootdef;
  rootnew->prev = roothead;
  roothead->next = rootnew;
  rootnew->cls = clsnew->root;
  rootnew->name = class_getName(clsnew->root);
}

void loadClass(void)
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
  loadRootClass(clsdef.next);
  setRootClass("NSObject");
  loaded = 1;
}

Class getRootClass(Class cls)
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

Class getClass(const char *name)
{
  struct Class *oclsdef;

  oclsdef = clsdef;
  do
    if(strcmp(name, clsdef->name) == 0 &&
       strcmp(clsroot, class_getName(clsdef->root)) == 0)
      return clsdef->cls;
  while((clsdef = clsdef->next) != oclsdef);

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
