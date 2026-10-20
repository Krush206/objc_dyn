#ifndef JSON_H
#define JSON_H 1
#import <stdio.h>

enum JType {
	JNULL, JBOOL, JNUM, JSTR, JARR, JOBJ
};

struct JVal {
	enum JType type;
	int boolean;
	double number;
	char *string;
	char **keys;
	struct JVal **vals;
	size_t count;
	size_t cap;
};

struct JVal *jnull(void);
struct JVal *jbool(int b);
struct JVal *jnum(double n);
struct JVal *jstr(const char *s);
struct JVal *jarr(void);
struct JVal *jobj(void);
void jpush(struct JVal *arr, struct JVal *v);
void jset(struct JVal *obj, const char *key, struct JVal *v);
struct JVal *jget(struct JVal *obj, const char *key);
struct JVal *jclone(const struct JVal *v);
const char *jparse(const char *src, struct JVal **out);
char *jdumps(const struct JVal *v);
void jprint(const struct JVal *v, FILE *fp);
void jfree(struct JVal *v);
#endif /* !JSON_H */
