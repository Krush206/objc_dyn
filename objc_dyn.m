#import "objc_dyn.h"

static void allocRootClass(struct Root *);
static void forEachRootClass(struct Root *);
static void loadRootClass(struct Root *, struct Class *);
static Class getRootClass(Class);

static struct Object objdef;
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
    alloc->meta = rootnew->meta;
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
  roothead.meta = object_getClass(clsnew->root);
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
    clsnew->meta = object_getClass(clsnew->cls);
    clsnew->root = getRootClass(clsnew->cls);
    clsnew->next = &clsdef;
    clsnew->prev = clshead;
    clsdef.prev = clsnew;
    clshead->next = clsnew;
    clshead = clsnew;
  }
  free(cls);
  objdef.next = &objdef;
  objdef.prev = &objdef;
  rootdef.next = &rootdef;
  rootdef.prev = &rootdef;
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

Class getClass(const char *clsname)
{
  struct Class *clsnew;

  for(clsnew = clsdef.next; clsnew != &clsdef; clsnew = clsnew->next)
    if(equal(clsname, clsnew->name) &&
       equal(clsroot, class_getName(clsnew->root)))
      return clsnew->cls;

  return Nil;
}

id getObject(const char *objname)
{
  struct Object *objnew;

  for(objnew = objdef.next; objnew != &objdef; objnew = objnew->next)
    if(equal(objname, objnew->name))
      return objnew->obj;

  return nil;
}

void setRootClass(const char *new)
{
  free(clsroot);
  clsroot = strcpy(malloc(strlen(new) + 1), new);
}

void setClass(struct Class *clsnew)
{
  clsnew->cls = objc_allocateClassPair(clsnew->super, clsnew->name, 0);
  if(clsnew->cls == Nil)
    return;
  objc_registerClassPair(clsnew->cls);
  clsnew->meta = object_getClass(clsnew->cls);
  clsnew->root = getRootClass(clsnew->cls);
  clsnew->next = &clsdef;
  clsnew->prev = clsdef.prev;
  clsdef.prev->next = clsnew;
  clsdef.prev = clsnew;
}

struct Object *getObjectList(void)
{
  return &objdef;
}
