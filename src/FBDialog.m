/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#import "FBDialog.h"
#import "Facebook.h"

#pragma mark - constants
static NSString* kDefaultTitle = @"Connect to Facebook";

static CGFloat kFacebookBlue[4] = {0.42578125, 0.515625, 0.703125, 1.0};
static CGFloat kBorderGray[4] = {0.3, 0.3, 0.3, 0.8};
static CGFloat kBorderBlack[4] = {0.3, 0.3, 0.3, 1};
static CGFloat kBorderBlue[4] = {0.23, 0.35, 0.6, 1.0};

static CGFloat kTransitionDuration = 0.3;

static CGFloat kTitleMarginX = 8;
static CGFloat kTitleMarginY = 4;
static CGFloat kPadding = 10;
static CGFloat kBorderWidth = 10;


#pragma mark - private interface declarations
@interface FBDialog () <UIWebViewDelegate>

- (void)initInstance;

- (void)dismissWithError:(NSError*)error animated:(BOOL)animated;
- (void)dismissWithSucceedURL:(NSURL *)url;
- (void)dismissWithCancelURL:(NSURL *)url;


- (void)addRoundedRectToPath:(CGContextRef)context rect:(CGRect)rect radius:(float)radius;
- (void)drawRect:(CGRect)rect fill:(const CGFloat*)fillColors radius:(CGFloat)radius;
- (void)strokeLines:(CGRect)rect stroke:(const CGFloat*)strokeColor;

- (CGAffineTransform)transformForCurrentOrientation;

- (void)updateWebOrientation;
- (void)sizeToFitOrientation:(BOOL)transform;

- (void)addObservers;
- (void)removeObservers;

- (void)updateWebOrientation;
- (BOOL)shouldRotateToOrientation:(UIDeviceOrientation)anOrientation;

- (void)cancel;

@property (nonatomic, retain) UIWebView* webView;
@property (nonatomic, retain) UIActivityIndicatorView* spinner;
@property (nonatomic, retain) UIImageView* iconView;
@property (nonatomic, retain) UILabel* titleLabel;
@property (nonatomic, retain) UIButton* closeButton;

// Ensures that UI elements behind the dialog are disabled.
@property (nonatomic, retain) UIView* modalBackgroundView;

@property (nonatomic, assign) UIDeviceOrientation orientation;
@property (nonatomic, assign, getter = isKeyboardDisplayed) BOOL keyboardDisplayed;    

@property (nonatomic, retain) NSURL* serverURL;
@property (nonatomic, retain) NSURL* loadingURL;

@end

#pragma mark - implementation
@implementation FBDialog

#pragma mark - class methods
+ (NSString *)getParamFromUrl:(NSURL*)url paramName:(NSString *)paramName {
    NSString * str = nil;
    NSRange start = [url.absoluteString rangeOfString:paramName];
    if (start.location != NSNotFound) {
        NSRange end = [[url.absoluteString substringFromIndex:start.location+start.length] rangeOfString:@"&"];
        NSUInteger offset = start.location+start.length;
        str = end.location == NSNotFound
        ? [url.absoluteString substringFromIndex:offset]
        : [url.absoluteString substringWithRange:NSMakeRange(offset, end.location)];
        str = [str stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    return str;
}

+ (NSURL *)buildURL:(NSURL *)baseURL withParams:(NSDictionary *)aParams {
    if (aParams != nil) {
        NSMutableArray* pairs = [NSMutableArray array];
        for (NSString* key in aParams.keyEnumerator) {
            NSString* value = [aParams objectForKey:key];
            NSString* escapedValue = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, /* allocator */
                                                                                         (CFStringRef)value,
                                                                                         NULL, /* charactersToLeaveUnescaped */
                                                                                         (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                         kCFStringEncodingUTF8);
            
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, escapedValue]];
            [escapedValue release];
        }
        
        NSString* query = [pairs componentsJoinedByString:@"&"];
        NSString* url = [NSString stringWithFormat:@"%@?%@", baseURL.absoluteString, query];
        return [NSURL URLWithString:url];
    } 
    else {
        return [[baseURL copy] autorelease];
    }
}

#pragma mark - properties
@synthesize params;

