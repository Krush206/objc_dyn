#import "objc_dyn.h"

#include <dlfcn.h>

extern void (*_objc_load_callback)(Class, Category *);

/* Classes loaded dynamically via libdl are registered here so resolve: can
 * find them.  The _objc_load_callback fires during dlopen() for every class
 * registered by __objc_exec_class in the loaded image. */
static void *loaded_images[64];
static int loaded_image_count = 0;
static Class loaded_classes[64];
static int loaded_class_count = 0;

static void dyn_load_callback(Class cls, Category *cat)
{
	if (loaded_class_count < 64)
		loaded_classes[loaded_class_count++] = cls;
}

@implementation Shell (Runtime)
- (void) allocRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	roothead = &self->rootdef;
	roothead->next = roothead;
	roothead->prev = roothead;
	while(rootnew != &self->rootdef)
	{
		struct RootList *alloc;

		alloc = malloc(sizeof *alloc);
		alloc->next = &self->rootdef;
		alloc->prev = roothead;
		alloc->cls = rootnew->cls;
		alloc->meta = rootnew->meta;
		alloc->name = rootnew->name;
		self->rootdef.prev = alloc;
		roothead->next = alloc;
		roothead = alloc;
		rootnew = rootnew->next;
	}
}

- (void) forEachRootClass: (struct RootList *) rootnew
{
	struct RootList *roothead;

	if(rootnew == &self->rootdef)
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
		[self forEachRootClass: self->rootdef.next];
		[self allocRootClass: self->rootdef.next];
		return;
	}
	roothead.next = &self->rootdef;
	roothead.prev = rootnew;
	roothead.cls = clsnew->root;
	roothead.meta = class_get_meta_class(clsnew->root);
	roothead.name = class_get_class_name(clsnew->root);
	self->rootdef.prev = &roothead;
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
	self->objdef.next = &self->objdef;
	self->objdef.prev = &self->objdef;
	self->rootdef.next = &self->rootdef;
	self->rootdef.prev = &self->rootdef;
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
	{
		Class cls = objc_lookup_class(clsname);
		if (cls != Nil)
			return cls;
	}

	/* Dynamic loading: try dlopen("<name>.so") as a last resort.
	 * Classic libobjc has no class-creation API, so real classes must
	 * come from shared objects loaded via libdl. */
	{
		char path[CMDSIZ];
		snprintf(path, sizeof path, "./%s.so", clsname);
		if (access(path, F_OK) == 0)
			[self loadImage: path];
		else
		{
			snprintf(path, sizeof path, "%s.so", clsname);
			if (access(path, F_OK) == 0)
				[self loadImage: path];
		}
		return objc_lookup_class(clsname);
	}
}

- (id) getObject: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = self->objdef.next; objnew != &self->objdef; objnew = objnew->next)
		if([self equalString: objname to: objnew->name])
			return objnew->obj;
	return nil;
}

- (struct ObjectList *) getObjectRecord: (const char *) objname
{
	struct ObjectList *objnew;

	for(objnew = self->objdef.next; objnew != &self->objdef; objnew = objnew->next)
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
	return &self->objdef;
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

/* Dynamically load a shared library (via libdl) and register every Objective-C
 * class it registers with the runtime, so resolve: can find them by name. */
- (void) loadImage: (const char *) path
{
	void *handle;
	void (*old_callback)(Class, Category *) = _objc_load_callback;
	int i;
	int start_count = loaded_class_count;

	_objc_load_callback = dyn_load_callback;
	handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
	_objc_load_callback = old_callback;

	if (!handle)
	{
		[self printString: dlerror()];
		[self putCharacter: '\n'];
		return;
	}

	if (loaded_image_count < 64)
		loaded_images[loaded_image_count++] = handle;

	/* Register every class the loaded image registered with the runtime */
	for (i = start_count; i < loaded_class_count; i++)
	{
		Class cls = loaded_classes[i];
		const char *name = class_get_class_name(cls);
		struct ClassList *clsnew;

		if (!name || *name == '\0')
			continue;
		if ([self getClassRecord: name] != NULL)
			continue;
		clsnew = malloc(sizeof *clsnew);
		clsnew->cls = cls;
		clsnew->super = class_get_super_class(cls);
		clsnew->root = [self getRootClass: cls];
		clsnew->meta = class_get_meta_class(cls);
		clsnew->name = strcpy(malloc(strlen(name) + 1), name);
		clsnew->next = &self->clsdef;
		clsnew->prev = self->clsdef.prev;
		self->clsdef.prev->next = clsnew;
		self->clsdef.prev = clsnew;
		[self printString: name];
		[self printString: "\n"];
	}
	self->output_done = 1;
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
	obj->next = &self->objdef;
	obj->prev = self->objdef.prev;
	obj->name = strcpy(malloc(strlen(name) + 1), name);
	obj->obj = val;
	self->objdef.prev->next = obj;
	self->objdef.prev = obj;
	return val;
}

- (id) getVariable: (const char *) name
{
	struct ObjectList *objnew;

	for(objnew = self->objdef.next; objnew != &self->objdef; objnew = objnew->next)
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
