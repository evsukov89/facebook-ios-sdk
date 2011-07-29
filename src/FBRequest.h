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

typedef void (^FBRequestCompletionHandler) (NSURLResponse* responce,id result,NSError* error);

typedef void (^FBRequestProgessHandler) (float progress);

/**
 * Do not use this interface directly, instead, use method in Facebook.h
 */
@interface FBRequest : NSObject

@property (nonatomic, retain) NSURL *url;
@property (nonatomic, retain) NSDictionary *params;
@property (nonatomic, retain) NSString *httpMethod;

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSURLResponse *responce;
@property (nonatomic, retain) NSMutableData *responceData;
@property (nonatomic, copy) FBRequestCompletionHandler completionHandler;
@property (nonatomic, copy) FBRequestProgessHandler uploadProgressHandler;
@property (nonatomic, copy) FBRequestProgessHandler downloadProgressHandler;

+ (NSString*)serializeURL:(NSString *)baseUrl
                   params:(NSDictionary *)params;

+ (NSString*)serializeURL:(NSString *)baseUrl
                   params:(NSDictionary *)params
               httpMethod:(NSString *)httpMethod;


+ (FBRequest*)requestWithURL:(NSURL*)url
                      params:(NSDictionary *)aParams 
                  httpMethod:(NSString *)aHttpMethod;

- (id)initWithURL:(NSURL*)anUrl
           params:(NSDictionary *)aParams 
       httpMethod:(NSString *)aHttpMethod;

- (void)perform;
- (void)performWithCompletionHandler:(FBRequestCompletionHandler)completionHandler;

- (BOOL)isExecuting;

@end

