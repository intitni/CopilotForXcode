#import <Foundation/Foundation.h>

@interface ObjcExceptionHandler : NSObject

+ (BOOL)catchException:(void (^)(void))tryBlock
                 error:(__autoreleasing NSError **)error;

@end

