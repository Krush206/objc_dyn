#import "objc_dyn.h"

static struct {
	struct ClassList clsdef;
	struct RootList rootdef;
	struct ObjectList objdef;
	char *clsroot;
} lbuf;

@implementation Shell (Runtime)
- (void) allocRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	roothead = &lbuf.rootdef;
	roothead->next = roothead;
	roothead->prev = roothead;
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

	if(clsnew == &self->clsdef)
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
	static int loaded;

	if(loaded)
		return;
	/* Don't walk all classes via objc_next_class() — that calls
	 * class_get_super_class() on GNUstep Base metadata which is
	 * ABI-incompatible with classic libobjc and segfaults.
	 * Instead, initialize the data structures and let getClass:
	 * resolve names via objc_lookup_class() on demand. */
	self->clsdef.next = &self->clsdef;
	self->clsdef.prev = &self->clsdef;
	self->argdef.next = &self->argdef;
	self->argdef.prev = &self->argdef;
	lbuf.objdef.next = &lbuf.objdef;
	lbuf.objdef.prev = &lbuf.objdef;
	lbuf.rootdef.next = &lbuf.rootdef;
	lbuf.rootdef.prev = &lbuf.rootdef;
	self->subchar = '$';
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

	/* Check the registry first (for explicitly defined classes) */
	for(clsnew = self->clsdef.next; clsnew != &self->clsdef; clsnew = clsnew->next)
		if([self equalString: clsname to: clsnew->name] &&
		   [self equalString: self->clsroot to: class_get_class_name(clsnew->root)])
			return clsnew->cls;

	/* Fall back to direct runtime lookup via objc_lookup_class()
	 * — avoids walking objc_next_class() which segfaults with
	 * GNUstep Base metadata under classic libobjc. */
	return objc_lookup_class(clsname);
}

- (id) getObject: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = lbuf.objdef.next; objnew != &lbuf.objdef; objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew->obj;
	return nil;
}

- (struct ObjectList *) getObjectRecord: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = lbuf.objdef.next; objnew != &lbuf.objdef; objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew;
	return NULL;
}

- (struct ClassList *) getClassRecord: (const char *) clsname
{
	struct ClassList *clsnew;

	for(clsnew = self->clsdef.next; clsnew != &self->clsdef; clsnew = clsnew->next)
		if([self equalString: clsname to: clsnew->name])
			return clsnew;
	return NULL;
}

- (void) setRootClass: (const char *) new
{
	free(self->clsroot);
	self->clsroot = strcpy(malloc(strlen(new) + 1), new);
}

- (struct ObjectList *) getObjectList
{
	return &lbuf.objdef;
}

- (struct ArgumentList *) getArgumentList
{
	return &self->argdef;
}

- (void) freeArgument: (struct ArgumentList *) argnew
{
	if(argnew == &self->argdef)
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

/* Variable assignment and lookup */
- (id) setVariable: (const char *) name value: (id) val
{
	struct ObjectList *obj;

	if((obj = [self getObjectRecord: name]) != NULL)
	{
		obj->obj = val;
		return val;
	}
	obj = malloc(sizeof *obj);
	obj->next = &lbuf.objdef;
	obj->prev = lbuf.objdef.prev;
	obj->name = strcpy(malloc(strlen(name) + 1), name);
	obj->obj = val;
	lbuf.objdef.prev->next = obj;
	lbuf.objdef.prev = obj;
	return val;
}

- (id) getVariable: (const char *) name
{
	struct ObjectList *objnew;

	for(objnew = lbuf.objdef.next; objnew != &lbuf.objdef; objnew = objnew->next)
		if([self equalString: name to: objnew->name])
			return objnew->obj;
	return nil;
}

/* Symbol support */
- (id) internSymbol: (const char *) name
{
	static struct Symbol *symbols = NULL;
	struct Symbol *sym;

	for(sym = symbols; sym != NULL; sym = sym->next)
		if([self equalString: name to: sym->name])
			return (id) sym;
	sym = malloc(sizeof *sym);
	sym->name = strcpy(malloc(strlen(name) + 1), name);
	sym->next = symbols;
	symbols = sym;
	return (id) sym;
}
@end
