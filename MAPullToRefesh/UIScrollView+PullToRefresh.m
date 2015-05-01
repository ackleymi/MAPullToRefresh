//
//  UIScrollView+PullToRefresh.m
//  TwitterRefresh
//
//  Created by Mike Ackley on 11/3/14.
//  Copyright (c) 2014 Michael Ackley. All rights reserved.
//


#define fequal(a,b) (fabs((a) - (b)) < FLT_EPSILON)
#define fequalzero(a) (fabs(a) < FLT_EPSILON)
#define PullToRefreshViewHeight 50

#import "UIScrollView+PullToRefresh.h"


@interface PullToRefreshView ()

@property (nonatomic, copy) void (^pullToRefreshActionHandler)(void);
@property (nonatomic, strong) UIImageView *arrow;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) PullToRefreshState state;
@property (nonatomic, readwrite) PullToRefreshPosition position;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalTopInset;
@property (nonatomic, readwrite) CGFloat originalBottomInset;
@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property(nonatomic, assign) BOOL isObserving;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForLoading;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;
- (void)rotateArrow:(float)degrees hide:(BOOL)hide;

@end

#pragma mark - UIScrollView (PullToRefresh)
#import <objc/runtime.h>

static char UIScrollViewPullToRefreshView;

@implementation UIScrollView (PullToRefresh)

@dynamic pullToRefreshView;

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler position:(PullToRefreshPosition)position {
    
    if(!self.pullToRefreshView) {
        CGFloat yOrigin;
        switch (position) {
            case PullToRefreshPositionTop:
                yOrigin = -PullToRefreshViewHeight;
                break;
            default:
                return;
        }
        PullToRefreshView *view = [[PullToRefreshView alloc] initWithFrame:CGRectMake(0, yOrigin, UIScreen.mainScreen.bounds.size.width, PullToRefreshViewHeight)];
        view.pullToRefreshActionHandler = actionHandler;
        view.scrollView = self;
        view.arrow = [[UIImageView alloc]initWithFrame:CGRectMake((UIScreen.mainScreen.bounds.size.width/2)-10,(PullToRefreshViewHeight/2)-10,20,20)];
        //self.frame.size.width
        view.arrow.image = [UIImage imageNamed:@"pull-arrow.png"];
        view.activityIndicatorView.center = view.arrow.center;
        [view addSubview:view.arrow];
        
        [self addSubview:view];
        
        view.originalTopInset = 0;
        view.originalBottomInset = 0;
        view.position = position;
        self.pullToRefreshView = view;
        
        self.showsPullToRefresh = YES;
    }
    
}

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler {
    [self addPullToRefreshWithActionHandler:actionHandler position:PullToRefreshPositionTop];
}

- (void)triggerPullToRefresh {
    self.pullToRefreshView.state = PullToRefreshStateTriggered;
    [self.pullToRefreshView startAnimating];
}

- (void)setPullToRefreshView:(PullToRefreshView *)pullToRefreshView {
    [self willChangeValueForKey:@"PullToRefreshView"];
    objc_setAssociatedObject(self, &UIScrollViewPullToRefreshView,
                             pullToRefreshView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"PullToRefreshView"];
}

- (PullToRefreshView *)pullToRefreshView {
    return objc_getAssociatedObject(self, &UIScrollViewPullToRefreshView);
}

- (void)setShowsPullToRefresh:(BOOL)showsPullToRefresh {
    self.pullToRefreshView.hidden = !showsPullToRefresh;
    
    
    if(!showsPullToRefresh) {
        if (self.pullToRefreshView.isObserving) {
            [self removeObserver:self.pullToRefreshView forKeyPath:@"contentOffset"];
            [self removeObserver:self.pullToRefreshView forKeyPath:@"contentSize"];
            [self removeObserver:self.pullToRefreshView forKeyPath:@"frame"];
            [self.pullToRefreshView resetScrollViewContentInset];
            self.pullToRefreshView.isObserving = NO;
        }
    }
    else {
        if (!self.pullToRefreshView.isObserving) {
            [self addObserver:self.pullToRefreshView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToRefreshView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToRefreshView forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
            self.pullToRefreshView.isObserving = YES;
            
            CGFloat yOrigin = 0;
            switch (self.pullToRefreshView.position) {
                case PullToRefreshPositionTop:
                    yOrigin = -PullToRefreshViewHeight;
                    break;
            }
            
            self.pullToRefreshView.frame = CGRectMake(0, yOrigin, self.bounds.size.width, PullToRefreshViewHeight);
        }
    }
}

- (BOOL)showsPullToRefresh {
    return !self.pullToRefreshView.hidden;
}

@end


#pragma mark - PullToRefresh
@implementation PullToRefreshView

// public properties
@synthesize pullToRefreshActionHandler;

@synthesize state = _state;
@synthesize activityIndicatorView = _activityIndicatorView;


- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        // default styling values
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = PullToRefreshStateStopped;
        self.wasTriggeredByUser = YES;
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        //use self.superview, not self.scrollView. Why self.scrollView == nil here?
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (scrollView.showsPullToRefresh) {
            if (self.isObserving) {
                //If enter this branch, it is the moment just before "PullToRefreshView's dealloc", so remove observer here
                [scrollView removeObserver:self forKeyPath:@"contentOffset"];
                [scrollView removeObserver:self forKeyPath:@"contentSize"];
                [scrollView removeObserver:self forKeyPath:@"frame"];
                self.isObserving = NO;
            }
        }
    }
}

