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

#import "FBRequest.h"
#import "JSON.h"

#pragma mark - constants
static NSString* kUserAgent = @"FacebookConnect";
static NSString* kStringBoundary = @"3i2ndDfv2rTHiSisAbouNdArYfORhtTPEefj3q2f";
static const int kGeneralErrorCode = 10000;

static const NSTimeInterval kTimeoutInterval = 180.0;


#pragma mark - private interface declaration
@interface FBRequest ()

- (NSError *)formError:(NSInteger)code 
              userInfo:(NSDictionary *)errorData;

- (NSMutableData *)generatePostBody;
- (void)appendString:(NSString *)string toBody:(NSMutableData *)body;
- (id)parseJsonResponse:(NSData *)data error:(NSError **)error;

@property (nonatomic, assign) BOOL loading;

@end

#pragma mark - implementation
@implementation FBRequest

#pragma mark - public class methods
+ (NSString *)serializeURL:(NSString *)baseUrl params:(NSDictionary *)params {
    return [self serializeURL:baseUrl params:params httpMethod:@"GET"];
}

+ (NSString*)serializeURL:(NSString *)baseUrl
                   params:(NSDictionary *)params
               httpMethod:(NSString *)httpMethod {
    
    NSURL* parsedURL = [NSURL URLWithString:baseUrl];
    NSString* queryPrefix = parsedURL.query ? @"&" : @"?";
    
    NSMutableArray* pairs = [NSMutableArray array];
    for (NSString* key in [params keyEnumerator]) {
        if (([[params valueForKey:key] isKindOfClass:[UIImage class]])
            ||([[params valueForKey:key] isKindOfClass:[NSData class]])) {
            if ([httpMethod isEqualToString:@"GET"]) {
                NSLog(@"can not use GET to upload a file");
            }
            continue;
        }
        
        NSString* escapedValue = (NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                                     NULL, /* allocator */
                                                                                     (CFStringRef)[params objectForKey:key],
                                                                                     NULL, /* charactersToLeaveUnescaped */
                                                                                     (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                     kCFStringEncodingUTF8);
        
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, escapedValue]];
        [escapedValue release];
    }
    NSString* query = [pairs componentsJoinedByString:@"&"];
    
    return [NSString stringWithFormat:@"%@%@%@", baseUrl, queryPrefix, query];
}

#pragma mark - properties
@synthesize url, params, httpMethod, connection;
@synthesize responce, responceData, completionHandler;
@synthesize uploadProgressHandler, downloadProgressHandler;

@synthesize loading;

#pragma mark - init & dealloc
+ (FBRequest*)requestWithURL:(NSURL*)anUrl
                      params:(NSDictionary *)aParams 
                  httpMethod:(NSString *)aHttpMethod
{
    FBRequest* request = [[[FBRequest alloc] initWithURL:anUrl
                                                  params:aParams 
                                              httpMethod:aHttpMethod] autorelease];
    return request;
}

- (id)initWithURL:(NSURL*)anUrl
           params:(NSDictionary *)aParams 
       httpMethod:(NSString *)aHttpMethod 
{    
    if ((self = [super init])) {
        self.url = anUrl;
        self.params = aParams;
        self.httpMethod = aHttpMethod;
        self.loading = NO;
    }
    return self;
}

- (void)dealloc {
    self.params = nil;
    self.url = nil;
    self.httpMethod = nil;
    
    [self.connection cancel];
    self.connection = nil;
    self.responce = nil;
    self.responceData = nil;
    self.completionHandler = nil;
    self.uploadProgressHandler = nil;
    self.downloadProgressHandler = nil;
    
    [super dealloc];
}

#pragma mark - request execution methods
- (void)performWithCompletionHandler:(FBRequestCompletionHandler)aCompletionHandler {
    self.completionHandler = aCompletionHandler;
    [self perform];
}

- (void)perform {
    if ([self isExecuting]) return;
    
    self.loading = YES;

    NSString* urlString = [[self class] serializeURL:[self.url absoluteString] params:self.params httpMethod:self.httpMethod];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:kTimeoutInterval];
    [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
    [request setHTTPMethod:self.httpMethod];
    
    if ([self.httpMethod isEqualToString: @"POST"]) {
        NSString* contentType = [NSString
                                 stringWithFormat:@"multipart/form-data; boundary=%@", kStringBoundary];
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
        
        [request setHTTPBody:[self generatePostBody]];
    }
    
    [self retain];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}
- (BOOL)isExecuting {
    return self.loading;
}


