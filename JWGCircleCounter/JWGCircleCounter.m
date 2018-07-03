//
//  JWGCircleCounter.m
//  Version 0.2.2
//
//  https://github.com/johngraham262/JWGCircleCounter
//

#import "JWGCircleCounter.h"

#define JWG_SECONDS_ADJUSTMENT 1000
#define JWG_TIMER_INTERVAL .015 // ~60 FPS

@interface JWGCircleCounter()

@property (strong, nonatomic) NSTimer *fadeOutTimer;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSDate *lastStartTime;

@property (strong, nonatomic) NSDate *fadeOutTimerStarted;
@property (assign, nonatomic) NSTimeInterval fadeOutDuration;
@property (assign, nonatomic) NSTimeInterval fadeOutElapsed;
@property (assign, nonatomic) BOOL isFadingOut;

@property (assign, nonatomic) NSTimeInterval completedTimeUpToLastStop;

@end

@implementation JWGCircleCounter

#pragma mark - Public methods

- (void)baseInit {
    self.backgroundColor = [UIColor clearColor];

    self.circleColor = JWG_CIRCLE_COLOR_DEFAULT;
    self.circleBackgroundColor = JWG_CIRCLE_BACKGROUND_COLOR_DEFAULT;
    self.circleFillColor = JWG_CIRCLE_FILL_COLOR_DEFAULT;
    self.circleTimerWidth = JWG_CIRCLE_TIMER_WIDTH;
    
    [self setupTimerLabel];
    self.timerLabelHidden = YES;
    self.hidesTimerLabelWhenFinished = YES;
    self.isFadingOut = NO;
    
    self.completedTimeUpToLastStop = 0;
    _elapsedTime = 0;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self baseInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self baseInit];
    }

    return self;
}

- (void)startWithSeconds:(NSTimeInterval)seconds {

    [JWGCircleCounter validateInputTime:seconds];

    self.totalTime = seconds;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:JWG_TIMER_INTERVAL
                                                  target:self
                                                selector:@selector(timerFired)
                                                userInfo:nil
                                                 repeats:YES];

    _isRunning = YES;
    _didStart = YES;
    _didFinish = NO;

    self.lastStartTime = [NSDate dateWithTimeIntervalSinceNow:0];
    self.completedTimeUpToLastStop = 0;
    _elapsedTime = 0;

    _timerLabel.hidden = self.timerLabelHidden;

    [self.timer fire];
}

- (void)updateElapsedTime:(NSTimeInterval)value {
    if (_isRunning) {
        return;
    }

    _elapsedTime = value;
    self.completedTimeUpToLastStop = value;

    // Check if timer has expired.
    if (self.elapsedTime > self.totalTime) {
        [self timerCompleted];
    }

    _timerLabel.text = [NSString stringWithFormat:@"%li", (long)ceil(_totalTime - _elapsedTime)];

    [self setNeedsDisplay];
}

- (void)timerFired {
    if (!_isRunning) {
        return;
    }

    _elapsedTime = (self.completedTimeUpToLastStop +
                    [[NSDate date] timeIntervalSinceDate:self.lastStartTime]);

    // Check if timer has expired.
    if (self.elapsedTime > self.totalTime) {
        [self timerCompleted];
    }

    _timerLabel.text = [NSString stringWithFormat:@"%li", (long)ceil(_totalTime - _elapsedTime)];
    
    [self setNeedsDisplay];
}

- (void)resume {
    _isRunning = YES;
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    self.lastStartTime = now;
    [self.timer setFireDate:now];
}

- (void)stop {
    _isRunning = NO;

    self.completedTimeUpToLastStop += [[NSDate date] timeIntervalSinceDate:self.lastStartTime];
    _elapsedTime = self.completedTimeUpToLastStop;

    [self.timer setFireDate:[NSDate distantFuture]];
}

- (void)reset {
    [self.timer invalidate];
    self.timer = nil;

    _elapsedTime = 0;
    _isRunning = NO;
    _didStart = NO;
    _didFinish = NO;
}

- (void)setTimerLabelHidden:(BOOL)timerLabelHidden {
    _timerLabelHidden = timerLabelHidden;
    
    [_timerLabel setHidden:timerLabelHidden];
}

#pragma mark - Private methods

+ (void)validateInputTime:(NSTimeInterval)time {
    if (time < 0.01) {
        [NSException raise:@"JWGInvalidTime"
                    format:@"inputted timer length, %li, must be a positive integer", (long)time];
    }
}

- (void)setupTimerLabel {
    _timerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _timerLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_timerLabel];
    
    _timerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(_timerLabel);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_timerLabel]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_timerLabel]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
}

