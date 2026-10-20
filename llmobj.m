#import "llm.h"
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <sys/wait.h>
#import <dirent.h>

static char *readcap(const char *path)
{
	FILE *fp = fopen(path, "rb");
	char *buf;
	size_t n;

	if(fp == NULL)
		return strdup("");
	buf = malloc(LLM_OUTCAP + 1);
	n = fread(buf, 1, LLM_OUTCAP, fp);
	buf[n] = '\0';
	fclose(fp);
	return buf;
}

/* --- LLMResult: wraps a plain JSON value --- */

@implementation LLMResult

- initWithJVal: (struct JVal *) v
{
	[super init];
	val = v;
	return self;
}

- (struct JVal *) jsonValue
{
	return jclone(val);
}

- (const char *) kind
{
	return "LLMResult";
}

- (const char *) refName
{
	return "";
}

- (id) value: (struct Argument *) args
{
	return [[LLMResult alloc] initWithJVal: jclone(val)];
}

- free
{
	jfree(val);
	return [super free];
}
@end

/* --- LLMFile --- */

@implementation LLMFile

- initWithPath: (const char *) p
{
	[super init];
	if(stat(p, &st) != 0)
	{
		[super free];
		return nil;
	}
	path = strdup(p);
	ref = malloc(strlen(p) + 8);
	sprintf(ref, "$file:%s", p);
	return self;
}

- (const char *) kind
{
	return "LLMFile";
}

- (const char *) refName
{
	return ref;
}

- (struct JVal *) jsonValue
{
	struct JVal *v = jobj();
	const char *base = strrchr(path, '/');
	char pm[16];

	jset(v, "kind", jstr("LLMFile"));
	jset(v, "path", jstr(path));
	jset(v, "name", jstr(base != NULL ? base + 1 : path));
	jset(v, "isDirectory", jbool(S_ISDIR(st.st_mode) ? 1 : 0));
	jset(v, "size", jnum((double)st.st_size));
	jset(v, "mtime", jnum((double)st.st_mtime));
	sprintf(pm, "%o", (unsigned)(st.st_mode & 07777));
	jset(v, "permissions", jstr(pm));
	return v;
}

