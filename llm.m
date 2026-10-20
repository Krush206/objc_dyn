#import "llm.h"
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <dirent.h>

/*
 * The tool catalog doubles as the schema an LLM reads: receiver kind,
 * selector, argument spec, one-line help.  Dispatch is gated through
 * this table — nothing else can be invoked.
 */
struct Tool llmTools[] = {
	{ LLM_SHELLNAME, "describeSystem:", "",
	  "return the full catalog: protocol, tools, registered objects, user-defined classes, runtime classes" },
	{ LLM_SHELLNAME, "describeObject:", "name",
	  "describe one registered object: kind, ref, value, methods" },
	{ LLM_SHELLNAME, "listObjects:", "",
	  "list all registered object names" },
	{ LLM_SHELLNAME, "getVariable:", "name",
	  "return the variable object named name" },
	{ LLM_SHELLNAME, "setVariable:", "name value",
	  "create or update a variable object; value may be any JSON value" },
	{ LLM_SHELLNAME, "fileAt:", "path",
	  "return a file object for path" },
	{ LLM_SHELLNAME, "listDirectory:", "path",
	  "list a directory as JSON file entries" },
	{ LLM_SHELLNAME, "runCommand:", "command argument ...",
	  "execute a program directly (execvp, no shell), wait for it, capture stdout and stderr" },
	{ LLM_SHELLNAME, "sendTo:", "receiver selector argument ...",
	  "send one message through the gateway; arguments are JSON values" },
	{ LLM_SHELLNAME, "pipeline:", "program",
	  "interpret a JSON program: an array of {receiver, selector, arguments} message sends, last result returned" },
	{ LLM_SHELLNAME, "defineClass:", "name superclass",
	  "declare a new class of objects" },
	{ LLM_SHELLNAME, "defineMethod:", "class selector program",
	  "declare a method on a user class; body is a JSON program; $self is the receiver instance, $arg:0 ... the arguments" },
	{ LLM_SHELLNAME, "newInstanceOfClass:", "class",
	  "instantiate a user class; returns a named instance object" },
	{ LLM_SHELLNAME, "history:", "",
	  "recent request/reply pairs, oldest first" },
	{ LLM_SHELLNAME, "quit:", "",
	  "end the session" },
	{ "LLMFile", "children:", "",
	  "list the children of a directory" },
	{ "LLMFile", "contents:", "",
	  "read a file as text (first 256 KiB)" },
	{ "LLMProcess", "output:", "",
	  "standard output of the finished process" },
	{ "LLMProcess", "errorOutput:", "",
	  "standard error of the finished process" },
	{ "LLMProcess", "exitCode:", "",
	  "exit status of the process" },
	{ "LLMProcess", "pid:", "",
	  "process id" },
	{ "LLMVariable", "value:", "",
	  "current value of the variable" },
	{ "LLMResult", "value:", "",
	  "the wrapped JSON value" },
	{ NULL, NULL, NULL, NULL }
};

/* --- argument helpers (C side) --- */

struct JVal *llm_arg(struct Argument *head, int i)
{
	struct Argument *a;
	int k = 0;

	if(head == NULL)
		return NULL;
	for(a = head->next; a != head; a = a->next)
		if(k++ == i)
			return a->val;
	return NULL;
}

const char *llm_argstr(struct Argument *head, int i)
{
	struct JVal *v = llm_arg(head, i);

	return (v != NULL && v->type == JSTR) ? v->string : NULL;
}

struct Argument *llm_argslice(struct Argument *head, int from)
{
	struct Argument *nhead = calloc(1, sizeof *nhead);
	struct Argument *a;
	int k = 0;

	nhead->next = nhead->prev = nhead;
	if(head == NULL)
		return nhead;
	for(a = head->next; a != head; a = a->next, k++)
	{
		struct Argument *n;

		if(k < from)
			continue;
		n = malloc(sizeof *n);
		n->val = a->val;
		n->prev = nhead->prev;
		n->next = nhead;
		nhead->prev->next = n;
		nhead->prev = n;
	}
	return nhead;
}