- (void)timerCompleted {
    [self.timer invalidate];

    _isRunning = NO;
    _didFinish = YES;

    _elapsedTime = self.totalTime;

    _timerLabel.hidden = self.hidesTimerLabelWhenFinished;

    if ([self.delegate respondsToSelector:@selector(circleCounterTimeDidExpire:)]) {
        [self.delegate circleCounterTimeDidExpire:self];
    }
}

- (void)drawRect:(CGRect)rect {
    if (self.isFadingOut) {
        [self drawFadeResetCircleRect:rect];
    } else {
        [self drawTimerCircleRect:rect];
    }
}

- (void)drawTimerCircleRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat radius = CGRectGetWidth(rect)/2.0f - self.circleTimerWidth/2.0f;
    CGFloat angleOffset = M_PI_2;
    
    // Draw the background of the circle.
    CGContextSetLineWidth(context, self.circleTimerWidth);
    CGContextBeginPath(context);
    CGContextAddArc(context,
                    CGRectGetMidX(rect), CGRectGetMidY(rect),
                    radius,
                    0,
                    2*M_PI,
                    0);
    CGContextSetStrokeColorWithColor(context, [self.circleBackgroundColor CGColor]);
    CGContextSetFillColorWithColor(context, [self.circleFillColor CGColor]);
    CGContextDrawPath(context, kCGPathFillStroke);
    
    // Draw the remaining amount of timer circle.
    CGContextSetLineWidth(context, self.circleTimerWidth);
    CGContextBeginPath(context);
    CGFloat startAngle = (((CGFloat)self.elapsedTime) / (CGFloat)self.totalTime)*M_PI*2;
    
    if (!self.isRunning && !self.didStart && !self.didFinish) {
        // If the timer hasn't started yet, fill the whole circle. (startAngle will be NaN)
        startAngle = 0;
    }
    
    CGContextAddArc(context,
                    CGRectGetMidX(rect), CGRectGetMidY(rect),
                    radius,
                    startAngle - angleOffset,
                    2*M_PI - angleOffset,
                    0);
    CGContextSetStrokeColorWithColor(context, [self.circleColor CGColor]);
    CGContextStrokePath(context);
}

- (void)drawFadeResetCircleRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat radius = CGRectGetWidth(rect)/2.0f - self.circleTimerWidth/2.0f;
    CGFloat angleOffset = M_PI_2;
    
    // Draw the background of the circle.
    CGContextSetLineWidth(context, self.circleTimerWidth);
    CGContextBeginPath(context);
    CGContextAddArc(context,
                    CGRectGetMidX(rect), CGRectGetMidY(rect),
                    radius,
                    0,
                    2*M_PI,
                    0);
    CGContextSetStrokeColorWithColor(context, [self.circleBackgroundColor CGColor]);
    

    CGContextSetFillColorWithColor(context, [self.circleFillColor CGColor]);
    CGContextDrawPath(context, kCGPathFillStroke);
    
    // Draw the remaining amount of timer circle.
    CGContextSetLineWidth(context, self.circleTimerWidth);
    CGContextBeginPath(context);
    CGFloat startAngle = 0;
    

    
    CGContextAddArc(context,
                    CGRectGetMidX(rect), CGRectGetMidY(rect),
                    radius,
                    startAngle - angleOffset,
                    2*M_PI - angleOffset,
                    0);
    
    CGFloat alpha = 0;
    if (self.fadeOutElapsed > 0) {
        alpha = self.fadeOutElapsed / self.fadeOutDuration;
    }
    NSLog(@"alpha %f", alpha);
    
    CGContextSetStrokeColorWithColor(context, [[self.circleColor colorWithAlphaComponent:alpha] CGColor]);
    CGContextStrokePath(context);
}

- (void)fadeResetWithTime:(NSTimeInterval)seconds
{
    self.fadeOutTimerStarted = [NSDate date];
    self.fadeOutDuration = seconds;
    self.fadeOutElapsed = 0;
    self.isFadingOut = YES;
    self.fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:JWG_TIMER_INTERVAL
                                                  target:self
                                                selector:@selector(fadeOutTimerFired)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)fadeOutTimerFired
{    
    NSLog(@"fadeOutTimerFired");
    if (!self.isFadingOut) {
        return;
    }
    
    self.fadeOutElapsed = -[self.fadeOutTimerStarted timeIntervalSinceNow];
    
    if (self.fadeOutElapsed > self.fadeOutDuration) {
        [self.fadeOutTimer invalidate];
        self.isFadingOut = NO;
        return;
    }
    
    [self setNeedsDisplay];
    
}

@end