@synthesize webView, spinner, iconView, titleLabel, closeButton, modalBackgroundView;
@synthesize orientation, keyboardDisplayed;
@synthesize serverURL, loadingURL;
@synthesize comletionHandler, shouldOpenURLInExternalBrowserHandler;

@dynamic title;

#pragma mark - constructors
- (id)init {
    if ((self = [super initWithFrame:CGRectZero])) {
        [self initInstance];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])){
        [self initInstance];
    }
    return self;
}
- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])){
        [self initInstance];
    }
    return self;
}
- (id)initWithURL:(NSURL *)anServerURL params:(NSDictionary *)aParams {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.serverURL = anServerURL;
        self.params = aParams;
        
        [self initInstance];
    }
    return self;
}

- (void)initInstance {
    self.loadingURL = nil;
    self.orientation = UIDeviceOrientationUnknown;
    self.keyboardDisplayed = NO;
    
    self.backgroundColor = [UIColor clearColor];
    self.autoresizesSubviews = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentMode = UIViewContentModeRedraw;
    
    UIImage *iconImage = [UIImage imageNamed:@"FBDialog.bundle/images/fbicon.png"];
    UIImage *closeImage = [UIImage imageNamed:@"FBDialog.bundle/images/close.png"];
    
    self.iconView = [[[UIImageView alloc] initWithImage:iconImage] autorelease];
    [self addSubview:self.iconView];
    
    UIColor *color = [UIColor colorWithRed:167.0/255 green:184.0/255 blue:216.0/255 alpha:1];
    self.closeButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    [self.closeButton setImage:closeImage forState:UIControlStateNormal];
    [self.closeButton setTitleColor:color forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [self.closeButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    
    self.closeButton.showsTouchWhenHighlighted = YES;
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.closeButton];
    
    CGFloat titleLabelFontSize = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 18 : 14);
    self.titleLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    self.titleLabel.text = kDefaultTitle;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:titleLabelFontSize];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.titleLabel];
    
    self.webView = [[[UIWebView alloc] initWithFrame:CGRectMake(kPadding, kPadding, 480, 480)] autorelease];
    self.webView.delegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.webView];
    
    self.spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self addSubview:spinner];
    self.modalBackgroundView = [[[UIView alloc] init] autorelease];    
}

- (void)dealloc {
    self.webView.delegate = nil;
    self.webView = nil;
    self.spinner = nil;
    self.iconView = nil;
    self.titleLabel = nil;
    self.closeButton = nil;
    self.modalBackgroundView = nil;
    
    self.params = nil;
    
    self.serverURL = nil;
    self.loadingURL = nil;
    
    self.comletionHandler = nil;
    
    [super dealloc];
}

#pragma mark - drawing
- (void)drawRect:(CGRect)rect {
    CGRect grayRect = CGRectOffset(rect, -0.5, -0.5);
    [self drawRect:grayRect fill:kBorderGray radius:10];
    
    CGRect headerRect = CGRectMake(ceil(rect.origin.x + kBorderWidth), ceil(rect.origin.y + kBorderWidth),
                                   rect.size.width - kBorderWidth*2, self.titleLabel.frame.size.height);
    [self drawRect:headerRect fill:kFacebookBlue radius:0];
    [self strokeLines:headerRect stroke:kBorderBlue];
    
    CGRect webRect = CGRectMake(ceil(rect.origin.x + kBorderWidth), headerRect.origin.y + headerRect.size.height,
                                rect.size.width - kBorderWidth*2, self.webView.frame.size.height+1);
    [self strokeLines:webRect stroke:kBorderBlack];
}

