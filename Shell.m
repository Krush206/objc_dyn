#import <Foundation/Foundation.h>
#import <unistd.h>
#import <sys/wait.h>
#import "Shell.h"
#import "objc_dyn.h"

@implementation Shell
- (id) readInput
{
  id str;
  int c;

  str = [NSString string];
  while((c = getchar()) != '\n')
    str = [NSString stringWithFormat: @"%@%c", str, c];

  return str;
}

- (id) parse: (id) str
{
  id cmd;
  id argv;
  int i;
  int len;

  cmd = [NSString string];
  argv = [NSMutableArray array];
  len = [str length];
  for(i = 0; i < len; i++)
    switch([str characterAtIndex: i])
    {
    case ' ':
      continue;
    case ':':
      if(i + 1 < len && [str characterAtIndex: i + 1] == '=')
      {
        id ap;

	ap = [self parse: [str substringFromIndex: i + 2]];
	[argv addObject: ap];

	return argv;
      }
    default:
      while(i < len && [str characterAtIndex: i] != ' ')
        cmd = [NSString stringWithFormat: @"%@%c",
                                          cmd,
                                          [str characterAtIndex: i++]];
      [argv addObject: cmd];
      cmd = [NSString string];
    }

  return argv;
}

- (id) exec: (id) argv
{
  id obj;
  id rec;
  Class cls;
  SEL msg;

  rec = [argv objectAtIndex: 0];
  msg = NSSelectorFromString([argv objectAtIndex: 1]);
  cls = getClass([rec cString]);
  if(cls != Nil)
  {
    [cls performSelector: msg];

    return nil;
  }
  obj = getObject([rec cString]);
  if(obj != nil)
  {
    [obj performSelector: msg];

    return nil;
  }
  NSLog(@"Invalid class or object.");

  return nil;
}

+ (int) entry
{
  id sh;
  id cmd;
  id argv;

  loadClass("NSObject");
  sh = [self new];
  while(YES)
  {
    printf("> ");
    cmd = [sh readInput];

    if([cmd length] == 0)
      continue;

    argv = [sh parse: cmd];

    if([argv count] == 0)
      continue;

    [sh exec: argv];
  }

  return 0;
}
@end

int main(void)
{
  @autoreleasepool
  {
    return [Shell entry];
  }
}
