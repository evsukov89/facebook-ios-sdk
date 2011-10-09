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

#import "Facebook.h"
#import "FBLoginDialog.h"
#import "FBRequest.h"

#pragma mark - Constants
static NSString* kDialogBaseURL = @"https://m.facebook.com/dialog/";
static NSString* kGraphBaseURL = @"https://graph.facebook.com/";
static NSString* kRestserverBaseURL = @"https://api.facebook.com/method/";

static NSString* kFBAppAuthURLScheme = @"fbauth";
static NSString* kFBAppAuthURLPath = @"authorize";
static NSString* kRedirectURL = @"fbconnect://success";

static NSString* kLogin = @"oauth";
static NSString* kSDK = @"ios";
static NSString* kSDKVersion = @"2";

#pragma mark - private interface declarations
@interface Facebook ()

- (NSString *)getOwnBaseUrl;
- (void)authorizeWithFBAppAuth:(BOOL)tryFBAppAuth safariAuth:(BOOL)trySafariAuth;

- (NSDictionary*)parseURLParams:(NSString *)query;

@property (nonatomic, copy) FBAuthorizeCompletionHandler authorizeResultCompletionHandler;
@property (nonatomic, retain) NSOperationQueue *authorizeResultCompletionHandlerQueue;

@property (nonatomic, copy) FBLoginDialogCompletionHandler loginCompletionHandler;

@end

#pragma mark -
@implementation Facebook

#pragma mark - properties
@synthesize accessToken, expirationDate, permissions, appId, localAppId;
@synthesize authorizeResultCompletionHandler, authorizeResultCompletionHandlerQueue;
@synthesize loginCompletionHandler;

#pragma mark - init & dealloc
- (id)init {
    NSLog(@"%s: returnin `nil` incorrect constructor. use -[Facebook initWithAppId:] instead",__PRETTY_FUNCTION__);
    return nil;
}

- (id)initWithAppId:(NSString *)anAppId {
    if ((self = [super init])) {
        self.appId = anAppId;
        
        self.loginCompletionHandler = ^(FBLoginDialogCompletionStatus status, NSString *token, NSDate *expiration,NSError *error){
            
            FBAuthorizeResult result;
            
            if (status == FBLoginDialogCompletionStatusSuccess) {
                self.accessToken = token;
                self.expirationDate = expiration;
                
                result = FBAuthorizeResultUserDidLogin;
            }
            else if (status == FBLoginDialogCompletionStatusCanceledByUser) {
                result = FBAuthorizeResultUserDidCanceled;
            }
            else if (status == FBLoginDialogCompletionStatusError) {
                result = FBAuthorizeResultUserDidNotLogin;
            }
            
            if (self.authorizeResultCompletionHandler != nil) {
                [self.authorizeResultCompletionHandlerQueue addOperationWithBlock:^{ 
                    self.authorizeResultCompletionHandler(result);
                    
                    [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                        self.authorizeResultCompletionHandlerQueue = nil;
                        self.authorizeResultCompletionHandler = nil;                        
                    }];
                }];
            }
        };
    }
    return self;
}

- (void)dealloc {
    self.accessToken = nil;
    self.expirationDate = nil;
    
    self.permissions = nil;
    self.appId = nil;
    self.localAppId = nil;
        
    self.authorizeResultCompletionHandler = nil;
    self.authorizeResultCompletionHandlerQueue = nil;
    self.loginCompletionHandler = nil;
    
    [super dealloc];
}

#pragma mark - private methods
- (NSString *)getOwnBaseUrl {
    return [NSString stringWithFormat:@"fb%@%@://authorize",
            self.appId, self.localAppId ? self.localAppId : @""];
}