- (void)addRoundedRectToPath:(CGContextRef)context rect:(CGRect)rect radius:(float)radius {
    CGContextBeginPath(context);
    CGContextSaveGState(context);
    
    if (radius == 0) {
        CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
        CGContextAddRect(context, rect);
    } 
    else {
        rect = CGRectOffset(CGRectInset(rect, 0.5, 0.5), 0.5, 0.5);
        CGContextTranslateCTM(context, CGRectGetMinX(rect)-0.5, CGRectGetMinY(rect)-0.5);
        CGContextScaleCTM(context, radius, radius);
        float fw = CGRectGetWidth(rect) / radius;
        float fh = CGRectGetHeight(rect) / radius;
        
        CGContextMoveToPoint(context, fw, fh/2);
        CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
        CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
        CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
        CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    }
    
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

- (void)drawRect:(CGRect)rect fill:(const CGFloat*)fillColors radius:(CGFloat)radius {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    
    if (fillColors) {
        CGContextSaveGState(context);
        CGContextSetFillColor(context, fillColors);
        if (radius) {
            [self addRoundedRectToPath:context rect:rect radius:radius];
            CGContextFillPath(context);
        } 
        else {
            CGContextFillRect(context, rect);
        }
        CGContextRestoreGState(context);
    }
    
    CGColorSpaceRelease(space);
}

- (void)strokeLines:(CGRect)rect stroke:(const CGFloat*)strokeColor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    
    CGContextSaveGState(context);
    CGContextSetStrokeColorSpace(context, space);
    CGContextSetStrokeColor(context, strokeColor);
    CGContextSetLineWidth(context, 1.0);
    
    {
        CGPoint points[] = {{rect.origin.x+0.5, rect.origin.y-0.5},
            {rect.origin.x+rect.size.width, rect.origin.y-0.5}};
        CGContextStrokeLineSegments(context, points, 2);
    }
    {
        CGPoint points[] = {{rect.origin.x+0.5, rect.origin.y+rect.size.height-0.5},
            {rect.origin.x+rect.size.width-0.5, rect.origin.y+rect.size.height-0.5}};
        CGContextStrokeLineSegments(context, points, 2);
    }
    {
        CGPoint points[] = {{rect.origin.x+rect.size.width-0.5, rect.origin.y},
            {rect.origin.x+rect.size.width-0.5, rect.origin.y+rect.size.height}};
        CGContextStrokeLineSegments(context, points, 2);
    }
    {
        CGPoint points[] = {{rect.origin.x+0.5, rect.origin.y},
            {rect.origin.x+0.5, rect.origin.y+rect.size.height}};
        CGContextStrokeLineSegments(context, points, 2);
    }
    
    CGContextRestoreGState(context);
    
    CGColorSpaceRelease(space);
}


#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = request.URL;
    
    if ([url.scheme isEqualToString:@"fbconnect"]) {
        if ([[url.resourceSpecifier substringToIndex:8] isEqualToString:@"//cancel"]) {
            NSString *errorCode = [[self class] getParamFromUrl:url paramName:@"error_code="];
            NSString *errorStr = [[self class] getParamFromUrl:url paramName:@"error_msg="];
            if (errorCode) {
                NSDictionary *errorData = [NSDictionary dictionaryWithObject:errorStr forKey:@"error_msg"];
                NSError *error = [NSError errorWithDomain:@"facebookErrDomain"
                                                      code:[errorCode intValue]
                                                  userInfo:errorData];
                [self dismissWithError:error animated:YES];
            } 
            else {
                [self dismissWithCancelURL:url];
            }
        } 
        else {
            [self dismissWithSucceedURL:url];
        }
        return NO;
    } 
    else if ([self.loadingURL isEqual:url]) {
        return YES;
    } 
    else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if (self.shouldOpenURLInExternalBrowserHandler != nil) {
            if (self.shouldOpenURLInExternalBrowserHandler(request.URL)) {
                [[UIApplication sharedApplication] openURL:request.URL];
            }
        }
        
        return NO;
    } 
    else {
        return YES;
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self.spinner stopAnimating];
    self.spinner.hidden = YES;
    
    self.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self updateWebOrientation];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // 102 == WebKitErrorFrameLoadInterruptedByPolicyChange
    if (!([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102)) {
        [self dismissWithError:error animated:YES];
    }
}

#pragma mark - notifications setup
- (void)addObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification 
                                               object:nil];
    
    // On the iPad the screen is large enough that we don't need to
    // resize the dialog to accomodate the keyboard popping up
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:) 
                                                     name:UIKeyboardWillShowNotification 
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:) 
                                                     name:UIKeyboardWillHideNotification 
                                                   object:nil];
    }
    
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification 
                                                  object:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIKeyboardWillShowNotification
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIKeyboardWillHideNotification 
                                                      object:nil];
    }
}

#pragma mark - orientation change notifications
- (void)deviceOrientationDidChange:(void*)object {
    if (!self.keyboardDisplayed && [self shouldRotateToOrientation:[UIDevice currentDevice].orientation]) {
        [self updateWebOrientation];
        
        CGFloat duration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
        [UIView animateWithDuration:duration animations:^{
            [self sizeToFitOrientation:YES];
        }];
    }
}

