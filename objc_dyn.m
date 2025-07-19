#import "objc_dyn.h"

static struct Class *clsdef;
static struct Root rootdef[100];

void loadClass(void)
{
  unsigned int i;
  Class *cls;
  struct Class *clsnew;
  struct Root *rootnew;
  static int loaded;

  if(loaded)
    return;
  cls = objc_copyClassList(&i);
  clsdef = malloc(sizeof *clsdef * i--);
  (clsnew = clsdef[0].prev = &clsdef[i])->next = clsdef;
  do
  {
    struct Class *oclsnew;

    oclsnew = clsnew--;
    oclsnew->prev = clsnew;
    clsnew->next = oclsnew;
  }
  while(clsnew != clsdef);
  do
  {
    clsnew->cls = *cls;
    clsnew->name = class_getName(*cls++);
  }
  while((clsnew = clsnew->next) != clsdef);
  do
  {
    clsnew->super = class_getSuperclass(clsnew->cls);
    clsnew->root = getRootClass(clsnew->cls);
  }
  while((clsnew = clsnew->next) != clsdef);
  (rootnew = rootdef[0].prev = &rootdef[99])->next = rootdef;
  do
  {
    struct Root *orootnew;

    orootnew = rootnew--;
    orootnew->prev = rootnew;
    rootnew->next = orootnew;
  }
  while(rootnew != rootdef);
  do
  {
    rootnew = rootdef;
    do
    {
      if(rootnew->cls == clsnew->root)
        break;
      if(rootnew->cls == Nil)
      {
        rootnew->cls = clsnew->root;
	rootnew->name = class_getName(clsnew->root);

	break;
      }
    }
    while((rootnew = rootnew->next) != rootdef);
  }
  while((clsnew = clsnew->next) != clsdef);
  do
    if(rootnew->cls == Nil)
      break;
  while((rootnew = rootnew->next) != rootdef);
  rootnew->prev->next = rootdef;
  rootdef[0].prev = rootnew->prev;
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

Class getClass(const char *name, const char *root)
{
  struct Class *oclsdef;

  oclsdef = clsdef;
  do
    if(strcmp(name, clsdef->name) == 0 &&
       strcmp(root, class_getName(clsdef->root)) == 0)
      return clsdef->cls;
  while((clsdef = clsdef->next) != oclsdef);

  return Nil;
}
