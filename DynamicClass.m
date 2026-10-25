#import <stdio.h>
#import <objc/Object.h>

@implementation DynamicClass : Object
- (id) init { return self; }
- (void) greet { printf("Hello from DynamicClass\n"); }
- (id) greetAndReturn { printf("Hello from DynamicClass\n"); return self; }
@end
