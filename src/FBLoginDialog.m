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
#import "FBLoginDialog.h"

@interface FBLoginDialog()

@property (nonatomic, copy) FBDialogComletionHandler originalCompletionHandler;

@end

@implementation FBLoginDialog

@synthesize originalCompletionHandler;
@synthesize loginCompletionHandler;

///////////////////////////////////////////////////////////////////////////////////////////////////
// FBDialog

/**
 * Override comletionHandler getter and setter to do all login dialog magic
 */
- (FBDialogComletionHandler)comletionHandler {
    return self.originalCompletionHandler;
}

- (void)setComletionHandler:(FBDialogComletionHandler)aComletionHandler {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    
    self.originalCompletionHandler = aComletionHandler;

    FBDialogComletionHandler overridenCompletionHandler = ^(FBDialogCompletionStatus completionStatus, NSURL *url, NSError *error) {
        if (completionStatus == FBDialogCompletionStatusSuccess) {
            NSString *token = [[self class] getParamFromUrl:url paramName:@"access_token="];
            NSString *expTime = [[self class] getParamFromUrl:url paramName:@"expires_in="];
                        
            NSDate *expirationDate = [expTime integerValue] == 0 ? [NSDate distantFuture] : [NSDate dateWithTimeIntervalSinceNow:[expTime integerValue]];
            
            if ((token == (NSString *)[NSNull null]) || (token.length == 0)) {
                
                if (self.originalCompletionHandler != nil) {
                    self.originalCompletionHandler(FBDialogCompletionStatusCancel,url,error);
                }
                if (self.loginCompletionHandler != nil) {
                    self.loginCompletionHandler(FBLoginDialogCompletionStatusCanceledByUser,nil,nil,nil);
                }
                
            } 
            else {
                if (self.originalCompletionHandler != nil) {
                    self.originalCompletionHandler(FBDialogCompletionStatusSuccess,url,error);
                }
                if (self.loginCompletionHandler != nil) {
                    self.loginCompletionHandler(FBLoginDialogCompletionStatusSuccess,token,expirationDate,nil);
                }
            }            
        }
        else if (completionStatus == FBDialogCompletionStatusCancel) {
            if (self.originalCompletionHandler != nil) {
                self.originalCompletionHandler(FBDialogCompletionStatusCancel,url,error);
            }
            if (self.loginCompletionHandler != nil) {
                self.loginCompletionHandler(FBLoginDialogCompletionStatusCanceledByUser,nil,nil,nil);
            }            
        }
        else if (completionStatus == FBDialogCompletionStatusError) {
            if (self.originalCompletionHandler != nil) {
                self.originalCompletionHandler(FBDialogCompletionStatusError,url,error);
            }            
            if (self.loginCompletionHandler != nil) {
                self.loginCompletionHandler(FBLoginDialogCompletionStatusError,nil,nil,error);
            }            
        }
    };
    
    super.comletionHandler = overridenCompletionHandler;
}

- (void)show {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    if (self.comletionHandler == nil) {
        self.comletionHandler = ^(FBDialogCompletionStatus completionStatus, NSURL *url, NSError *error){ };
    }
    [super show];
}

//- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
//    if (!(([error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -999) ||
//          ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102))) {
//        [super webView:webView didFailLoadWithError:error];
//        if ([_loginDelegate respondsToSelector:@selector(fbDialogNotLogin:)]) {
//            [_loginDelegate fbDialogNotLogin:NO];
//        }
//    }
//}

@end
