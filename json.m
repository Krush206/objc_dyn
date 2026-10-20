#import "json.h"
#import <stdlib.h>
#import <string.h>
#import <math.h>

#define JMAXDEPTH 64

/* --- construction --- */

struct JVal *jnull(void)
{
	struct JVal *v = calloc(1, sizeof *v);
	v->type = JNULL;
	return v;
}

struct JVal *jbool(int b)
{
	struct JVal *v = calloc(1, sizeof *v);
	v->type = JBOOL;
	v->boolean = b ? 1 : 0;
	return v;
}

struct JVal *jnum(double n)
{
	struct JVal *v = calloc(1, sizeof *v);
	v->type = JNUM;
	v->number = n;
	return v;
}

struct JVal *jstr(const char *s)
{
	struct JVal *v = calloc(1, sizeof *v);
	v->type = JSTR;
	v->string = strdup(s != NULL ? s : "");
	return v;
}

struct JVal *jarr(void)
{
	struct JVal *v = calloc(1, sizeof *v);
	v->type = JARR;
	return v;
}

struct JVal *jobj(void)
{
	struct JVal *v = calloc(1, sizeof *v);
	v->type = JOBJ;
	return v;
}

static void jgrow(struct JVal *v)
{
	if(v->count == v->cap)
	{
		v->cap = v->cap ? v->cap * 2 : 8;
		v->vals = realloc(v->vals, v->cap * sizeof *v->vals);
		if(v->type == JOBJ)
			v->keys = realloc(v->keys, v->cap * sizeof *v->keys);
	}
}

void jpush(struct JVal *arr, struct JVal *v)
{
	jgrow(arr);
	arr->vals[arr->count++] = v;
}

void jset(struct JVal *obj, const char *key, struct JVal *v)
{
	size_t i;

	for(i = 0; i < obj->count; i++)
		if(strcmp(obj->keys[i], key) == 0)
		{
			jfree(obj->vals[i]);
			obj->vals[i] = v;
			return;
		}
	jgrow(obj);
	obj->keys[obj->count] = strdup(key);
	obj->vals[obj->count] = v;
	obj->count++;
}

struct JVal *jget(struct JVal *obj, const char *key)
{
	size_t i;

	if(obj == NULL || obj->type != JOBJ)
		return NULL;
	for(i = 0; i < obj->count; i++)
		if(strcmp(obj->keys[i], key) == 0)
			return obj->vals[i];
	return NULL;
}

struct JVal *jclone(const struct JVal *v)
{
	struct JVal *n;
	size_t i;

	if(v == NULL)
		return NULL;
	switch(v->type)
	{
	case JNULL:
		return jnull();
	case JBOOL:
		return jbool(v->boolean);
	case JNUM:
		return jnum(v->number);
	case JSTR:
		return jstr(v->string);
	case JARR:
		n = jarr();
		for(i = 0; i < v->count; i++)
			jpush(n, jclone(v->vals[i]));
		return n;
	case JOBJ:
		n = jobj();
		for(i = 0; i < v->count; i++)
			jset(n, v->keys[i], jclone(v->vals[i]));
		return n;
	}
	return NULL;
}

void jfree(struct JVal *v)
{
	size_t i;

	if(v == NULL)
		return;
	switch(v->type)
	{
	case JSTR:
		free(v->string);
		break;
	case JBOOL:
	case JNUM:
	case JNULL:
		break;
	case JARR:
		for(i = 0; i < v->count; i++)
			jfree(v->vals[i]);
		free(v->vals);
		break;
	case JOBJ:
		for(i = 0; i < v->count; i++)
		{
			free(v->keys[i]);
			jfree(v->vals[i]);
		}
		free(v->keys);
		free(v->vals);
		break;
	}
	free(v);
}

/* --- writer --- */

struct JBuf {
	char *s;
	size_t n;
	size_t cap;
};

