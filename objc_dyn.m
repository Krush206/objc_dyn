#import "objc_dyn.h"

static struct {
	struct ArgumentList argdef;
	struct ObjectList objdef;
	struct ClassList clsdef;
	struct RootList rootdef;
	char *clsroot;
} lbuf;

@implementation Shell (Runtime)
- (void) allocRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	roothead = &lbuf.rootdef;
	lbuf.rootdef.next = roothead;
	lbuf.rootdef.prev = roothead;
	while(rootnew != &lbuf.rootdef)
	{
		struct RootList *alloc;

		alloc = malloc(sizeof *alloc);
		alloc->next = &lbuf.rootdef;
		alloc->prev = roothead;
		alloc->cls = rootnew->cls;
		alloc->meta = rootnew->meta;
		alloc->name = rootnew->name;
		lbuf.rootdef.prev = alloc;
		roothead->next = alloc;
		roothead = alloc;
		rootnew = rootnew->next;
	}
}

- (void) forEachRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	if(rootnew == &lbuf.rootdef)
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

	if(clsnew == &lbuf.clsdef)
	{
		[self forEachRootClass: lbuf.rootdef.next];
		[self allocRootClass: lbuf.rootdef.next];
		return;
	}
	roothead.next = &lbuf.rootdef;
	roothead.prev = rootnew;
	roothead.cls = clsnew->root;
	roothead.meta = class_get_meta_class(clsnew->root);
	roothead.name = class_get_class_name(clsnew->root);
	lbuf.rootdef.prev = &roothead;
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
	clsnew = &lbuf.clsdef;
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
		clsnew->next = &lbuf.clsdef;
		clsnew->prev = clshead;
		lbuf.clsdef.prev = clsnew;
		clshead->next = clsnew;
		clshead = clsnew;
	}
	lbuf.argdef.next = &lbuf.argdef;
	lbuf.argdef.prev = &lbuf.argdef;
	lbuf.objdef.next = &lbuf.objdef;
	lbuf.objdef.prev = &lbuf.objdef;
	lbuf.rootdef.next = &lbuf.rootdef;
	lbuf.rootdef.prev = &lbuf.rootdef;
	[self loadRootClass: &lbuf.rootdef class: lbuf.clsdef.next];
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

	for(clsnew = lbuf.clsdef.next;
	    clsnew != &lbuf.clsdef;
	    clsnew = clsnew->next)
		if([self equalString: clsname
			 to: clsnew->name] &&
		   [self equalString: lbuf.clsroot
			 to: class_get_class_name(clsnew->root)])
			return clsnew->cls;
	return Nil;
}

- (id) getObject: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = lbuf.objdef.next;
	    objnew != &lbuf.objdef;
	    objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew->obj;
	return nil;
}

- (struct ObjectList *) getObjectRecord: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = lbuf.objdef.next;
	    objnew != &lbuf.objdef;
	    objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew;
	return NULL;
}

- (struct ClassList *) getClassRecord: (const char *) clsname
{
	struct ClassList *clsnew;

	for(clsnew = lbuf.clsdef.next;
	    clsnew != &lbuf.clsdef;
	    clsnew = clsnew->next)
		if([self equalString: clsname to: clsnew->name])
			return clsnew;
	return NULL;
}

- (void) setRootClass: (const char *) new
{
	free(lbuf.clsroot);
	lbuf.clsroot = strcpy(malloc(strlen(new) + 1), new);
}

- (struct ObjectList *) getObjectList
{
	return &lbuf.objdef;
}

- (struct ArgumentList *) getArgumentList
{
	return &lbuf.argdef;
}

- (void) freeArgument: (struct ArgumentList *) argnew
{
	if(argnew == &lbuf.argdef)
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
