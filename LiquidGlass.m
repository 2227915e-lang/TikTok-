// LiquidGlass.m
// Target: TikTok iOS (gtok_2_5_3.ipa)
// Language: ObjC | Runtime: UIKit | Build: clang arm64
// Effect: iOS 26-style liquid glass on tab bar, nav bar, sheets, comment view

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─── Liquid Glass Layer ───────────────────────────────────────────────────────

@interface LGGlassLayer : CALayer
@end

@implementation LGGlassLayer

- (void)layoutSublayers {
    [super layoutSublayers];
    [self applyLiquidGlass];
}

- (void)applyLiquidGlass {
    // remove previous glass sublayers tagged with name
    NSArray *sublayersCopy = [self.sublayers copy];
    for (CALayer *l in sublayersCopy) {
        if ([l.name isEqualToString:@"lg_specular"] ||
            [l.name isEqualToString:@"lg_border"] ||
            [l.name isEqualToString:@"lg_refract"]) {
            [l removeFromSuperlayer];
        }
    }

    CGRect bounds = self.bounds;

    // refraction tint — very subtle cool tint like glass
    CALayer *refract = [CALayer layer];
    refract.name = @"lg_refract";
    refract.frame = bounds;
    refract.cornerRadius = self.cornerRadius;
    refract.masksToBounds = YES;
    refract.backgroundColor = [UIColor colorWithRed:0.85 green:0.92 blue:1.0 alpha:0.06].CGColor;
    [self insertSublayer:refract atIndex:0];

    // specular highlight — top edge glow like light hitting glass
    CAGradientLayer *specular = [CAGradientLayer layer];
    specular.name = @"lg_specular";
    specular.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height * 0.38);
    specular.cornerRadius = self.cornerRadius;
    specular.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.22].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    specular.startPoint = CGPointMake(0.5, 0.0);
    specular.endPoint   = CGPointMake(0.5, 1.0);
    [self addSublayer:specular];

    // luminous border
    CALayer *border = [CALayer layer];
    border.name = @"lg_border";
    border.frame = bounds;
    border.cornerRadius = self.cornerRadius;
    border.masksToBounds = NO;
    border.borderWidth = 0.5;
    border.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    [self addSublayer:border];
}

@end

// ─── Glass View Builder ───────────────────────────────────────────────────────

static UIVisualEffectView *LGMakeBlurView(CGRect frame, CGFloat cornerRadius) {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:blur];
    ev.frame = frame;
    ev.layer.cornerRadius = cornerRadius;
    ev.layer.masksToBounds = YES;
    ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    ev.tag = 0x4C47; // 'LG' tag to avoid double-apply
    return ev;
}

static void LGApplyToView(UIView *view, CGFloat cornerRadius) {
    if (!view || view.bounds.size.width == 0) return;

    // check already applied
    for (UIView *sub in view.subviews) {
        if (sub.tag == 0x4C47) return;
    }

    // glass blur
    UIVisualEffectView *ev = LGMakeBlurView(view.bounds, cornerRadius);
    [view insertSubview:ev atIndex:0];

    // glass layer on top of blur
    LGGlassLayer *glassLayer = [LGGlassLayer layer];
    glassLayer.frame = view.bounds;
    glassLayer.cornerRadius = cornerRadius;
    glassLayer.masksToBounds = NO;
    [glassLayer applyLiquidGlass];
    [view.layer addSublayer:glassLayer];

    // keep existing background translucent
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.01];
}

// ─── Hooks ────────────────────────────────────────────────────────────────────

// UITabBar
static void (*orig_tabBar_layoutSubviews)(UITabBar *, SEL);
static void hook_tabBar_layoutSubviews(UITabBar *self, SEL _cmd) {
    orig_tabBar_layoutSubviews(self, _cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        LGApplyToView(self, 22.0);
    });
}

// UINavigationBar
static void (*orig_navBar_layoutSubviews)(UINavigationBar *, SEL);
static void hook_navBar_layoutSubviews(UINavigationBar *self, SEL _cmd) {
    orig_navBar_layoutSubviews(self, _cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        LGApplyToView(self, 0.0);
    });
}

// UIToolbar (used by TikTok comment/share sheets)
static void (*orig_toolbar_layoutSubviews)(UIToolbar *, SEL);
static void hook_toolbar_layoutSubviews(UIToolbar *self, SEL _cmd) {
    orig_toolbar_layoutSubviews(self, _cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        LGApplyToView(self, 16.0);
    });
}

// UISearchBar
static void (*orig_searchBar_layoutSubviews)(UISearchBar *, SEL);
static void hook_searchBar_layoutSubviews(UISearchBar *self, SEL _cmd) {
    orig_searchBar_layoutSubviews(self, _cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        LGApplyToView(self, 12.0);
    });
}

// ─── Swizzle Helper ──────────────────────────────────────────────────────────

static void swizzle(Class cls, SEL orig, IMP hook, IMP *store) {
    Method m = class_getInstanceMethod(cls, orig);
    if (!m) return;
    *store = method_getImplementation(m);
    method_setImplementation(m, hook);
}

// ─── Constructor ─────────────────────────────────────────────────────────────

__attribute__((constructor))
static void LiquidGlassInit(void) {
    @autoreleasepool {
        // slight delay so TikTok finishes its own UIKit setup
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{

            SEL layoutSub = @selector(layoutSubviews);

            swizzle([UITabBar class],        layoutSub,
                    (IMP)hook_tabBar_layoutSubviews,    (IMP *)&orig_tabBar_layoutSubviews);

            swizzle([UINavigationBar class], layoutSub,
                    (IMP)hook_navBar_layoutSubviews,    (IMP *)&orig_navBar_layoutSubviews);

            swizzle([UIToolbar class],       layoutSub,
                    (IMP)hook_toolbar_layoutSubviews,   (IMP *)&orig_toolbar_layoutSubviews);

            swizzle([UISearchBar class],     layoutSub,
                    (IMP)hook_searchBar_layoutSubviews, (IMP *)&orig_searchBar_layoutSubviews);

            NSLog(@"[LiquidGlass] hooks installed");
        });
    }
}