static void jbputc(struct JBuf *b, char c)
{
	if(b->n + 1 >= b->cap)
	{
		b->cap *= 2;
		b->s = realloc(b->s, b->cap);
	}
	b->s[b->n++] = c;
}

static void jbputs(struct JBuf *b, const char *s)
{
	while(*s)
		jbputc(b, *s++);
}

static void jbstr(struct JBuf *b, const char *s)
{
	jbputc(b, '"');
	for(; *s; s++)
	{
		unsigned char c = *s;
		if(c == '"' || c == '\\')
		{
			jbputc(b, '\\');
			jbputc(b, c);
		}
		else if(c == '\n')
			jbputs(b, "\\n");
		else if(c == '\r')
			jbputs(b, "\\r");
		else if(c == '\t')
			jbputs(b, "\\t");
		else if(c < 0x20)
		{
			char esc[8];
			sprintf(esc, "\\u%04x", c);
			jbputs(b, esc);
		}
		else
			jbputc(b, c);
	}
	jbputc(b, '"');
}

static void jbval(struct JBuf *b, const struct JVal *v)
{
	size_t i;

	if(v == NULL)
	{
		jbputs(b, "null");
		return;
	}
	switch(v->type)
	{
	case JNULL:
		jbputs(b, "null");
		break;
	case JBOOL:
		jbputs(b, v->boolean ? "true" : "false");
		break;
	case JNUM:
		if(!isfinite(v->number))
			jbputs(b, "null");
		else if(v->number >= -9e15 && v->number <= 9e15 &&
			v->number == floor(v->number))
		{
			char buf[32];
			sprintf(buf, "%lld", (long long)v->number);
			jbputs(b, buf);
		}
		else
		{
			char buf[40];
			sprintf(buf, "%.17g", v->number);
			jbputs(b, buf);
		}
		break;
	case JSTR:
		jbstr(b, v->string);
		break;
	case JARR:
		jbputc(b, '[');
		for(i = 0; i < v->count; i++)
		{
			if(i) jbputc(b, ',');
			jbval(b, v->vals[i]);
		}
		jbputc(b, ']');
		break;
	case JOBJ:
		jbputc(b, '{');
		for(i = 0; i < v->count; i++)
		{
			if(i) jbputc(b, ',');
			jbstr(b, v->keys[i]);
			jbputc(b, ':');
			jbval(b, v->vals[i]);
		}
		jbputc(b, '}');
		break;
	}
}

char *jdumps(const struct JVal *v)
{
	struct JBuf b;

	b.cap = 256;
	b.n = 0;
	b.s = malloc(b.cap);
	jbval(&b, v);
	jbputc(&b, '\0');
	return b.s;
}

void jprint(const struct JVal *v, FILE *fp)
{
	char *s = jdumps(v);

	fputs(s, fp);
	free(s);
}

/* --- parser --- */

struct P {
	const char *s;
};

static void pskip(struct P *p)
{
	while(*p->s == ' ' || *p->s == '\t' || *p->s == '\n' || *p->s == '\r')
		p->s++;
}