#pragma mark - private methods
- (void)appendString:(NSString *)string toBody:(NSMutableData *)body {
    [body appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSMutableData *)generatePostBody {
    NSMutableData *body = [NSMutableData data];
    NSString *endLine = [NSString stringWithFormat:@"\r\n--%@\r\n", kStringBoundary];
    NSMutableDictionary *dataDictionary = [NSMutableDictionary dictionary];
    
    [self appendString:[NSString stringWithFormat:@"--%@\r\n", kStringBoundary] toBody:body];
    
    for (id key in [self.params keyEnumerator]) {
        
        if (([[self.params valueForKey:key] isKindOfClass:[UIImage class]])
            ||([[self.params valueForKey:key] isKindOfClass:[NSData class]])) {
            
            [dataDictionary setObject:[self.params valueForKey:key] forKey:key];
            continue;
            
        }
        [self appendString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] toBody:body];
        
        [self appendString:[self.params valueForKey:key] toBody:body];
        [self appendString:endLine toBody:body];
    }
    
    if ([dataDictionary count] > 0) {
        for (id key in dataDictionary) {
            NSObject *dataParam = [dataDictionary valueForKey:key];
            if ([dataParam isKindOfClass:[UIImage class]]) {
                NSData* imageData = UIImagePNGRepresentation((UIImage*)dataParam);
                [self appendString:[NSString stringWithFormat:@"Content-Disposition: form-data; filename=\"%@\"\r\n", key] 
                            toBody:body];
                [self appendString:[NSString stringWithString:@"Content-Type: image/png\r\n\r\n"] 
                            toBody:body];
                [body appendData:imageData];
            } else {
                NSAssert([dataParam isKindOfClass:[NSData class]],@"dataParam must be a UIImage or NSData");
                [self appendString:[NSString stringWithFormat:@"Content-Disposition: form-data; filename=\"%@\"\r\n", key] 
                            toBody:body];
                [self appendString:[NSString stringWithString:@"Content-Type: content/unknown\r\n\r\n"] 
                            toBody:body];
                [body appendData:(NSData*)dataParam];
            }
            [self appendString:endLine toBody:body];
        }
    }
    
    return body;
}

- (NSError *)formError:(NSInteger)code userInfo:(NSDictionary *)errorData {
    return [NSError errorWithDomain:@"facebookErrDomain" code:code userInfo:errorData];
}

- (id)parseJsonResponse:(NSData *)data error:(NSError **)error {
    
    NSString* responseString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    
    SBJSON *jsonParser = [[SBJSON new] autorelease];
    if ([responseString isEqualToString:@"true"]) {
        return [NSDictionary dictionaryWithObject:@"true" forKey:@"result"];
    } else if ([responseString isEqualToString:@"false"]) {
        if (error != nil) {
            *error = [self formError:kGeneralErrorCode
                            userInfo:[NSDictionary
                                      dictionaryWithObject:@"This operation can not be completed"
                                      forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    
    
    id result = [jsonParser objectWithString:responseString];
    
    if (![result isKindOfClass:[NSArray class]]) {
        if ([result objectForKey:@"error"] != nil) {
            if (error != nil) {
                *error = [self formError:kGeneralErrorCode
                                userInfo:result];
            }
            return nil;
        }
        
        if ([result objectForKey:@"error_code"] != nil) {
            if (error != nil) {
                *error = [self formError:[[result objectForKey:@"error_code"] intValue] userInfo:result];
            }
            return nil;
        }
        
        if ([result objectForKey:@"error_msg"] != nil) {
            if (error != nil) {
                *error = [self formError:kGeneralErrorCode userInfo:result];
            }
        }
        
        if ([result objectForKey:@"error_reason"] != nil) {
            if (error != nil) {
                *error = [self formError:kGeneralErrorCode userInfo:result];
            }
        }
    }
    
    return result;
}


#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)aResponse {
    if (aConnection == self.connection) {
        self.responce = aResponse;
        
        if ([self.responceData length] != 0) 
            [self.responceData setLength:0];
    }
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data {
    if (aConnection == self.connection) {
        
        if (!self.responceData) 
            self.responceData = [NSMutableData data];
        
        [self.responceData appendData:data];
        
        if (self.downloadProgressHandler != nil && self.responce != nil && [self.responce expectedContentLength] != NSURLResponseUnknownLength) {
            self.downloadProgressHandler((float)[self.responceData length]/(float)[self.responce expectedContentLength]);
        }
    }
}

- (void)connection:(NSURLConnection *)aConnection didSendBodyData:(NSInteger)bytesWritten 
 totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (aConnection == self.connection) {
        if (self.uploadProgressHandler != nil) {
            self.uploadProgressHandler((float)totalBytesWritten/(float)totalBytesExpectedToWrite);
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
    if (aConnection == self.connection) {
        if (self.completionHandler != nil) {
            NSError* error = nil;
            id result = [self parseJsonResponse:self.responceData error:&error];
            
            self.completionHandler(self.responce,result,error);
        }
        
        self.loading = NO;
        [self release];
    }
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
    if (aConnection == self.connection) {
        if (self.completionHandler != nil) {
            self.completionHandler(nil, nil, error);
        }
        
        self.loading = NO;
        [self release];
    }
}

@end