#pragma mark - keyboard show notifications
- (void)keyboardWillShow:(NSNotification*)notification {
    self.keyboardDisplayed = YES;
        
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        self.webView.frame = CGRectInset(self.webView.frame,
                                         -(kPadding + kBorderWidth),
                                         -(kPadding + kBorderWidth) - self.titleLabel.frame.size.height);
    }
}

- (void)keyboardWillHide:(NSNotification*)notification {
    self.keyboardDisplayed = NO;
    
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        self.webView.frame = CGRectInset(self.webView.frame,
                                         kPadding + kBorderWidth,
                                         kPadding + kBorderWidth + self.titleLabel.frame.size.height);
    }
}

#pragma mark - dialog presentation methods
- (void)show {
    self.loadingURL = [[self class] buildURL:self.serverURL withParams:self.params];
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.loadingURL]];
    
    [self sizeToFitOrientation:NO];
    
    CGFloat innerWidth = self.frame.size.width - (kBorderWidth+1)*2;
    [self.iconView sizeToFit];
    [self.titleLabel sizeToFit];
    [self.closeButton sizeToFit];
    
    self.titleLabel.frame = CGRectMake(kBorderWidth + kTitleMarginX + self.iconView.frame.size.width + kTitleMarginX,
                                       kBorderWidth,
                                       innerWidth - (self.titleLabel.frame.size.height + self.iconView.frame.size.width + kTitleMarginX*2),
                                       self.titleLabel.frame.size.height + kTitleMarginY*2);
    
    self.iconView.frame = CGRectMake(kBorderWidth + kTitleMarginX,
                                     kBorderWidth + floor(self.titleLabel.frame.size.height/2.0 - self.iconView.frame.size.height/2),
                                     self.iconView.frame.size.width,
                                     self.iconView.frame.size.height);
    
    self.closeButton.frame = CGRectMake(self.frame.size.width - (self.titleLabel.frame.size.height + kBorderWidth),
                                        kBorderWidth,
                                        self.titleLabel.frame.size.height,
                                        self.titleLabel.frame.size.height);
    
    self.webView.frame = CGRectMake(kBorderWidth+1,
                                    kBorderWidth + self.titleLabel.frame.size.height,
                                    innerWidth,
                                    self.frame.size.height - (self.titleLabel.frame.size.height + 1 + kBorderWidth*2));
    
    [self.spinner sizeToFit];
    [self.spinner startAnimating];
    self.spinner.center = self.webView.center;
    
    UIWindow* window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        window = [[UIApplication sharedApplication].windows objectAtIndex:0];
    }
    
    self.modalBackgroundView.frame = window.frame;
    [self.modalBackgroundView addSubview:self];
    [window addSubview:self.modalBackgroundView];
    
    [window addSubview:self];
    
    self.transform = CGAffineTransformScale([self transformForCurrentOrientation], 0.001, 0.001);
    //[UIView beginAnimations:nil context:nil];
    //[UIView setAnimationDuration:kTransitionDuration/1.5];
    //[UIView setAnimationDelegate:self];
    //[UIView setAnimationDidStopSelector:@selector(bounce1AnimationStopped)];
    //self.transform = CGAffineTransformScale([self transformForCurrentOrientation], 1.1, 1.1);
    //[UIView commitAnimations];
        
    dispatch_block_t step1 = ^{
        self.transform = CGAffineTransformScale([self transformForCurrentOrientation], 1.1, 1.1);
    };
    dispatch_block_t step2 = ^{
        self.transform = CGAffineTransformScale([self transformForCurrentOrientation], 0.9, 0.9);
    };
    dispatch_block_t step3 = ^{
        self.transform = [self transformForCurrentOrientation];
    };
    
    [UIView animateWithDuration:kTransitionDuration/1.5 animations:step1 completion:^(BOOL finished){
        [UIView animateWithDuration:kTransitionDuration/2 animations:step2 completion:^(BOOL finished){
            [UIView animateWithDuration:kTransitionDuration/2 animations:step3];
        }];
    }];
    
    
    [self addObservers];
}

