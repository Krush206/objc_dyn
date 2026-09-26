#import "objc_dyn.h"

@implementation Shell (Process)
- (void) wait: (int) i
{
	register int p, e;
	int s;
	const char *message;

	for(;;) {
		p = wait(&s);
		if(p == -1)
			break;
		if(WIFEXITED(s)) {
			errval |= WEXITSTATUS(s);
			if(WEXITSTATUS(s) && stoperr)
				[self error: "" code: WEXITSTATUS(s)];
			continue;
		}
		if(!WIFSIGNALED(s))
			continue;
		e = WTERMSIG(s);
		if(p != i) {
			[self printNumber: p];
			[self printString: ": "];
		}
		message = strsignal(e);
		if(message)
			[self printString: message];
		else {
			[self printString: "Signal "];
			[self printNumber: e];
		}
		if(WCOREDUMP(s))
			[self printString: " -- Core dumped"];
		[self error: "" code: e];
		errval |= e;
	}
}
@end