static int phex(int c)
{
	if(c >= '0' && c <= '9') return c - '0';
	if(c >= 'a' && c <= 'f') return c - 'a' + 10;
	if(c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

static char *pstring(struct P *p)
{
	char *buf = malloc(strlen(p->s) + 1);
	char *w = buf;

	p->s++;
	while(*p->s && *p->s != '"')
	{
		char c = *p->s++;
		if(c == '\\' && *p->s)
		{
			char esc = *p->s++;
			switch(esc)
			{
			case '"': *w++ = '"'; break;
			case '\\': *w++ = '\\'; break;
			case '/': *w++ = '/'; break;
			case 'b': *w++ = '\b'; break;
			case 'f': *w++ = '\f'; break;
			case 'n': *w++ = '\n'; break;
			case 'r': *w++ = '\r'; break;
			case 't': *w++ = '\t'; break;
			case 'u':
			{
				unsigned cp = 0;
				int i, h;
				for(i = 0; i < 4 && (h = phex(*p->s)) >= 0; i++)
				{
					cp = cp * 16 + h;
					p->s++;
				}
				if(cp < 0x80)
					*w++ = cp;
				else if(cp < 0x800)
				{
					*w++ = 0xC0 | (cp >> 6);
					*w++ = 0x80 | (cp & 63);
				}
				else
				{
					*w++ = 0xE0 | (cp >> 12);
					*w++ = 0x80 | ((cp >> 6) & 63);
					*w++ = 0x80 | (cp & 63);
				}
				break;
			}
			default: *w++ = '?'; break;
			}
		}
		else
			*w++ = c;
	}
	if(*p->s == '"')
		p->s++;
	*w = '\0';
	return buf;
}

static const char *pval(struct P *p, int depth, struct JVal **out);

static const char *pobj(struct P *p, int depth, struct JVal **out)
{
	struct JVal *o = jobj();

	p->s++;
	pskip(p);
	if(*p->s == '}')
	{
		p->s++;
		*out = o;
		return NULL;
	}
	for(;;)
	{
		char *k;
		struct JVal *v;
		const char *e;

		pskip(p);
		if(*p->s != '"')
			{ jfree(o); return "expected key"; }
		k = pstring(p);
		pskip(p);
		if(*p->s != ':')
			{ free(k); jfree(o); return "expected ':'"; }
		p->s++;
		e = pval(p, depth + 1, &v);
		if(e != NULL)
			{ free(k); jfree(o); return e; }
		jset(o, k, v);
		free(k);
		pskip(p);
		if(*p->s == ',') { p->s++; continue; }
		if(*p->s == '}') { p->s++; *out = o; return NULL; }
		jfree(o);
		return "expected ',' or '}'";
	}
}

static const char *parr(struct P *p, int depth, struct JVal **out)
{
	struct JVal *a = jarr();

	p->s++;
	pskip(p);
	if(*p->s == ']')
	{
		p->s++;
		*out = a;
		return NULL;
	}
	for(;;)
	{
		struct JVal *v;
		const char *e = pval(p, depth + 1, &v);

		if(e != NULL)
			{ jfree(a); return e; }
		jpush(a, v);
		pskip(p);
		if(*p->s == ',') { p->s++; continue; }
		if(*p->s == ']') { p->s++; *out = a; return NULL; }
		jfree(a);
		return "expected ',' or ']'";
	}
}

static const char *pval(struct P *p, int depth, struct JVal **out)
{
	pskip(p);
	*out = NULL;
	if(depth > JMAXDEPTH)
		return "nesting too deep";
	if(*p->s == '{')
		return pobj(p, depth, out);
	if(*p->s == '[')
		return parr(p, depth, out);
	if(*p->s == '"')
	{
		char *s = pstring(p);
		*out = jstr(s);
		free(s);
		return NULL;
	}
	if(strncmp(p->s, "true", 4) == 0)
		{ p->s += 4; *out = jbool(1); return NULL; }
	if(strncmp(p->s, "false", 5) == 0)
		{ p->s += 5; *out = jbool(0); return NULL; }
	if(strncmp(p->s, "null", 4) == 0)
		{ p->s += 4; *out = jnull(); return NULL; }
	if(*p->s == '-' || (*p->s >= '0' && *p->s <= '9'))
	{
		char *end;
		double d = strtod(p->s, &end);

		if(end == p->s)
			return "bad number";
		p->s = end;
		*out = jnum(d);
		return NULL;
	}
	return "unexpected character";
}

const char *jparse(const char *src, struct JVal **out)
{
	struct P p;
	const char *e;

	*out = NULL;
	p.s = src;
	e = pval(&p, 0, out);
	if(e != NULL)
	{
		jfree(*out);
		*out = NULL;
		return e;
	}
	pskip(&p);
	if(*p.s != '\0')
	{
		jfree(*out);
		*out = NULL;
		return "trailing characters";
	}
	return NULL;
}
