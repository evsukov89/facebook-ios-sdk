/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FBLoginDialog.h"
#import "FBRequest.h"

typedef enum {
    FBAuthorizeResultUserDidLogin = 0,
    FBAuthorizeResultUserDidNotLogin,
    FBAuthorizeResultUserDidCanceled,
    FBAuthorizeResultUserDidLogout
} FBAuthorizeResult;

typedef void (^FBAuthorizeCompletionHandler) (FBAuthorizeResult result);

@protocol FBSessionDelegate;

/**
 * Main Facebook interface for interacting with the Facebook developer API.
 * Provides methods to log in and log out a user, make requests using the REST
 * and Graph APIs, and start user interface interactions (such as
 * pop-ups promoting for credentials, permissions, stream posts, etc.)
 */
@interface Facebook : NSObject

@property(nonatomic, retain) NSString *appId;
@property(nonatomic, retain) NSString *localAppId;

@property(nonatomic, retain) NSString *accessToken;
@property(nonatomic, retain) NSDate *expirationDate;
@property(nonatomic, retain) NSArray *permissions;

- (id)initWithAppId:(NSString *)anAppId;

- (void)authorizeWithPersmissions:(NSArray*)permissions
                completionHandler:(FBAuthorizeCompletionHandler)completionHandler;

/**
 * Starts a dialog which prompts the user to log in to Facebook and grant
 * the requested permissions to the application.
 *
 * If the device supports multitasking, we use fast app switching to show
 * the dialog in the Facebook app or, if the Facebook app isn't installed,
 * in Safari (this enables single sign-on by allowing multiple apps on
 * the device to share the same user session).
 * When the user grants or denies the permissions, the app that
 * showed the dialog (the Facebook app or Safari) redirects back to
 * the calling application, passing in the URL the access token
 * and/or any other parameters the Facebook backend includes in
 * the result (such as an error code if an error occurs).
 *
 * See http://developers.facebook.com/docs/authentication/ for more details.
 *
 * Also note that requests may be made to the API without calling
 * authorize() first, in which case only public information is returned.
 *
 * @param permissions
 *            A list of permission required for this application: e.g.
 *            "read_stream", "publish_stream", or "offline_access". see
 *            http://developers.facebook.com/docs/authentication/permissions
 *            This parameter should not be null -- if you do not require any
 *            permissions, then pass in an empty String array.
 * @param localAppId
 *            localAppId is a string of lowercase letters that is
 *            appended to the base URL scheme used for SSO. For example,
 *            if your facebook ID is "350685531728" and you set localAppId to
 *            "abcd", the Facebook app will expect your application to bind to
 *            the following URL scheme: "fb350685531728abcd".
 *            This is useful if your have multiple iOS applications that
 *            share a single Facebook application id (for example, if you
 *            have a free and a paid version on the same app) and you want
 *            to use SSO with both apps. Giving both apps different
 *            localAppId values will allow the Facebook app to disambiguate
 *            their URL schemes and always redirect the user back to the
 *            correct app, even if both the free and the app is installed
 *            on the device.
 *            localAppId is supported on version 3.4.1 and above of the Facebook
 *            app. If the user has an older version of the Facebook app
 *            installed and your app uses localAppId parameter, the SDK will
 *            proceed as if the Facebook app isn't installed on the device
 *            and redirect the user to Safari.
 * @param completionHandler
 *            Block callback
 */
- (void)authorizeWithPersmissions:(NSArray*)permissions
                       localAppId:(NSString *)localAppId
                completionHandler:(FBAuthorizeCompletionHandler)completionHandler;


/**
 * Invalidate the current user session by removing the access token in
 * memory, clearing the browser cookie, and calling auth.expireSession
 * through the API.
 *
 * Note that this method dosen't unauthorize the application --
 * it just invalidates the access token. To unauthorize the application,
 * the user must remove the app in the app settings page under the privacy
 * settings screen on facebook.com.
 *
 * @param delegate
 *            Callback interface for notifying the calling application when
 *            the application has logged out
 */
- (void)logoutWithCompletionHandler:(FBAuthorizeCompletionHandler)completionHandler;

/**
 * @return boolean - whether this object has an non-expired session token
 */
- (BOOL)isSessionValid;

/**
 * This function processes the URL the Facebook application or Safari used to
 * open your application during a single sign-on flow.
 *
 * You MUST call this function in your UIApplicationDelegate's handleOpenURL
 * method (see
 * http://developer.apple.com/library/ios/#documentation/uikit/reference/UIApplicationDelegate_Protocol/Reference/Reference.html
 * for more info).
 *
 * This will ensure that the authorization process will proceed smoothly once the
 * Facebook application or Safari redirects back to your application.
 *
 * @param URL the URL that was passed to the application delegate's handleOpenURL method.
 *
 * @return YES if the URL starts with 'fb[app_id]://authorize and hence was handled
 *   by SDK, NO otherwise.
 */