/* --- static type-cast helpers for the uniform object surface --- */

static const char *kindOf(id obj)
{
	return [(LLMResult *)obj kind];
}

static const char *refOf(id obj)
{
	return [(LLMResult *)obj refName];
}

static struct JVal *jsonOf(id obj)
{
	return [(LLMResult *)obj jsonValue];
}

static int responds(id obj, SEL sel)
{
	return [(Object *)obj respondsTo: sel] != 0;
}

static struct UserMethod *findMethod(struct UserClass *c, const char *name)
{
	struct UserMethod *m;

	if(c == NULL)
		return NULL;
	for(m = c->methods.next; m != &c->methods; m = m->next)
		if(strcmp(m->name, name) == 0)
			return m;
	return NULL;
}

/* --- shell core --- */

@implementation LLMShell

- init
{
	int i;

	[super init];
	objects.next = objects.prev = &objects;
	classes.next = classes.prev = &classes;
	for(i = 0; i < LLM_HISTN; i++)
		hist[i] = NULL;
	histp = histn = seq = done = 0;
	errv = NULL;
	{
		extern void __objc_resolve_class_links(void);

		__objc_resolve_class_links();
	}
	[self registerObject: self name: LLM_SHELLNAME];
	return self;
}

- (void) registerObject: (id) obj name: (const char *) name
{
	struct NamedObject *o;

	for(o = objects.next; o != &objects; o = o->next)
		if(strcmp(o->name, name) == 0)
		{
			o->obj = obj;
			return;
		}
	o = malloc(sizeof *o);
	o->obj = obj;
	o->name = strdup(name);
	o->next = &objects;
	o->prev = objects.prev;
	objects.prev->next = o;
	objects.prev = o;
}

- (id) resolve: (const char *) name
{
	struct NamedObject *o;

	if(name == NULL)
		return nil;
	if(strcmp(name, LLM_SHELLNAME) == 0)
		return self;
	for(o = objects.next; o != &objects; o = o->next)
		if(strcmp(o->name, name) == 0)
			return o->obj;
	return nil;
}

- (struct UserClass *) findClass: (const char *) name
{
	struct UserClass *c;

	for(c = classes.next; c != &classes; c = c->next)
		if(strcmp(c->name, name) == 0)
			return c;
	return NULL;
}

- (void) setErr: (const char *) e
{
	free(errv);
	errv = e != NULL ? strdup(e) : NULL;
}

- (const char *) errval
{
	return errv;
}

/* --- gateway dispatch --- */

- (id) dispatch: (id) recv selector: (const char *) selname
	arguments: (struct Argument *) args depth: (int) depth
{
	const char *kind;
	SEL sel;
	IMP imp;
	struct Tool *t;

	if(depth > LLM_MAXDEPTH)
	{
		[self setErr: ERR_DEPTH];
		return nil;
	}
	kind = kindOf(recv);
	if(strcmp(kind, "LLMInstance") == 0)
	{
		struct UserClass *c = [(LLMInstance *)recv userClass];
		struct UserMethod *m = findMethod(c, selname);

		if(m != NULL)
			return [self interpret: m->program self: recv
				arguments: args depth: depth + 1];
		[self setErr: ERR_NOMETHOD];
		return nil;
	}
	for(t = llmTools; t->name != NULL; t++)
		if(strcmp(t->recv, kind) == 0 && strcmp(t->name, selname) == 0)
			break;
	if(t->name == NULL)
	{
		[self setErr: ERR_NOMETHOD];
		return nil;
	}
	sel = sel_get_uid(selname);
	if(!responds(recv, sel))
	{
		[self setErr: ERR_NOMETHOD];
		return nil;
	}
	imp = objc_msg_lookup(recv, sel);
	return ((id (*)(id, SEL, struct Argument *))imp)(recv, sel, args);
}

/* --- user method interpreter --- */

