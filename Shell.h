@interface Shell: NSObject
- (id) exec: (id) argv;
- (id) parse: (id) str;
+ (int) entry;
@end
