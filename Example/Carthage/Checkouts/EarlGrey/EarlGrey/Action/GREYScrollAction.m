//
// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "Action/GREYScrollAction.h"

#import "Action/GREYPathGestureUtils.h"
#import "Action/GREYScrollActionError.h"
#import "Additions/CGGeometry+GREYAdditions.h"
#import "Additions/NSError+GREYAdditions.h"
#import "Additions/NSObject+GREYAdditions.h"
#import "Additions/NSString+GREYAdditions.h"
#import "Additions/UIScrollView+GREYAdditions.h"
#import "Assertion/GREYAssertionDefines.h"
#import "Event/GREYSyntheticEvents.h"
#import "Matcher/GREYAllOf.h"
#import "Matcher/GREYAnyOf.h"
#import "Matcher/GREYMatchers.h"
#import "Matcher/GREYNot.h"
#import "Synchronization/GREYAppStateTracker.h"
#import "Synchronization/GREYUIThreadExecutor.h"

/**
 *  Scroll views under web views take at least (depending on speed of execution environment) two
 *  touch points to accurately determine scroll resistance.
 */
static const NSInteger kMinTouchPointsToDetectScrollResistance = 2;

@implementation GREYScrollAction {
  /**
   *  The direction in which the content must be scrolled.
   */
  GREYDirection _direction;
  /**
   *  The amount of scroll (in the units of scrollView's coordinate system) to be applied.
   */
  CGFloat _amount;
}

- (instancetype)initWithDirection:(GREYDirection)direction amount:(CGFloat)amount {
  NSAssert(amount > 0, @"Scroll 'amount' must be positive and greater than zero.");
  NSString *name =
      [NSString stringWithFormat:@"Scroll %@ for %g", NSStringFromGREYDirection(direction), amount];

  self = [super initWithName:name
                 constraints:grey_allOf(grey_anyOf(grey_kindOfClass([UIScrollView class]),
                                                   grey_kindOfClass([UIWebView class]),
                                                   nil),
                                        grey_not(grey_systemAlertViewShown()),
                                        nil)];
  if (self) {
    _direction = direction;
    _amount = amount;
  }
  return self;
}

#pragma mark - GREYAction

- (BOOL)perform:(id)element error:(__strong NSError **)errorOrNil {
  if (![self satisfiesConstraintsForElement:element error:errorOrNil]) {
    return NO;
  }
  // To scroll UIWebView we must use the UIScrollView in its heirarchy and scroll it.
  if ([element isKindOfClass:[UIWebView class]]) {
    element = [(UIWebView *)element scrollView];
  }

  CGFloat amountRemaining = _amount;
  BOOL success = YES;
  while (amountRemaining > 0 && success) {
    @autoreleasepool {
      // To scroll the content view in a direction
      NSArray *touchPath =
          [GREYPathGestureUtils touchPathForGestureInView:element
                   withDirection:[GREYConstants reverseOfDirection:_direction]
                          amount:amountRemaining
              outRemainingAmount:&amountRemaining];
      if (!touchPath) {
        [NSError grey_logOrSetOutReferenceIfNonNil:errorOrNil
                                        withDomain:kGREYScrollErrorDomain
                                              code:kGREYScrollImpossible
                              andDescriptionFormat:@"Cannot scroll, ensure that the selected scroll"
                                                   @" view is wide enough to scroll."];
        return NO;
      }
      success = [GREYScrollAction grey_injectTouchPath:touchPath onScrollView:element];
    }
  }
  if (!success) {
    [NSError grey_logOrSetOutReferenceIfNonNil:errorOrNil
                                    withDomain:kGREYScrollErrorDomain
                                          code:kGREYScrollReachedContentEdge
                          andDescriptionFormat:@"Cannot scroll, the scrollview is already at"
                                               @" the edge."];
  }
  return success;
}

#pragma mark - Private

/**
 *  Injects the touch path into the given @c scrollView until the content edge could be reached.
 *
 *  @param touchPath  The touch path to be injected.
 *  @param scrollView The UIScrollView for the injection.
 *
 *  @return @c YES if entire touchPath was injected, else @c NO.
 */
+ (BOOL)grey_injectTouchPath:(NSArray *)touchPath onScrollView:(UIScrollView *)scrollView {
  // We need at least one touch point to inject a touch path.
  NSParameterAssert([touchPath count] >= 1);
  // In scrollviews that have their bounce turned off the horizontal and vertical velocities are not
  // reliable for detecting scroll resistance because they report non-zero velocities even when
  // content edge has been reached. So we are using contentOffsets as a workaround. But note that
  // this can be broken by AUT since it can modify the offsets during the scroll and if it resets
  // the offset to the same point for kMinTouchPointsToDetectScrollResistance times, this algorithm
  // interprets it as scroll resistance and stops scrolling.
  BOOL shouldDetectResistanceFromContentOffset = !scrollView.bounces;
  CGPoint prevOffset = scrollView.contentOffset;

  GREYSyntheticEvents *eventGenerator = [[GREYSyntheticEvents alloc] init];
  [eventGenerator beginTouchAtPoint:[touchPath[0] CGPointValue]
                   relativeToWindow:[scrollView window]
                  immediateDelivery:YES];
  BOOL hasResistance = NO;
  NSInteger consecutiveTouchPointsWithSameContentOffset = 0;
  for (NSUInteger touchPointIndex = 1; touchPointIndex < [touchPath count]; touchPointIndex++) {
    @autoreleasepool {
      CGPoint currentTouchPoint = [touchPath[touchPointIndex] CGPointValue];
      [eventGenerator continueTouchAtPoint:currentTouchPoint
                         immediateDelivery:YES
                                expendable:NO];
      BOOL detectedResistanceFromContentOffsets = NO;
      // Keep track of |consecutiveTouchPointsWithSameContentOffset| if we must detect resistance
      // from content offset.
      if (shouldDetectResistanceFromContentOffset) {
        if (CGPointEqualToPoint(prevOffset, scrollView.contentOffset)) {
          consecutiveTouchPointsWithSameContentOffset++;
        } else {
          consecutiveTouchPointsWithSameContentOffset = 0;
          prevOffset = scrollView.contentOffset;
        }
      }
      if (touchPointIndex > kMinTouchPointsToDetectScrollResistance) {
        if (shouldDetectResistanceFromContentOffset &&
            consecutiveTouchPointsWithSameContentOffset > kMinTouchPointsToDetectScrollResistance) {
          detectedResistanceFromContentOffsets = YES;
        }
        if ([scrollView grey_hasScrollResistance] || detectedResistanceFromContentOffsets) {
          // Looks like we have reached the edge we can stop scrolling now.
          hasResistance = YES;
          break;
        }
      }
    }
  }
  [eventGenerator endTouch];
  // Drain the main loop to process the touch path and finish scroll bounce animation if any.
  while ([[GREYAppStateTracker sharedInstance] currentState] & kGREYPendingUIScrollViewScrolling) {
    [[GREYUIThreadExecutor sharedInstance] drainOnce];
  }
  return !hasResistance;
}

@end