#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Reconstruction scaffold.
// Feature hooks remain disabled until their original targets,
// call order, and restoration behavior are verified.

%ctor {
    @autoreleasepool {
        NSLog(@"[NaiWa] reconstruction scaffold loaded");
    }
}
