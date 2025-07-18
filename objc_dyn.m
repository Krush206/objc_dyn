#import "objc_dyn.h"

static struct Class *clsdef;

void loadClass(void)
{
  unsigned int i;
  Class *cls;
  struct Class *clsnew;
  
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
    clsnew[i].cls = &cls[i];
    clsnew[i].name = class_getName(cls[i]);
  }
  while(i--);
}

Class getClass(const char *name)
{
  struct Class *oclsdef;

  oclsdef = clsdef;
  do
    if(strcmp(name, clsdef->name) == 0)
      return *clsdef->cls;
  while((clsdef = clsdef->next) != oclsdef);

  return Nil;
}
