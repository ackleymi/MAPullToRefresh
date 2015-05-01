//
//  UIScrollView+PullToRefresh.h
//  TwitterRefresh
//
//  Created by Mike Ackley on 11/3/14.
//  Copyright (c) 2014 Michael Ackley. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AvailabilityMacros.h>

@class PullToRefreshView;

@interface UIScrollView (PullToRefresh)

typedef NS_ENUM(NSUInteger, PullToRefreshPosition) {
    PullToRefreshPositionTop = 0,
};

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler;
- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler position:(PullToRefreshPosition)position;
- (void)triggerPullToRefresh;

@property (nonatomic, strong) PullToRefreshView *pullToRefreshView;
@property (nonatomic, assign) BOOL showsPullToRefresh;

@end


typedef NS_ENUM(NSUInteger, PullToRefreshState) {
    PullToRefreshStateStopped = 0,
    PullToRefreshStateTriggered,
    PullToRefreshStateLoading,
    PullToRefreshStateAll = 10
};

@interface PullToRefreshView : UIView

@property (nonatomic, readonly) PullToRefreshState state;
@property (nonatomic, readonly) PullToRefreshPosition position;


- (void)startAnimating;
- (void)stopAnimating;


@end
