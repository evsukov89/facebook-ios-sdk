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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol FBDialogDelegate;

typedef enum {
    FBDialogCompletionStatusSuccess = 0,
    FBDialogCompletionStatusCancel,
    FBDialogCompletionStatusError
} FBDialogCompletionStatus;

typedef void (^FBDialogComletionHandler) (FBDialogCompletionStatus comletionStatus, NSURL *url, NSError *error);
typedef BOOL (^FBDialogShouldOpenURLInExternalBrowser) (NSURL *url);


/**
 * Do not use this interface directly, instead, use dialog in Facebook.h
 *
 * Facebook dialog interface for start the facebook webView UIServer Dialog.
 */
@interface FBDialog : UIView

@property(nonatomic, retain) NSDictionary* params;
@property(nonatomic,   copy) NSString* title;
@property(nonatomic,   copy) FBDialogComletionHandler comletionHandler;
@property(nonatomic,   copy) FBDialogShouldOpenURLInExternalBrowser shouldOpenURLInExternalBrowserHandler;

/**
 * Find a specific parameter from the url
 */
+ (NSString *)getParamFromUrl:(NSURL *)url paramName:(NSString *)paramName;

+ (NSURL *)buildURL:(NSURL *)baseURL withParams:(NSDictionary *)aParams;

- (id)initWithURL:(NSURL *)dialogURL params:(NSDictionary *)params;

- (void)show;
- (void)showWithCompletionHandler:(FBDialogComletionHandler)comletionHandler;

- (void)dismissAnimated:(BOOL)animated;

@end