- (id) interpret: (struct JVal *) prog self: (id) selfobj
	arguments: (struct Argument *) args depth: (int) depth
{
	id result = nil;
	size_t i;

	if(prog == NULL || prog->type != JARR)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	for(i = 0; i < prog->count; i++)
	{
		struct JVal *step = prog->vals[i];
		struct JVal *rj, *sj;
		id recv;
		struct Argument *alist;

		if(step->type != JOBJ)
		{
			[self setErr: ERR_BADMSG];
			return nil;
		}
		rj = jget(step, "receiver");
		sj = jget(step, "selector");
		if(rj == NULL || rj->type != JSTR || sj == NULL || sj->type != JSTR)
		{
			[self setErr: ERR_BADMSG];
			return nil;
		}
		if(strcmp(rj->string, "$self") == 0)
			recv = selfobj;
		else
			recv = [self resolve: rj->string];
		if(recv == nil)
		{
			[self setErr: ERR_NORECV];
			return nil;
		}
		alist = [self makeArguments: jget(step, "arguments")];
		result = [self dispatch: recv selector: sj->string
			arguments: alist depth: depth + 1];
		[self freeArguments: alist];
		if(result == nil && [self errval] != NULL)
			return nil;
	}
	return result;
}

/* --- argument lists --- */

- (struct Argument *) makeArguments: (struct JVal *) arr
{
	struct Argument *head = calloc(1, sizeof *head);
	size_t i;

	head->next = head->prev = head;
	if(arr == NULL || arr->type != JARR)
		return head;
	for(i = 0; i < arr->count; i++)
	{
		struct Argument *n = malloc(sizeof *n);

		n->val = arr->vals[i];
		n->prev = head->prev;
		n->next = head;
		head->prev->next = n;
		head->prev = n;
	}
	return head;
}

- (void) freeArguments: (struct Argument *) head
{
	struct Argument *a = head->next;

	while(a != head)
	{
		struct Argument *n = a->next;

		free(a);
		a = n;
	}
	free(head);
}

/* --- replies --- */

- (struct JVal *) buildReply: (struct JVal *) idv ok: (int) okv
	error: (const char *) e result: (struct JVal *) rv
	ref: (const char *) ref
{
	struct JVal *rep = jobj();

	if(idv != NULL)
		jset(rep, "id", jclone(idv));
	jset(rep, "ok", jbool(okv));
	if(e != NULL)
		jset(rep, "error", jstr(e));
	if(okv)
	{
		if(ref != NULL && ref[0] != '\0')
			jset(rep, "ref", jstr(ref));
		jset(rep, "result", rv != NULL ? rv : jnull());
	}
	else
		jfree(rv);
	return rep;
}

- (void) emitError: (struct JVal *) idv message: (const char *) msg
{
	struct JVal *rep = jobj();

	if(idv != NULL)
		jset(rep, "id", jclone(idv));
	jset(rep, "ok", jbool(0));
	jset(rep, "error", jstr(msg));
	jprint(rep, stdout);
	fputc('\n', stdout);
	fflush(stdout);
	jfree(rep);
}

- (void) record: (struct JVal *) req reply: (struct JVal *) rep
{
	struct JVal *h;

	if(req == NULL)
		return;
	h = jobj();
	jset(h, "request", jclone(req));
	if(rep != NULL)
		jset(h, "reply", jclone(rep));
	if(hist[histp] != NULL)
		jfree(hist[histp]);
	hist[histp] = h;
	histp = (histp + 1) % LLM_HISTN;
	if(histn < LLM_HISTN)
		histn++;
}