- (void)layoutSubviews {
    
    switch (self.state) {
        case PullToRefreshStateAll:
        case PullToRefreshStateStopped:
            self.arrow.alpha = 1;
            [self.activityIndicatorView stopAnimating];
            self.arrow.hidden = NO;
            switch (self.position) {
                case PullToRefreshPositionTop:
                    [self rotateArrow:0 hide:NO];
                    break;
            }
            break;
            
        case PullToRefreshStateTriggered:
            switch (self.position) {
                case PullToRefreshPositionTop:
                    [self rotateArrow:(float)M_PI hide:NO];
                    break;
            }
            break;
            
        case PullToRefreshStateLoading:
            [self.activityIndicatorView startAnimating];
            self.arrow.hidden = YES;
            switch (self.position) {
                case PullToRefreshPositionTop:
                    [self rotateArrow:0 hide:YES];
                    break;
            }
            break;
    }
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.position) {
        case PullToRefreshPositionTop:
            currentInsets.top = 64;
            break;
    }
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForLoading {
    CGFloat offset = MAX(-self.scrollView.contentOffset.y +64,64);
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.position) {
        case PullToRefreshPositionTop:
            currentInsets.top = offset; //MIN(offset, 64 + self.bounds.size.height);
            break;
    }
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset {
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                     }
                     completion:NULL];
}

#pragma mark - Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"contentOffset"])
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    else if([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        
        CGFloat yOrigin;
        switch (self.position) {
            case PullToRefreshPositionTop:
                yOrigin = -PullToRefreshViewHeight;
                break;
        }
        self.frame = CGRectMake(0, yOrigin, self.bounds.size.width, PullToRefreshViewHeight);
    }
    else if([keyPath isEqualToString:@"frame"])
        [self layoutSubviews];
    
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    
    if(self.state != PullToRefreshStateLoading) {
        
        CGFloat scrollOffsetThreshold = 0;
        switch (self.position) {
            case PullToRefreshPositionTop:
                scrollOffsetThreshold = self.frame.origin.y - 64.0f;
                break;
        }
        
        if(!self.scrollView.isDragging && self.state == PullToRefreshStateTriggered)
            self.state = PullToRefreshStateLoading;
        else if(contentOffset.y < scrollOffsetThreshold && self.scrollView.isDragging && self.state == PullToRefreshStateStopped && self.position == PullToRefreshPositionTop)
            self.state = PullToRefreshStateTriggered;
        else if(contentOffset.y >= scrollOffsetThreshold && self.state != PullToRefreshStateStopped && self.position == PullToRefreshPositionTop)
            self.state = PullToRefreshStateStopped;
    } else {
        
        CGFloat offset;
        UIEdgeInsets contentInset;
        switch (self.position) {
            case PullToRefreshPositionTop:
                offset = MAX(-self.scrollView.contentOffset.y +64, 64.0f);
                offset = MIN(offset, 64 + self.frame.size.height);
                contentInset = self.scrollView.contentInset;
                self.scrollView.contentInset = UIEdgeInsetsMake(offset, contentInset.left, contentInset.bottom, contentInset.right);
                break;
        }
    }
}

#pragma mark - Getters

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

#pragma mark - Setters

#pragma mark -

- (void)triggerRefresh {
    [self.scrollView triggerPullToRefresh];
}

- (void)startAnimating{
    
    switch (self.position) {
        case PullToRefreshPositionTop:
            
            if(fequalzero(self.scrollView.contentOffset.y)) {
                [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.frame.size.height-64.0f) animated:YES];
                self.wasTriggeredByUser = NO;
            }
            else
                self.wasTriggeredByUser = YES;
            
            break;
    }
    
    self.state = PullToRefreshStateLoading;
}

- (void)stopAnimating {
    self.state = PullToRefreshStateStopped;
    switch (self.position) {
        case PullToRefreshPositionTop:
            if(!self.wasTriggeredByUser){
                [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, 64.0) animated:YES];
            }
            break;
    }
}

- (void)setState:(PullToRefreshState)newState {
    
    if(_state == newState)
        return;
    
    PullToRefreshState previousState = _state;
    _state = newState;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    switch (newState) {
        case PullToRefreshStateAll:
        case PullToRefreshStateStopped:
            [self resetScrollViewContentInset];
            break;
            
        case PullToRefreshStateTriggered:
            break;
            
        case PullToRefreshStateLoading:
            [self setScrollViewContentInsetForLoading];
            
            if(previousState == PullToRefreshStateTriggered && pullToRefreshActionHandler)
                pullToRefreshActionHandler();
            
            break;
    }
}

- (void)rotateArrow:(float)degrees hide:(BOOL)hide {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.arrow.layer.transform = CATransform3DMakeRotation(-degrees, 0, 0, 1);
    } completion:nil];
}

@end
