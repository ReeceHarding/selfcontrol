//
//  SCTimeSlider.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/17/21.
//

#import "SCDurationSlider.h"
#import "SCTimeIntervalFormatter.h"
#import <TransformerKit/NSValueTransformer+TransformerKit.h>
#import <math.h>

#define kValueTransformerName @"BlockDurationSliderTransformer"
#define kMinDurationMinutes 1
#define kSliderMinPosition 0.0
#define kSliderMaxPosition 1.0

@implementation SCDurationSlider

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder: coder]) {
        [self initializeDurationProperties];
    }
    return self;
}
- (instancetype)init {
    if (self = [super init]) {
        [self initializeDurationProperties];
    }
    return self;
}

- (void)initializeDurationProperties {
    // default: 30 day max
    _maxDuration = 30 * 24 * 60;
    [self configurePositionRange];

    // register an NSValueTransformer
    [self registerMinutesValueTransformer];
}

- (void)setMaxDuration:(NSInteger)maxDuration {
    _maxDuration = MAX(maxDuration, kMinDurationMinutes);
    [self configurePositionRange];
}

- (void)configurePositionRange {
    [self setMinValue: kSliderMinPosition];
    [self setMaxValue: kSliderMaxPosition];
    [self setDurationValueMinutes: self.durationValueMinutes];
}

- (NSInteger)clampedDurationMinutes:(NSInteger)durationMinutes {
    return MIN(MAX(durationMinutes, kMinDurationMinutes), self.maxDuration);
}

- (NSInteger)roundedDurationMinutes:(double)durationMinutes {
    NSInteger roundedMinutes;
    if (durationMinutes < 60) {
        roundedMinutes = lround(durationMinutes);
    } else if (durationMinutes < 6 * 60) {
        roundedMinutes = lround(durationMinutes / 5.0) * 5;
    } else if (durationMinutes < 24 * 60) {
        roundedMinutes = lround(durationMinutes / 15.0) * 15;
    } else if (durationMinutes < 7 * 24 * 60) {
        roundedMinutes = lround(durationMinutes / 60.0) * 60;
    } else {
        roundedMinutes = lround(durationMinutes / (6.0 * 60.0)) * 6 * 60;
    }

    return [self clampedDurationMinutes: roundedMinutes];
}

- (double)sliderPositionForDurationMinutes:(NSInteger)durationMinutes {
    NSInteger clampedDuration = [self clampedDurationMinutes: durationMinutes];
    if (self.maxDuration <= kMinDurationMinutes) {
        return kSliderMinPosition;
    }

    double logMax = log((double)self.maxDuration);
    return log((double)clampedDuration) / logMax;
}

- (NSInteger)durationMinutesForSliderPosition:(double)sliderPosition {
    if (self.maxDuration <= kMinDurationMinutes) {
        return kMinDurationMinutes;
    }

    double clampedPosition = MIN(MAX(sliderPosition, kSliderMinPosition), kSliderMaxPosition);
    double rawMinutes = exp(clampedPosition * log((double)self.maxDuration));
    return [self roundedDurationMinutes: rawMinutes];
}

- (void)registerMinutesValueTransformer {
    [NSValueTransformer registerValueTransformerWithName: kValueTransformerName
                                   transformedValueClass: [NSNumber class]
                      returningTransformedValueWithBlock:^id _Nonnull(id  _Nonnull value) {
        // if it's not a number or convertable to one, IDK man
        if (![value respondsToSelector: @selector(floatValue)]) return @0;
        
        long minutesValue = lroundf([value floatValue]);
        return @(minutesValue);
    }];
}

- (NSInteger)durationValueMinutes {
    return [self durationMinutesForSliderPosition: self.doubleValue];
}

- (void)setDurationValueMinutes:(NSInteger)durationValueMinutes {
    [self setDoubleValue: [self sliderPositionForDurationMinutes: durationValueMinutes]];
}

- (void)bindDurationToObject:(id)obj keyPath:(NSString*)keyPath {
    [self bind: @"value"
      toObject: obj
   withKeyPath: keyPath
       options: @{
                  NSContinuouslyUpdatesValueBindingOption: @YES,
                  NSValueTransformerNameBindingOption: kValueTransformerName
                  }];
}

- (NSString*)durationDescription {
    return [SCDurationSlider timeSliderDisplayStringFromNumberOfMinutes: self.durationValueMinutes];
}

// String conversion utility methods

+ (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static SCTimeIntervalFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[SCTimeIntervalFormatter alloc] init];
    }

    NSString* formatted = [formatter stringForObjectValue:@(numberOfSeconds)];
    return formatted;
}

+ (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
    if (numberOfMinutes < 0) return @"Invalid duration";

    static NSCalendar* gregorian = nil;
    if (gregorian == nil) {
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }

    NSRange secondsRangePerMinute = [gregorian
                                     rangeOfUnit:NSCalendarUnitSecond
                                     inUnit:NSCalendarUnitMinute
                                     forDate:[NSDate date]];
    NSInteger numberOfSecondsPerMinute = (NSInteger)NSMaxRange(secondsRangePerMinute);

    NSTimeInterval numberOfSecondsSelected = (NSTimeInterval)(numberOfSecondsPerMinute * numberOfMinutes);

    NSString* displayString = [SCDurationSlider timeSliderDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}


@end