- (void) handleLine: (const char *) line
{
	struct JVal *req = NULL;
	const char *e = jparse(line, &req);
	id recv, result;
	struct JVal *idv, *rj, *sj, *rep;
	struct Argument *alist;
	char *s;

	if(e != NULL)
	{
		[self emitError: NULL message: e];
		if(req != NULL)
			jfree(req);
		return;
	}
	idv = jget(req, "id");
	rj = jget(req, "receiver");
	sj = jget(req, "selector");
	if(rj == NULL || rj->type != JSTR || sj == NULL || sj->type != JSTR)
	{
		[self emitError: idv message: ERR_BADMSG];
		jfree(req);
		return;
	}
	recv = [self resolve: rj->string];
	if(recv == nil)
	{
		[self emitError: idv message: ERR_NORECV];
		jfree(req);
		return;
	}
	alist = [self makeArguments: jget(req, "arguments")];
	[self setErr: NULL];
	result = [self dispatch: recv selector: sj->string
		arguments: alist depth: 0];
	[self freeArguments: alist];
	{
		int okv = 1;
		const char *err = NULL;
		const char *ref = NULL;
		struct JVal *rv = NULL;

		if(result == nil)
		{
			if([self errval] != NULL)
			{
				okv = 0;
				err = [self errval];
			}
		}
		else if(responds(result, sel_get_uid("jsonValue")))
		{
			rv = jsonOf(result);
			ref = refOf(result);
		}
		else
		{
			okv = 0;
			err = "unserializable result";
		}
		rep = [self buildReply: idv ok: okv error: err
			result: rv ref: ref];
	}
	s = jdumps(rep);
	if(strlen(s) <= LLM_RECCAP)
		[self record: req reply: rep];
	fputs(s, stdout);
	fputc('\n', stdout);
	fflush(stdout);
	free(s);
	jfree(rep);
	jfree(req);
}