- (void)showWithCompletionHandler:(FBDialogComletionHandler)aComletionHandler {
    self.comletionHandler = aComletionHandler;
    [self show];
}

- (void)dismissAnimated:(BOOL)animated {
    self.loadingURL = nil;
    
    [UIView animateWithDuration:(animated ? kTransitionDuration : 0)
                     animations:^{
                         self.alpha = 0;
                     }
                     completion:^(BOOL finished){
                         [self removeObservers];
                         [self removeFromSuperview];
                         [self.modalBackgroundView removeFromSuperview];
                     }];    
}

//- (void)bounce1AnimationStopped {
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationDuration:kTransitionDuration/2];
//    [UIView setAnimationDelegate:self];
//    [UIView setAnimationDidStopSelector:@selector(bounce2AnimationStopped)];
//    self.transform = CGAffineTransformScale([self transformForCurrentOrientation], 0.9, 0.9);
//    [UIView commitAnimations];
//}
//
//- (void)bounce2AnimationStopped {
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationDuration:kTransitionDuration/2];
//    self.transform = [self transformForCurrentOrientation];
//    [UIView commitAnimations];
//}

#pragma mark - completion methods
- (void)dismissWithError:(NSError*)error animated:(BOOL)animated {
    if (self.comletionHandler != nil) {
        self.comletionHandler(FBDialogCompletionStatusError,nil,error);
    }
    
    [self dismissAnimated:animated];
}
- (void)dismissWithSucceedURL:(NSURL *)url {    
    if (self.comletionHandler != nil) {
        self.comletionHandler(FBDialogCompletionStatusSuccess,url,nil);
    }
    [self dismissAnimated:YES];
}

- (void)dismissWithCancelURL:(NSURL *)url {
    if (self.comletionHandler != nil) {
        self.comletionHandler(FBDialogCompletionStatusCancel,url,nil);
    }
    [self dismissAnimated:YES];
}

#pragma mark - helpers
- (void)cancel {
    [self dismissWithCancelURL:nil];
}

- (BOOL)shouldRotateToOrientation:(UIDeviceOrientation)anOrientation {
    return anOrientation != self.orientation;
}

- (CGAffineTransform)transformForCurrentOrientation {
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (currentOrientation == UIInterfaceOrientationLandscapeLeft) {
        return CGAffineTransformMakeRotation(M_PI*1.5);
    } 
    else if (currentOrientation == UIInterfaceOrientationLandscapeRight) {
        return CGAffineTransformMakeRotation(M_PI/2);
    } 
    else if (currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        return CGAffineTransformMakeRotation(-M_PI);
    } 
    else {
        return CGAffineTransformIdentity;
    }
}

- (void)sizeToFitOrientation:(BOOL)transform {
    if (transform) {
        self.transform = CGAffineTransformIdentity;
    }
    
    CGRect frame = [UIScreen mainScreen].applicationFrame;
    CGPoint center = CGPointMake(frame.origin.x + ceil(frame.size.width/2),
                                 frame.origin.y + ceil(frame.size.height/2));
    
    CGFloat scale_factor = 1.0f;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        // On the iPad the dialog's dimensions should only be 60% of the screen's
        scale_factor = 0.6f;
    }
    
    CGFloat width = floor(scale_factor * frame.size.width) - kPadding * 2;
    CGFloat height = floor(scale_factor * frame.size.height) - kPadding * 2;
    
    self.orientation = [UIDevice currentDevice].orientation;
    if (UIInterfaceOrientationIsLandscape(self.orientation)) {
        self.frame = CGRectMake(kPadding, kPadding, height, width);
    } 
    else {
        self.frame = CGRectMake(kPadding, kPadding, width, height);
    }
    self.center = center;
    
    if (transform) {
        self.transform = [self transformForCurrentOrientation];
    }
}

- (void)updateWebOrientation {
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        [self.webView stringByEvaluatingJavaScriptFromString:@"document.body.setAttribute('orientation', 90);"];
    } 
    else {
        [self.webView stringByEvaluatingJavaScriptFromString:@"document.body.removeAttribute('orientation');"];
    }
}

#pragma mark - getters & setters
#pragma mark title
- (NSString*)title {
    return self.titleLabel.text;
}

- (void)setTitle:(NSString*)title {
    self.titleLabel.text = title;
}

@end