- (void)authorizeWithFBAppAuth:(BOOL)tryFBAppAuth safariAuth:(BOOL)trySafariAuth {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   self.appId, @"client_id",
                                   @"user_agent", @"type",
                                   kRedirectURL, @"redirect_uri",
                                   @"touch", @"display",
                                   kSDKVersion, @"sdk",
                                   nil];
    
    NSString *loginDialogURL = [kDialogBaseURL stringByAppendingString:kLogin];
    
    if (self.permissions != nil) {
        [params setObject:[self.permissions componentsJoinedByString:@","] forKey:@"scope"];
    }
    
    if (self.localAppId != nil) {
        [params setObject:self.localAppId forKey:@"local_client_id"];
    }
    
    // If the device is running a version of iOS that supports multitasking,
    // try to obtain the access token from the Facebook app installed
    // on the device.
    // If the Facebook app isn't installed or it doesn't support
    // the fbauth:// URL scheme, fall back on Safari for obtaining the access token.
    // This minimizes the chance that the user will have to enter his or
    // her credentials in order to authorize the application.
    BOOL didOpenOtherApp = NO;
    UIDevice *device = [UIDevice currentDevice];
    if ([device respondsToSelector:@selector(isMultitaskingSupported)] && [device isMultitaskingSupported]) {
        if (tryFBAppAuth) {
            NSString *scheme = kFBAppAuthURLScheme;
            if (self.localAppId) {
                scheme = [scheme stringByAppendingString:@"2"];
            }
            NSString *urlPrefix = [NSString stringWithFormat:@"%@://%@", scheme, kFBAppAuthURLPath];
            NSString *fbAppUrl = [FBRequest serializeURL:urlPrefix params:params];
            didOpenOtherApp = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:fbAppUrl]];
        }
        
        if (trySafariAuth && !didOpenOtherApp) {
            NSString *nextUrl = [self getOwnBaseUrl];
            [params setValue:nextUrl forKey:@"redirect_uri"];
            
            NSString *fbAppUrl = [FBRequest serializeURL:loginDialogURL params:params];
            didOpenOtherApp = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:fbAppUrl]];
        }
    }
    
    // If single sign-on failed, open an inline login dialog. This will require the user to
    // enter his or her credentials.
    if (!didOpenOtherApp) {        
        FBLoginDialog *loginDialog = [[[FBLoginDialog alloc] initWithURL:[NSURL URLWithString:loginDialogURL] params:params] autorelease];
        loginDialog.loginCompletionHandler = self.loginCompletionHandler;
        [loginDialog show];
    }
}