- (void) runProtocol
{
	char *line = NULL;
	size_t cap = 0;

	if(isatty(0))
		fprintf(stderr, "llmsh %s ready\n", LLM_PROTOCOL);
	for(;;)
	{
		ssize_t n = getline(&line, &cap, stdin);

		if(n < 0)
			break;
		while(n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r'))
			line[--n] = '\0';
		if(n == 0 || line[0] == '#')
			continue;
		[self handleLine: line];
		if(done)
			break;
	}
	free(line);
}

/* --- introspection --- */

- (struct JVal *) describeSystemValue
{
	struct JVal *sys = jobj();
	struct JVal *tl, *ob, *uc, *rc;
	struct Tool *t;
	struct NamedObject *o;
	struct UserClass *c;

	tl = jarr();
	for(t = llmTools; t->name != NULL; t++)
	{
		struct JVal *e = jobj();

		jset(e, "receiver", jstr(t->recv));
		jset(e, "selector", jstr(t->name));
		jset(e, "arguments", jstr(t->args));
		jset(e, "help", jstr(t->help));
		jpush(tl, e);
	}
	jset(sys, "tools", tl);

	ob = jobj();
	for(o = objects.next; o != &objects; o = o->next)
		jset(ob, o->name, jsonOf(o->obj));
	jset(sys, "objects", ob);

	uc = jobj();
	for(c = classes.next; c != &classes; c = c->next)
	{
		struct JVal *cj = jobj();
		struct JVal *ms = jarr();
		struct UserMethod *m;

		jset(cj, "super", jstr(c->super));
		for(m = c->methods.next; m != &c->methods; m = m->next)
			jpush(ms, jstr(m->name));
		jset(cj, "methods", ms);
		jset(uc, c->name, cj);
	}
	jset(sys, "userClasses", uc);

	rc = jarr();
	{
		void *state = NULL;
		Class cls;

		while((cls = objc_next_class(&state)) != Nil)
			jpush(rc, jstr(class_get_class_name(cls)));
	}
	jset(sys, "runtimeClasses", rc);

	jset(sys, "protocol", jstr(LLM_PROTOCOL));
	return sys;
}

- (const char *) kind
{
	return LLM_SHELLNAME;
}

- (const char *) refName
{
	return LLM_SHELLNAME;
}

- (struct JVal *) jsonValue
{
	struct JVal *v = jobj();

	jset(v, "kind", jstr(LLM_SHELLNAME));
	jset(v, "protocol", jstr(LLM_PROTOCOL));
	return v;
}
@end

/* --- shell tools --- */

@implementation LLMShell (Tools)

- (id) describeSystem: (struct Argument *) args
{
	return [[LLMResult alloc] initWithJVal: [self describeSystemValue]];
}

- (id) describeObject: (struct Argument *) args
{
	const char *name = llm_argstr(args, 0);
	id obj;
	struct JVal *v;

	if(name == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	obj = [self resolve: name];
	if(obj == nil)
	{
		[self setErr: ERR_NORECV];
		return nil;
	}
	v = jobj();
	jset(v, "name", jstr(name));
	jset(v, "kind", jstr(kindOf(obj)));
	if(refOf(obj) != NULL && refOf(obj)[0] != '\0')
		jset(v, "ref", jstr(refOf(obj)));
	jset(v, "object", jsonOf(obj));
	if(strcmp(kindOf(obj), "LLMInstance") == 0)
	{
		struct UserClass *c = [(LLMInstance *)obj userClass];
		struct JVal *ms = jarr();
		struct UserMethod *m;

		if(c != NULL)
			for(m = c->methods.next; m != &c->methods; m = m->next)
				jpush(ms, jstr(m->name));
		jset(v, "methods", ms);
	}
	return [[LLMResult alloc] initWithJVal: v];
}

- (id) listObjects: (struct Argument *) args
{
	struct JVal *arr = jarr();
	struct NamedObject *o;

	for(o = objects.next; o != &objects; o = o->next)
		jpush(arr, jstr(o->name));
	return [[LLMResult alloc] initWithJVal: arr];
}

- (id) getVariable: (struct Argument *) args
{
	const char *name = llm_argstr(args, 0);
	char *ref;
	id v;

	if(name == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	ref = malloc(strlen(name) + 6);
	sprintf(ref, "$var:%s", name);
	v = [self resolve: ref];
	free(ref);
	if(v == nil)
	{
		[self setErr: ERR_NOTFOUND];
		return nil;
	}
	return v;
}

- (id) setVariable: (struct Argument *) args
{
	const char *name = llm_argstr(args, 0);
	struct JVal *val = llm_arg(args, 1);
	char *ref;
	id v;

	if(name == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	ref = malloc(strlen(name) + 6);
	sprintf(ref, "$var:%s", name);
	v = [self resolve: ref];
	free(ref);
	if(v != nil)
		[(LLMVariable *)v setValue: val];
	else
	{
		v = [[LLMVariable alloc] initWithName: name value: val];
		[self registerObject: v name: [v refName]];
	}
	return v;
}

- (id) fileAt: (struct Argument *) args
{
	const char *path = llm_argstr(args, 0);
	char *ref;
	id f;

	if(path == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	ref = malloc(strlen(path) + 8);
	sprintf(ref, "$file:%s", path);
	f = [self resolve: ref];
	free(ref);
	if(f != nil)
		return f;
	f = [[LLMFile alloc] initWithPath: path];
	if(f == nil)
	{
		[self setErr: ERR_NOTFOUND];
		return nil;
	}
	[self registerObject: f name: [f refName]];
	return f;
}

- (id) listDirectory: (struct Argument *) args
{
	const char *path = llm_argstr(args, 0);
	struct JVal *arr;
	DIR *d;
	struct dirent *e;

	if(path == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	arr = jarr();
	d = opendir(path);
	if(d == NULL)
	{
		jfree(arr);
		[self setErr: ERR_NOTFOUND];
		return nil;
	}
	while((e = readdir(d)) != NULL)
	{
		struct JVal *f;
		char *full;
		struct stat cst;

		if(strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0)
			continue;
		full = malloc(strlen(path) + strlen(e->d_name) + 2);
		sprintf(full, "%s/%s", path, e->d_name);
		f = jobj();
		jset(f, "name", jstr(e->d_name));
		jset(f, "path", jstr(full));
		if(stat(full, &cst) == 0)
		{
			jset(f, "isDirectory", jbool(S_ISDIR(cst.st_mode) ? 1 : 0));
			jset(f, "size", jnum((double)cst.st_size));
		}
		jpush(arr, f);
		free(full);
	}
	closedir(d);
	return [[LLMResult alloc] initWithJVal: arr];
}

- (id) runCommand: (struct Argument *) args
{
	id p = [[LLMProcess alloc] initWithArguments: args];

	if(p == nil)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	[self registerObject: p name: [p refName]];
	return p;
}

- (id) sendTo: (struct Argument *) args
{
	const char *rn = llm_argstr(args, 0);
	const char *sn = llm_argstr(args, 1);
	id recv, result;
	struct Argument *sub;

	if(rn == NULL || sn == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	recv = [self resolve: rn];
	if(recv == nil)
	{
		[self setErr: ERR_NORECV];
		return nil;
	}
	sub = llm_argslice(args, 2);
	result = [self dispatch: recv selector: sn arguments: sub depth: 1];
	[self freeArguments: sub];
	return result;
}

- (id) pipeline: (struct Argument *) args
{
	struct JVal *prog = llm_arg(args, 0);

	if(prog == NULL || prog->type != JARR)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	return [self interpret: prog self: nil arguments: NULL depth: 1];
}

- (id) defineClass: (struct Argument *) args
{
	const char *name = llm_argstr(args, 0);
	const char *sup = llm_argstr(args, 1);
	struct UserClass *c;
	struct JVal *v;

	if(name == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	if([self findClass: name] != NULL)
	{
		[self setErr: ERR_EXISTS];
		return nil;
	}
	c = calloc(1, sizeof *c);
	c->name = strdup(name);
	c->super = strdup(sup != NULL ? sup : "Object");
	c->methods.next = c->methods.prev = &c->methods;
	c->next = &classes;
	c->prev = classes.prev;
	classes.prev->next = c;
	classes.prev = c;
	v = jobj();
	jset(v, "class", jstr(c->name));
	jset(v, "super", jstr(c->super));
	return [[LLMResult alloc] initWithJVal: v];
}

- (id) defineMethod: (struct Argument *) args
{
	const char *cn = llm_argstr(args, 0);
	const char *mn = llm_argstr(args, 1);
	struct JVal *prog = llm_arg(args, 2);
	struct UserClass *c;
	struct UserMethod *m;
	size_t i;
	struct JVal *v;

	if(cn == NULL || mn == NULL || prog == NULL || prog->type != JARR)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	for(i = 0; i < prog->count; i++)
		if(prog->vals[i]->type != JOBJ)
		{
			[self setErr: ERR_BADMSG];
			return nil;
		}
	c = [self findClass: cn];
	if(c == NULL)
	{
		[self setErr: ERR_NOTFOUND];
		return nil;
	}
	m = findMethod(c, mn);
	if(m != NULL)
	{
		jfree(m->program);
		m->program = jclone(prog);
	}
	else
	{
		m = calloc(1, sizeof *m);
		m->name = strdup(mn);
		m->program = jclone(prog);
		m->next = &c->methods;
		m->prev = c->methods.prev;
		c->methods.prev->next = m;
		c->methods.prev = m;
	}
	v = jobj();
	jset(v, "class", jstr(c->name));
	jset(v, "method", jstr(m->name));
	return [[LLMResult alloc] initWithJVal: v];
}

- (id) newInstanceOfClass: (struct Argument *) args
{
	const char *cn = llm_argstr(args, 0);
	struct UserClass *c;
	id inst;
	char ref[32];

	if(cn == NULL)
	{
		[self setErr: ERR_ARGS];
		return nil;
	}
	c = [self findClass: cn];
	if(c == NULL)
	{
		[self setErr: ERR_NOTFOUND];
		return nil;
	}
	sprintf(ref, "$inst:%d", seq++);
	inst = [[LLMInstance alloc] initWithClass: c name: ref];
	[self registerObject: inst name: ref];
	return inst;
}

- (id) history: (struct Argument *) args
{
	struct JVal *arr = jarr();
	int k;

	for(k = 0; k < histn; k++)
	{
		int i = (histp + LLM_HISTN - histn + k) % LLM_HISTN;

		jpush(arr, jclone(hist[i]));
	}
	return [[LLMResult alloc] initWithJVal: arr];
}

- (id) quit: (struct Argument *) args
{
	done = 1;
	return nil;
}
@end

int main(int argc, char **argv)
{
	id shell = [[LLMShell alloc] init];

	[shell runProtocol];
	[shell free];
	return 0;
}