- (BOOL)handleOpenURL:(NSURL *)url;


#pragma mark - API requests methods
/**
 * Makes an object to call Facebook's REST API with the given
 * parameters. One of the parameter keys must be "method" and its value
 * should be a valid REST server API method.
 *
 * See http://developers.facebook.com/docs/reference/rest/
 *
 * @param parameters
 *            Key-value pairs of parameters to the request. Refer to the
 *            documentation: one of the parameters must be "method".
 * @return FBRequest*
 *            Returns a pointer to the FBRequest object.
 */
- (FBRequest*)buildRequestWithParams:(NSDictionary *)params;

/**
 * Makes an object to call Facebook's REST API with the given method name and
 * parameters.
 *
 * See http://developers.facebook.com/docs/reference/rest/
 *
 *
 * @param methodName
 *             a valid REST server API method.
 * @param parameters
 *            Key-value pairs of parameters to the request. Refer to the
 *            documentation: one of the parameters must be "method". To upload
 *            a file, you should specify the httpMethod to be "POST" and the
 *            “params” you passed in should contain a value of the type
 *            (UIImage *) or (NSData *) which contains the content that you
 *            want to upload
 * @return FBRequest*
 *            Returns a pointer to the FBRequest object.
 */
- (FBRequest*)buildRequestWithMethodName:(NSString *)methodName
                             params:(NSDictionary *)params
                         httpMethod:(NSString *)httpMethod;

/**
 * Make a request to the Facebook Graph API without any parameters.
 *
 * See http://developers.facebook.com/docs/api
 *
 * @param graphPath
 *            Path to resource in the Facebook graph, e.g., to fetch data
 *            about the currently logged authenticated user, provide "me",
 *            which will fetch http://graph.facebook.com/me
 * @return FBRequest*
 *            Returns a pointer to the FBRequest object.
 */
- (FBRequest*)buildRequestWithGraphPath:(NSString *)graphPath;

/**
 * Make a request to the Facebook Graph API with the given string
 * parameters using an HTTP GET (default method).
 *
 * See http://developers.facebook.com/docs/api
 *
 *
 * @param graphPath
 *            Path to resource in the Facebook graph, e.g., to fetch data
 *            about the currently logged authenticated user, provide "me",
 *            which will fetch http://graph.facebook.com/me
 * @param parameters
 *            key-value string parameters, e.g. the path "search" with
 *            parameters "q" : "facebook" would produce a query for the
 *            following graph resource:
 *            https://graph.facebook.com/search?q=facebook
 * @return FBRequest*
 *            Returns a pointer to the FBRequest object.
 */
- (FBRequest*)buildRequestWithGraphPath:(NSString *)graphPath
                            params:(NSDictionary *)params;

/**
 * Make a request to the Facebook Graph API with the given
 * HTTP method and string parameters. Note that binary data parameters
 * (e.g. pictures) are not yet supported by this helper function.
 *
 * See http://developers.facebook.com/docs/api
 *
 *
 * @param graphPath
 *            Path to resource in the Facebook graph, e.g., to fetch data
 *            about the currently logged authenticated user, provide "me",
 *            which will fetch http://graph.facebook.com/me
 * @param parameters
 *            key-value string parameters, e.g. the path "search" with
 *            parameters {"q" : "facebook"} would produce a query for the
 *            following graph resource:
 *            https://graph.facebook.com/search?q=facebook
 *            To upload a file, you should specify the httpMethod to be
 *            "POST" and the “params” you passed in should contain a value
 *            of the type (UIImage *) or (NSData *) which contains the
 *            content that you want to upload
 * @param httpMethod
 *            http verb, e.g. "GET", "POST", "DELETE"
 * @return FBRequest*
 *            Returns a pointer to the FBRequest object.
 */
- (FBRequest*)buildRequestWithGraphPath:(NSString *)graphPath
                                 params:(NSDictionary *)params
                             httpMethod:(NSString *)httpMethod;

#pragma mark - dialog
- (FBDialog *)buildDialogWithAction:(NSString *)action;

/**
 * Generate a UI dialog for the request action with the provided parameters.
 *
 * @param action
 *            String representation of the desired method: e.g. "login",
 *            "feed", ...
 * @param parameters
 *            key-value string parameters
 */
- (FBDialog *)buildDialogWithAction:(NSString *)action
                             params:(NSDictionary *)params;


@end
