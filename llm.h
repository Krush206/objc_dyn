#ifndef LLM_H
#define LLM_H 1
#import <stdio.h>
#import <sys/types.h>
#import <sys/stat.h>
#import "/usr/local/include/objc/Object.h"
#import "/usr/local/include/objc/objc-api.h"
#import "json.h"

/*
 * llmsh — an object-oriented shell designed for LLMs, on classic libobjc.
 *
 * The shell is a message gateway: an LLM never writes command text, it
 * sends JSON messages of the form
 *
 *	{"id": "..", "receiver": "$shell", "selector": "fileAt:",
 *	 "arguments": ["/etc/motd"]}
 *
 * over stdin (one per line); the shell resolves the receiver in its
 * object registry, gates the selector through its tool catalog, and
 * dispatches it with objc_msg_lookup.  Every LLM-visible method has the
 * uniform signature - (id) name: (struct Argument *) args, so tools are
 * ordinary Objective-C methods and user-defined methods can be
 * interpreted through the same gateway.
 */

#define LLM_PROTOCOL  "llmsh/1"
#define LLM_SHELLNAME "$shell"
#define LLM_HISTN     32
#define LLM_MAXDEPTH  64
#define LLM_OUTCAP    (256 * 1024)
#define LLM_RECCAP    (64 * 1024)

#define ERR_BADMSG   "bad message"
#define ERR_NORECV   "receiver not found"
#define ERR_NOMETHOD "no such method"
#define ERR_ARGS     "bad arguments"
#define ERR_NOTFOUND "not found"
#define ERR_DEPTH    "message nesting too deep"
#define ERR_EXISTS   "already defined"

/* One JSON-typed argument of a message send. */
struct Argument {
	struct JVal *val;
	struct Argument *next;
	struct Argument *prev;
};

/* Named object registry entry (circular list, sentinel head). */
struct NamedObject {
	id obj;
	char *name;
	struct NamedObject *next;
	struct NamedObject *prev;
};

/* User-defined method: body is a JSON program of message sends. */
struct UserMethod {
	char *name;
	struct JVal *program;
	struct UserMethod *next;
	struct UserMethod *prev;
};

/* User-defined class. */
struct UserClass {
	char *name;
	char *super;
	struct UserMethod methods;
	struct UserClass *next;
	struct UserClass *prev;
};

/* Catalog entry: one LLM-callable method. */
struct Tool {
	const char *recv;
	const char *name;
	const char *args;
	const char *help;
};

extern struct Tool llmTools[];

struct JVal *llm_arg(struct Argument *head, int i);
const char *llm_argstr(struct Argument *head, int i);
struct Argument *llm_argslice(struct Argument *head, int from);

@interface LLMShell: Object
{
	struct NamedObject objects;
	struct UserClass classes;
	struct JVal *hist[LLM_HISTN];
	int histp;
	int histn;
	int seq;
	int done;
	char *errv;
}
- init;
- (void) runProtocol;
- (void) handleLine: (const char *) line;
- (id) resolve: (const char *) name;
- (void) registerObject: (id) obj name: (const char *) name;
- (struct UserClass *) findClass: (const char *) name;
- (id) dispatch: (id) recv selector: (const char *) selname
	arguments: (struct Argument *) args depth: (int) depth;
- (id) interpret: (struct JVal *) prog self: (id) selfobj
	arguments: (struct Argument *) args depth: (int) depth;
- (struct Argument *) makeArguments: (struct JVal *) arr;
- (void) freeArguments: (struct Argument *) head;
- (struct JVal *) describeSystemValue;
- (void) emitError: (struct JVal *) idv message: (const char *) msg;
- (struct JVal *) buildReply: (struct JVal *) idv ok: (int) okv
	error: (const char *) e result: (struct JVal *) rv
	ref: (const char *) ref;
- (void) setErr: (const char *) e;
- (const char *) errval;
- (void) record: (struct JVal *) req reply: (struct JVal *) rep;
@end

@interface LLMShell (Tools)
- (id) describeSystem: (struct Argument *) args;
- (id) describeObject: (struct Argument *) args;
- (id) listObjects: (struct Argument *) args;
- (id) getVariable: (struct Argument *) args;
- (id) setVariable: (struct Argument *) args;
- (id) fileAt: (struct Argument *) args;
- (id) listDirectory: (struct Argument *) args;
- (id) runCommand: (struct Argument *) args;
- (id) sendTo: (struct Argument *) args;
- (id) pipeline: (struct Argument *) args;
- (id) defineClass: (struct Argument *) args;
- (id) defineMethod: (struct Argument *) args;
- (id) newInstanceOfClass: (struct Argument *) args;
- (id) history: (struct Argument *) args;
- (id) quit: (struct Argument *) args;
@end

/* Every object visible to the LLM implements kind/refName/jsonValue. */

@interface LLMResult: Object
{
	struct JVal *val;
}
- initWithJVal: (struct JVal *) v;
- (struct JVal *) jsonValue;
- (const char *) kind;
- (const char *) refName;
- (id) value: (struct Argument *) args;
- free;
@end

@interface LLMFile: Object
{
	char *path;
	char *ref;
	struct stat st;
}
- initWithPath: (const char *) p;
- (const char *) kind;
- (const char *) refName;
- (struct JVal *) jsonValue;
- (id) children: (struct Argument *) args;
- (id) contents: (struct Argument *) args;
- free;
@end

@interface LLMProcess: Object
{
	pid_t pid;
	int status;
	char **cmd;
	int cmdn;
	char *out;
	char *err;
	char *ref;
}
- initWithArguments: (struct Argument *) args;
- (const char *) kind;
- (const char *) refName;
- (struct JVal *) jsonValue;
- (id) output: (struct Argument *) args;
- (id) errorOutput: (struct Argument *) args;
- (id) exitCode: (struct Argument *) args;
- (id) pid: (struct Argument *) args;
@end

@interface LLMVariable: Object
{
	char *name;
	char *ref;
	struct JVal *value;
}
- initWithName: (const char *) n value: (struct JVal *) v;
- (const char *) kind;
- (const char *) refName;
- (struct JVal *) jsonValue;
- (id) value: (struct Argument *) args;
- (void) setValue: (struct JVal *) v;
@end

@interface LLMInstance: Object
{
	struct UserClass *cls;
	char *ref;
}
- initWithClass: (struct UserClass *) c name: (const char *) n;
- (struct UserClass *) userClass;
- (const char *) kind;
- (const char *) refName;
- (struct JVal *) jsonValue;
@end
#endif /* !LLM_H */
