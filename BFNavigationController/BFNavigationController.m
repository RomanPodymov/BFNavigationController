//
//  BFNavigationController.m
//
//  Created by Heiko Dreyer on 04/26/12.
//  Copyright (c) 2012 boxedfolder.com. All rights reserved.
//

#import "BFNavigationController.h"
#import "BFViewController.h"
#import "NSView+BFUtilities.h"
#import "NSViewController+BFNavigationController.h"

static const CGFloat kPushPopAnimationDuration = 0.2;

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface BFNavigationController ()

- (void)_setViewControllers:(NSArray *)controllers animated:(BOOL)animated;
- (void)_navigateFromViewController:(NSViewController *)lastController
                   toViewController:(NSViewController *)newController
                           animated:(BOOL)animated
                               push:(BOOL)push;

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation BFNavigationController {
    NSMutableArray<NSViewController*> *_viewControllers;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Init Methods

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithFrame:NSZeroRect rootViewController:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithFrame:(NSRect)aFrame rootViewController:(NSViewController *)viewController {
    if (self = [super initWithNibName: nil bundle: nil]) {
        // Create view
        self.view = [[NSView alloc] initWithFrame: aFrame];
        self.view.autoresizingMask = NSViewMinXMargin |
                                     NSViewMaxXMargin |
                                     NSViewMinYMargin |
                                     NSViewMaxYMargin |
                                     NSViewWidthSizable |
                                     NSViewHeightSizable;
        
        // Add dummy controller if none provided
        if (!viewController) {
            viewController = [[NSViewController alloc] init];
            viewController.view = [[NSView alloc] initWithFrame:aFrame];
        }
        
        _viewControllers = [NSMutableArray array];
        [_viewControllers addObject: viewController];
        
        if ([viewController respondsToSelector:@selector(setNavigationController:)]) {
            [viewController performSelector:@selector(setNavigationController:) withObject:self];
        }

        viewController.view.autoresizingMask = self.view.autoresizingMask;
        viewController.view.frame = self.view.bounds;
        [self.view addSubview:viewController.view];
        
        // Initial controller will appear on startup
        if([viewController respondsToSelector:@selector(viewWillAppear:)]) {
            [(id<BFViewController>)viewController viewWillAppear:NO];
        }

    }
    
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Accessors

- (NSViewController *)topViewController {
    return [_viewControllers lastObject];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSViewController *)visibleViewController {
    return [_viewControllers lastObject];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<NSViewController*> *)viewControllers {
    return [NSArray arrayWithArray: _viewControllers];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setViewControllers:(NSArray<NSViewController*> *)viewControllers {
    [self _setViewControllers:viewControllers animated:NO];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setViewControllers:(NSArray<NSViewController*> *)viewControllers animated:(BOOL)animated {
    [self _setViewControllers:viewControllers animated:animated];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Helpers & Navigation

- (void)_setViewControllers:(NSArray<NSViewController*> *)controllers animated:(BOOL)animated {
    NSViewController *visibleController = self.visibleViewController;
    NSViewController *newTopmostController = [controllers lastObject];
    
    // Decide if pop or push - If visible controller already in new stack, but is not topmost, use pop otherwise push
    BOOL push = !([_viewControllers containsObject:newTopmostController] &&
                  [_viewControllers indexOfObject:newTopmostController] < [_viewControllers count] - 1);
    
    _viewControllers = [controllers mutableCopy];

    for (NSViewController* viewController in _viewControllers) {
        if ([viewController respondsToSelector:@selector(setNavigationController:)]) {
            [viewController performSelector:@selector(setNavigationController:) withObject:self];
        }
    }

    // Navigate
    [self _navigateFromViewController:visibleController toViewController:newTopmostController animated:animated push:push];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_navigateFromViewController:(NSViewController *)lastController
                   toViewController:(NSViewController *)newController
                           animated:(BOOL)animated
                               push:(BOOL)push
{ 
    newController.view.autoresizingMask = self.view.autoresizingMask;
    
    // Call delegate
    if (_delegate && [_delegate respondsToSelector:@selector(navigationController:willShowViewController:animated:)]) {
        [_delegate navigationController:self willShowViewController:newController animated:animated];
    }
    
    // New controller will appear
    if ([newController respondsToSelector:@selector(viewWillAppear:)]) {
        [(id<BFViewController>)newController viewWillAppear:animated];
    }
    
    // Last controller will disappear
    if ([lastController respondsToSelector:@selector(viewWillDisappear:)]) {
        [(id<BFViewController>)lastController viewWillDisappear:animated];
    }
    
    NSRect newControllerStartFrame = self.view.bounds;
    NSRect lastControllerEndFrame = self.view.bounds;

    // Completion inline Block
    void(^navigationCompleted)(BOOL) = ^(BOOL animated) {
        // Call delegate
        if (_delegate && [_delegate respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) {
            [_delegate navigationController:self didShowViewController:newController animated:animated];
        }
        
        // New controller did appear
        if ([newController respondsToSelector: @selector(viewDidAppear:)]) {
            [(id<BFViewController>)newController viewDidAppear:animated];
        }
            
        // Last controller did disappear
        if ([lastController respondsToSelector: @selector(viewDidDisappear:)]) {
            [(id<BFViewController>)lastController viewDidDisappear:animated];
        }
    };
    
    if (animated) {
        newControllerStartFrame.origin.x = push ? newControllerStartFrame.size.width : -newControllerStartFrame.size.width;
        lastControllerEndFrame.origin.x = push ? -lastControllerEndFrame.size.width : lastControllerEndFrame.size.width;
        
        // Assign start frame
        newController.view.frame = newControllerStartFrame;
        
        // Remove last controller from superview
        [lastController.view removeFromSuperview];
        
        // We use NSImageViews to cache animating views. Of course we could animate using Core Animation layers - Do it if you like that.
        NSImageView *lastControllerImageView = [[NSImageView alloc] initWithFrame:self.view.bounds];
        NSImageView *newControllerImageView = [[NSImageView alloc] initWithFrame:newControllerStartFrame];
        
        [lastControllerImageView setImage:[lastController.view flattenWithSubviews]];
        [newControllerImageView setImage:[newController.view flattenWithSubviews]];
        
        [self.view addSubview: lastControllerImageView];
        [self.view addSubview: newControllerImageView];
        
        // Animation 'block' - Using default timing function
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:kPushPopAnimationDuration];
        [[lastControllerImageView animator] setFrame:lastControllerEndFrame];
        [[newControllerImageView animator] setFrame:self.view.bounds];
        [NSAnimationContext endGrouping];
        
        // Could have just called setCompletionHandler: on animation context if it was Lion only.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, kPushPopAnimationDuration * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            [lastControllerImageView removeFromSuperview];
            [self.view replaceSubview:newControllerImageView with:newController.view];
            newController.view.frame = self.view.bounds;
            navigationCompleted(animated);
        });
    } else {
        newController.view.frame = newControllerStartFrame;
        [self.view addSubview:newController.view];
        [lastController.view removeFromSuperview];
        navigationCompleted(animated);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Push / Pop Controllers

- (void)pushViewController:(NSViewController *)viewController animated:(BOOL)animated {
    NSViewController *visibleController = self.visibleViewController;
    [_viewControllers addObject:viewController];
    
    if([viewController respondsToSelector:@selector(setNavigationController:)]) {
        [viewController performSelector:@selector(setNavigationController:) withObject:self];
    }
    
    // Navigate
    [self _navigateFromViewController:visibleController toViewController:[_viewControllers lastObject] animated:animated push:YES];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSViewController *)popViewControllerAnimated:(BOOL)animated {
    // Don't pop last controller
    if ([_viewControllers count] == 1) {
        return nil;
    }
    
    NSViewController *viewController = [_viewControllers lastObject];
    [_viewControllers removeLastObject];
    
    // Navigate
    [self _navigateFromViewController:viewController toViewController:[_viewControllers lastObject] animated:animated push:NO];
    
    if ([viewController respondsToSelector:@selector(setNavigationController:)]) {
        [viewController performSelector:@selector(setNavigationController:) withObject:nil];
    }

    // Return popping controller
    return viewController;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated {
    // Don't pop last controller
    if ([_viewControllers count] == 1) {
        return [NSArray array];
    }
    
    NSViewController *rootController = [_viewControllers objectAtIndex:0];
    [_viewControllers removeObject:rootController];
    
    NSArray *dispControllers = [NSArray arrayWithArray:_viewControllers];
    _viewControllers = [NSMutableArray arrayWithObject:rootController];
    
    // Navigate
    [self _navigateFromViewController: [dispControllers lastObject] toViewController:rootController animated:animated push:NO];

    for (NSViewController * aViewController in dispControllers) {
        if ([aViewController respondsToSelector:@selector(setNavigationController:)]) {
            [aViewController performSelector:@selector(setNavigationController:) withObject:nil];
        }
    }

    // Return popping controller stack
    return [[dispControllers reverseObjectEnumerator] allObjects];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)popToViewController:(NSViewController *)viewController animated:(BOOL)animated {
    NSViewController *visibleController = self.visibleViewController;
    
    // Don't pop last controller
    if (![_viewControllers containsObject: viewController] || visibleController == viewController) {
        return [NSArray array];
    }
    
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    NSUInteger length = [_viewControllers count] - (index + 1);
    NSRange range = NSMakeRange(index + 1, length);
    NSArray *dispControllers = [_viewControllers subarrayWithRange:range];
    [_viewControllers removeObjectsInArray:dispControllers];
    
    // Navigate
    [self _navigateFromViewController:visibleController toViewController:viewController animated:animated push:NO];

    for (NSViewController * aViewController in dispControllers) {
        if([aViewController respondsToSelector:@selector(setNavigationController:)]) {
            [aViewController performSelector:@selector(setNavigationController:) withObject:nil];
        }
    }

    // Return popping controller stack
    return [[dispControllers reverseObjectEnumerator] allObjects];
}

@end