- (id) children: (struct Argument *) args
{
	struct JVal *arr = jarr();
	DIR *d;
	struct dirent *e;

	if(!S_ISDIR(st.st_mode))
		return [[LLMResult alloc] initWithJVal: arr];
	d = opendir(path);
	if(d == NULL)
		return [[LLMResult alloc] initWithJVal: arr];
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

- (id) contents: (struct Argument *) args
{
	if(S_ISDIR(st.st_mode))
		return [[LLMResult alloc]
			initWithJVal: jstr("[directory]")];
	{
		char *text = readcap(path);
		id r = [[LLMResult alloc] initWithJVal: jstr(text)];

		free(text);
		return r;
	}
}

- free
{
	free(path);
	free(ref);
	return [super free];
}
@end

/* --- LLMProcess: runs a program via execvp, no shell --- */

@implementation LLMProcess

- initWithArguments: (struct Argument *) args
{
	struct Argument *a;
	int k = 0;
	int outfd, errfd;
	char outn[] = "/tmp/llmsh-out-XXXXXX";
	char errn[] = "/tmp/llmsh-err-XXXXXX";

	[super init];
	cmdn = 0;
	if(args != NULL)
		for(a = args->next; a != args; a = a->next)
			cmdn++;
	if(cmdn == 0)
	{
		[super free];
		return nil;
	}
	cmd = malloc((cmdn + 1) * sizeof *cmd);
	for(a = args->next; a != args; a = a->next)
	{
		struct JVal *v = a->val;
		char buf[32];

		if(v != NULL && v->type == JSTR)
			cmd[k++] = strdup(v->string);
		else if(v != NULL && v->type == JNUM)
		{
			snprintf(buf, sizeof buf, "%lld", (long long)v->number);
			cmd[k++] = strdup(buf);
		}
		else if(v != NULL && v->type == JBOOL)
			cmd[k++] = strdup(v->boolean ? "true" : "false");
		else
			cmd[k++] = strdup("");
	}
	cmd[cmdn] = NULL;

	outfd = mkstemp(outn);
	errfd = mkstemp(errn);
	if(outfd < 0 || errfd < 0)
	{
		[super free];
		return nil;
	}
	pid = fork();
	if(pid == 0)
	{
		dup2(outfd, 1);
		dup2(errfd, 2);
		execvp(cmd[0], cmd);
		_exit(127);
	}
	close(outfd);
	close(errfd);
	if(pid < 0)
	{
		status = -1;
		out = strdup("");
		err = strdup("fork failed");
		ref = strdup("$proc:none");
		unlink(outn);
		unlink(errn);
		return self;
	}
	waitpid(pid, &status, 0);
	out = readcap(outn);
	err = readcap(errn);
	unlink(outn);
	unlink(errn);
	ref = malloc(32);
	sprintf(ref, "$proc:%d", (int)pid);
	return self;
}

- (const char *) kind
{
	return "LLMProcess";
}

- (const char *) refName
{
	return ref;
}

- (struct JVal *) jsonValue
{
	struct JVal *v = jobj();
	struct JVal *av = jarr();
	int i;

	jset(v, "kind", jstr("LLMProcess"));
	jset(v, "pid", jnum((double)pid));
	jset(v, "command", jstr(cmd[0]));
	for(i = 0; i < cmdn; i++)
		jpush(av, jstr(cmd[i]));
	jset(v, "arguments", av);
	jset(v, "exitCode", jnum(WIFEXITED(status) ? WEXITSTATUS(status) : -1));
	jset(v, "output", jstr(out != NULL ? out : ""));
	jset(v, "errorOutput", jstr(err != NULL ? err : ""));
	return v;
}

- (id) output: (struct Argument *) args
{
	return [[LLMResult alloc] initWithJVal: jstr(out != NULL ? out : "")];
}

- (id) errorOutput: (struct Argument *) args
{
	return [[LLMResult alloc] initWithJVal: jstr(err != NULL ? err : "")];
}

- (id) exitCode: (struct Argument *) args
{
	return [[LLMResult alloc]
		initWithJVal: jnum(WIFEXITED(status) ? WEXITSTATUS(status) : -1)];
}

- (id) pid: (struct Argument *) args
{
	return [[LLMResult alloc] initWithJVal: jnum((double)pid)];
}
@end

/* --- LLMVariable --- */

@implementation LLMVariable

- initWithName: (const char *) n value: (struct JVal *) v
{
	[super init];
	name = strdup(n);
	ref = malloc(strlen(n) + 7);
	sprintf(ref, "$var:%s", n);
	value = jclone(v);
	return self;
}

- (const char *) kind
{
	return "LLMVariable";
}

- (const char *) refName
{
	return ref;
}

- (struct JVal *) jsonValue
{
	struct JVal *v = jobj();

	jset(v, "kind", jstr("LLMVariable"));
	jset(v, "name", jstr(name));
	jset(v, "value", jclone(value));
	return v;
}

- (id) value: (struct Argument *) args
{
	return [[LLMResult alloc] initWithJVal: jclone(value)];
}

- (void) setValue: (struct JVal *) v
{
	jfree(value);
	value = jclone(v);
}
@end

/* --- LLMInstance: instance of a user-defined class --- */

@implementation LLMInstance

- initWithClass: (struct UserClass *) c name: (const char *) n
{
	[super init];
	cls = c;
	ref = strdup(n);
	return self;
}

- (struct UserClass *) userClass
{
	return cls;
}

- (const char *) kind
{
	return "LLMInstance";
}

- (const char *) refName
{
	return ref;
}

- (struct JVal *) jsonValue
{
	struct JVal *v = jobj();
	struct JVal *ms = jarr();

	jset(v, "kind", jstr("LLMInstance"));
	jset(v, "class", jstr(cls != NULL ? cls->name : ""));
	if(cls != NULL)
	{
		struct UserMethod *m;

		for(m = cls->methods.next; m != &cls->methods; m = m->next)
			jpush(ms, jstr(m->name));
	}
	jset(v, "methods", ms);
	return v;
}
@end
