// flutter/flutter#183900 — iOS 26 + motor implícito + ProMotion:
// -[VSyncClient initWithTaskRunner:callback:] com task runner null em viewDidLoad.
// Adiar a criação do cliente para o próximo ciclo da fila principal (onde o engine
// já expõe o platformTaskRunner). Remover este ficheiro quando o Flutter corrigir o engine.

#if __has_include(<Flutter/Flutter.h>)
#import <Flutter/Flutter.h>
#elif __has_include("Flutter/Flutter.h")
#import "Flutter/Flutter.h"
#else
#import <UIKit/UIKit.h>
@interface FlutterViewController : UIViewController
@end
#endif
#import <objc/runtime.h>

// Só declaramos o método que **esta** categoria implementa. O seletor original existe no
// engine Flutter (sem header público): usar sel_registerName evita "Undeclared selector"
// e "Method definition for … not found" (o Clang exige @implementation para tudo no @interface).
@interface FlutterViewController (FlutterTouchRateCrashFix)
- (void)fl_trcf_swizzled_createTouchRateCorrectionVSyncClientIfNeeded;
@end

@implementation FlutterViewController (FlutterTouchRateCrashFix)

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class cls = [FlutterViewController class];
    SEL originalSel = sel_registerName("createTouchRateCorrectionVSyncClientIfNeeded");
    SEL swizzledSel = @selector(fl_trcf_swizzled_createTouchRateCorrectionVSyncClientIfNeeded);
    Method originalMethod = class_getInstanceMethod(cls, originalSel);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSel);
    if (originalMethod == NULL || swizzledMethod == NULL) {
      return;
    }
    method_exchangeImplementations(originalMethod, swizzledMethod);
  });
}

- (void)fl_trcf_swizzled_createTouchRateCorrectionVSyncClientIfNeeded {
  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    __strong typeof(self) strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }
    [strongSelf fl_trcf_swizzled_createTouchRateCorrectionVSyncClientIfNeeded];
  });
}

@end
