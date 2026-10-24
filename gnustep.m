#import "objc_dyn.h"
#import "/usr/local/include/objc/Object.h"
#import "/usr/local/include/objc/objc-api.h"

void gnustep_register_classes(void)
{
  void *state = NULL;
  Class cls;
  /* Force linking of GNUstep Base */
  extern void *NSObject;
  (void) NSObject;
  extern unsigned long GNUstepConfig;
  (void) GNUstepConfig;
  /* Actually use a function from GNUstep Base */
  extern void GSAllocMethodList();
  __asm__ volatile ("" : : "r" (GSAllocMethodList));
  while ((cls = objc_next_class(&state)) != Nil) {
    const char *name = class_get_class_name(cls);
    if (name && (strncmp(name, "NS", 2) == 0 || strncmp(name, "GS", 2) == 0)) {
      // Register class name in shell's dynamic registry
      // The Shell::getClass implementation will pick up via objc_next_class
    }
  }
}