- (NSDictionary*)parseURLParams:(NSString *)query {
	NSArray *pairs = [query componentsSeparatedByString:@"&"];
	NSMutableDictionary *params = [NSMutableDictionary dictionary];
	for (NSString *pair in pairs) {
		NSArray *kv = [pair componentsSeparatedByString:@"="];
		NSString *val = [[kv objectAtIndex:1]
                         stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
		[params setObject:val forKey:[kv objectAtIndex:0]];
	}
    return params;
}

#pragma mark - authorize methods
- (void)authorizeWithPersmissions:(NSArray*)aPermissions completionHandler:(FBAuthorizeCompletionHandler)completionHandler {
    [self authorizeWithPersmissions:aPermissions localAppId:nil completionHandler:completionHandler];
}

- (void)authorizeWithPersmissions:(NSArray*)permissions localAppId:(NSString *)aLocalAppId 
                completionHandler:(FBAuthorizeCompletionHandler)completionHandler {
    
    self.permissions = permissions;
    self.localAppId = aLocalAppId;
    self.authorizeResultCompletionHandler = completionHandler;
    self.authorizeResultCompletionHandlerQueue = [NSOperationQueue currentQueue];
        
    [self authorizeWithFBAppAuth:YES safariAuth:YES];
}


- (BOOL)handleOpenURL:(NSURL *)url {
    // If the URL's structure doesn't match the structure used for Facebook authorization, abort.
    if (![[url absoluteString] hasPrefix:[self getOwnBaseUrl]]) {
        return NO;
    }
    
    NSString *query = [url fragment];
    
    // Version 3.2.3 of the Facebook app encodes the parameters in the query but
    // version 3.3 and above encode the parameters in the fragment. To support
    // both versions of the Facebook app, we try to parse the query if
    // the fragment is missing.
    if (!query) {
        query = [url query];
    }
    
    NSDictionary *params = [self parseURLParams:query];
    NSString *anAccessToken = [params valueForKey:@"access_token"];
    
    // If the URL doesn't contain the access token, an error has occurred.
    if (!anAccessToken) {
        NSString *errorReason = [params valueForKey:@"error"];
        
        // If the error response indicates that we should try again using Safari, open
        // the authorization dialog in Safari.
        if (errorReason && [errorReason isEqualToString:@"service_disabled_use_browser"]) {
            [self authorizeWithFBAppAuth:NO safariAuth:YES];
            return YES;
        }
        
        // If the error response indicates that we should try the authorization flow
        // in an inline dialog, do that.
        if (errorReason && [errorReason isEqualToString:@"service_disabled"]) {
            [self authorizeWithFBAppAuth:NO safariAuth:NO];
            return YES;
        }
        
        // The facebook app may return an error_code parameter in case it
        // encounters a UIWebViewDelegate error. This should not be treated
        // as a cancel.
        NSString *errorCode = [params valueForKey:@"error_code"];
        
        BOOL userDidCancel = !errorCode && (!errorReason || [errorReason isEqualToString:@"access_denied"]);
        NSError *error = [NSError errorWithDomain:@"facebookErrorDomain" code:[errorCode integerValue] userInfo:nil];
        
        FBLoginDialogCompletionStatus completionStatus = userDidCancel ? FBLoginDialogCompletionStatusCanceledByUser : FBLoginDialogCompletionStatusError;
        
        self.loginCompletionHandler(completionStatus,nil,nil,error);
        return YES;
    }
    
    // We have an access token, so parse the expiration date.
    NSString *expTime = [params valueForKey:@"expires_in"];
    NSDate *anExpirationDate = [NSDate distantFuture];
    if (expTime != nil) {
        int expVal = [expTime intValue];
        if (expVal != 0) {
            anExpirationDate = [NSDate dateWithTimeIntervalSinceNow:expVal];
        }
    }
    
    //[self fbDialogLogin:anAccessToken expirationDate:anExpirationDate];
    self.loginCompletionHandler(FBLoginDialogCompletionStatusSuccess,anAccessToken,anExpirationDate,nil);
    return YES;
}

- (void)logoutWithCompletionHandler:(FBAuthorizeCompletionHandler)completionHandler {
    //FBRequest *request = [self buildRequestWithGraphPath:@"auth.expireSession"];
    FBRequest *request = [self buildRequestWithMethodName:@"auth.expireSession" params:[NSDictionary dictionary] httpMethod:@"GET"];
    [request performWithCompletionHandler:^(NSURLResponse* response, id result, NSError* error){
        if (error != nil) {
            NSLog(@"%s: error during logout:%@",__PRETTY_FUNCTION__,error);
            if (completionHandler != nil) {
                completionHandler(FBAuthorizeResultUserDidNotLogout);
            }
        }
        if (![result isKindOfClass:[NSDictionary class]] && 
            [[result objectForKey:@"result"] boolValue] != true) {
            NSLog(@"%s: error during logout:%@",__PRETTY_FUNCTION__,result);
            if (completionHandler != nil) {
                completionHandler(FBAuthorizeResultUserDidNotLogout);
            }
        }
             
        
        self.accessToken = nil;
        self.expirationDate = nil;
        
        NSHTTPCookieStorage* cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray* facebookCookies = [cookies cookiesForURL:[NSURL URLWithString:@"http://login.facebook.com"]];
        
        for (NSHTTPCookie* cookie in facebookCookies) {
            [cookies deleteCookie:cookie];
        }
        
        if (completionHandler != nil) {
            completionHandler(FBAuthorizeResultUserDidLogout);
        }
        
    }];
}

#pragma mark - API requests methods
- (FBRequest*)buildRequestWithParams:(NSDictionary *)params {
    if ([params objectForKey:@"method"] == nil) {
        NSLog(@"%s:API Method must be specified",__PRETTY_FUNCTION__);
        return nil;
    }
    
    NSMutableDictionary *newParams = [params mutableCopy];

    NSString *methodName = [newParams objectForKey:@"method"];
    [newParams removeObjectForKey:@"method"];
    
    return [self buildRequestWithMethodName:methodName params:newParams httpMethod:@"GET"];
}

- (FBRequest*)buildRequestWithMethodName:(NSString *)methodName params:(NSDictionary *)params httpMethod:(NSString *)httpMethod {
    
    NSMutableDictionary *newParams = [params mutableCopy];
    [newParams setObject:@"json"          forKey:@"format"];
    [newParams setObject:kSDK             forKey:@"sdk"];
    [newParams setObject:kSDKVersion      forKey:@"sdk_version"];
    if ([self isSessionValid]) {
        [newParams setObject:self.accessToken forKey:@"access_token"];
    }
    
    NSString *fullURL = [kRestserverBaseURL stringByAppendingString:methodName];
    
    return [FBRequest requestWithURL:[NSURL URLWithString:fullURL] params:newParams httpMethod:httpMethod];
}

- (FBRequest*)buildRequestWithGraphPath:(NSString *)graphPath {
    return [self buildRequestWithGraphPath:graphPath params:[NSDictionary dictionary] httpMethod:@"GET"];
}

- (FBRequest*)buildRequestWithGraphPath:(NSString *)graphPath params:(NSDictionary *)params {
    return [self buildRequestWithGraphPath:graphPath params:params httpMethod:@"GET"];
}

- (FBRequest*)buildRequestWithGraphPath:(NSString *)graphPath params:(NSDictionary *)params httpMethod:(NSString *)httpMethod {
    NSMutableDictionary *newParams = [params mutableCopy];
    [newParams setObject:@"json"          forKey:@"format"];
    [newParams setObject:kSDK             forKey:@"sdk"];
    [newParams setObject:kSDKVersion      forKey:@"sdk_version"];
    if ([self isSessionValid]) {
        [newParams setObject:self.accessToken forKey:@"access_token"];
    }    
    
    NSURL *fullURL = [NSURL URLWithString:[kGraphBaseURL stringByAppendingString:graphPath]];
    
    return [FBRequest requestWithURL:fullURL params:newParams httpMethod:httpMethod];
}

#pragma mark - dialog methods
- (FBDialog *)buildDialogWithAction:(NSString *)action {
    return [self buildDialogWithAction:action params:[NSDictionary dictionary]];
}

- (FBDialog *)buildDialogWithAction:(NSString *)action params:(NSDictionary *)params {
    NSURL *dialogURL = [NSURL URLWithString:[kDialogBaseURL stringByAppendingString:action]];
    
    NSMutableDictionary *newParams = [params mutableCopy];
    
    [newParams setObject:@"touch"     forKey:@"display"];
    [newParams setObject:kSDKVersion  forKey:@"sdk"];
    [newParams setObject:kRedirectURL forKey:@"redirect_uri"];
    
    if (action == kLogin) {
        [newParams setObject:@"user_agent" forKey:@"type"];
        
        return [[[FBDialog alloc] initWithURL:dialogURL params:newParams] autorelease];
    } 
    else {
        [newParams setObject:self.appId forKey:@"app_id"];
        if ([self isSessionValid]) {
            [newParams setValue:[self.accessToken stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                      forKey:@"access_token"];
        }
        return [[[FBDialog alloc] initWithURL:dialogURL params:newParams] autorelease];
    }
}


- (BOOL)isSessionValid {
    return (self.accessToken != nil 
            && self.expirationDate != nil
            && [self.expirationDate compare:[NSDate date]] == NSOrderedDescending);
    
}


@end
