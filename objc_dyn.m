#import "objc_dyn.h"

static struct ArgumentList argdef;
static struct ObjectList objdef;
static struct ClassList clsdef;
static struct RootList rootdef;

static char *clsroot;

@implementation Shell (Runtime)
- (void) allocRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	roothead = &rootdef;
	rootdef.next = roothead;
	rootdef.prev = roothead;
	while(rootnew != &rootdef)
	{
		struct RootList *alloc;

		alloc = malloc(sizeof *alloc);
		alloc->next = &rootdef;
		alloc->prev = roothead;
		alloc->cls = rootnew->cls;
		alloc->meta = rootnew->meta;
		alloc->name = rootnew->name;
		rootdef.prev = alloc;
		roothead->next = alloc;
		roothead = alloc;
		rootnew = rootnew->next;
	}
}

- (void) forEachRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	if(rootnew == &rootdef)
		return;
	for(roothead = rootnew->next;
	    roothead != rootnew;
	    roothead = roothead->next)
		if(roothead->cls == rootnew->cls)
		{
			rootnew->prev->next = rootnew->next;
			rootnew->next->prev = rootnew->prev;
			break;
		}
	[self forEachRootClass: rootnew->next];
}

- (void) loadRootClass: (struct RootList *) rootnew
	 class: (struct ClassList *) clsnew
{
	struct RootList roothead;

	if(clsnew == &clsdef)
	{
		[self forEachRootClass: rootdef.next];
		[self allocRootClass: rootdef.next];
		return;
	}
	roothead.next = &rootdef;
	roothead.prev = rootnew;
	roothead.cls = clsnew->root;
	roothead.meta = class_get_meta_class(clsnew->root);
	roothead.name = class_get_class_name(clsnew->root);
	rootdef.prev = &roothead;
	rootnew->next = &roothead;
	[self loadRootClass: &roothead class: clsnew->next];
}

- (void) loadClass: (const char *) rootname
{
	Class cls;
	struct ClassList *clsnew;
	struct ClassList *clshead;
	void *init;
	static int loaded;

	if(loaded)
		return;
	clsnew = &clsdef;
	clsnew->next = clsnew;
	clsnew->prev = clsnew;
	clshead = clsnew;
	init = NULL;
	[self resolveLinks];
	while((cls = objc_next_class(&init)) != Nil)
	{
		clsnew = malloc(sizeof *clsnew);
		clsnew->cls = cls;
		clsnew->name = class_get_class_name(clsnew->cls);
		clsnew->super = class_get_super_class(clsnew->cls);
		clsnew->meta = class_get_meta_class(clsnew->cls);
		clsnew->root = [self getRootClass: clsnew->cls];
		clsnew->next = &clsdef;
		clsnew->prev = clshead;
		clsdef.prev = clsnew;
		clshead->next = clsnew;
		clshead = clsnew;
	}
	argdef.next = &argdef;
	argdef.prev = &argdef;
	objdef.next = &objdef;
	objdef.prev = &objdef;
	rootdef.next = &rootdef;
	rootdef.prev = &rootdef;
	[self loadRootClass: &rootdef class: clsdef.next];
	[self setRootClass: rootname];
	loaded = 1;
}

- (Class) getRootClass: (Class) cls
{
	Class clsnew;

	do
	{
		clsnew = cls;
		cls = class_get_super_class(cls);
	}
	while(cls != Nil);
	return clsnew;
}

- (Class) getClass: (const char *) clsname
{
	struct ClassList *clsnew;

	for(clsnew = clsdef.next; clsnew != &clsdef; clsnew = clsnew->next)
		if([self equalString: clsname to: clsnew->name] &&
		   [self equalString: clsroot to: class_get_class_name(clsnew->root)])
			return clsnew->cls;
	return Nil;
}

- (id) getObject: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = objdef.next; objnew != &objdef; objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew->obj;
	return nil;
}

- (struct ObjectList *) getObjectRecord: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = objdef.next; objnew != &objdef; objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew;
	return NULL;
}

- (struct ClassList *) getClassRecord: (const char *) clsname
{
	struct ClassList *clsnew;

	for(clsnew = clsdef.next; clsnew != &clsdef; clsnew = clsnew->next)
		if([self equalString: clsname to: clsnew->name])
			return clsnew;
	return NULL;
}

- (void) setRootClass: (const char *) new
{
	free(clsroot);
	clsroot = strcpy(malloc(strlen(new) + 1), new);
}

- (struct ObjectList *) getObjectList
{
	return &objdef;
}

- (struct ArgumentList *) getArgumentList
{
	return &argdef;
}

- (void) freeArgument: (struct ArgumentList *) argnew
{
	if(argnew == &argdef)
	{
		argnew->next = argnew;
		argnew->prev = argnew;
		return;
	}
	[self freeArgument: argnew->next];
	free(argnew);
}

- (void) resolveLinks
{
	extern void __objc_resolve_class_links(void);

	__objc_resolve_class_links();
}
@end
