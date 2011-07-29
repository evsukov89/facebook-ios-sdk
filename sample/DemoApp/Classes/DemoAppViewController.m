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


#import "DemoAppViewController.h"
#import "FBConnect.h"

// Your Facebook APP Id must be set before running this example
// See http://www.facebook.com/developers/createapp.php
// Also, your application must bind to the fb[app_id]:// URL
// scheme (substitue [app_id] for your real Facebook app id).
static NSString* kAppId = @"144552878926641";

@implementation DemoAppViewController

@synthesize label = _label, facebook = _facebook;

//////////////////////////////////////////////////////////////////////////////////////////////////
// UIViewController

/**
 * initialization
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (!kAppId) {
        NSLog(@"missing app id!");
        exit(1);
        return nil;
    }
    
    
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        _permissions =  [[NSArray arrayWithObjects:
                          @"read_stream", @"publish_stream", @"offline_access",nil] retain];
    }
    
    return self;
}

/**
 * Set initial view
 */
- (void)viewDidLoad {
    _facebook = [[Facebook alloc] initWithAppId:kAppId];
    [self.label setText:@"Please log in"];
    _getUserInfoButton.hidden = YES;
    _getPublicInfoButton.hidden = YES;
    _publishButton.hidden = YES;
    _uploadPhotoButton.hidden = YES;
    _fbButton.isLoggedIn = NO;
    [_fbButton updateImage];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (void)dealloc {
    [_label release];
    [_fbButton release];
    [_getUserInfoButton release];
    [_getPublicInfoButton release];
    [_publishButton release];
    [_uploadPhotoButton release];
    [_facebook release];
    [_permissions release];
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

/**
 * Show the authorization dialog.
 */
- (void)login {
    //[_facebook authorize:_permissions delegate:self];
    [_facebook authorizeWithPersmissions:_permissions completionHandler:^(FBAuthorizeResult result) {
        if (result == FBAuthorizeResultUserDidLogin) {
            [self.label setText:@"logged in"];
            _getUserInfoButton.hidden = NO;
            _getPublicInfoButton.hidden = NO;
            _publishButton.hidden = NO;
            _uploadPhotoButton.hidden = NO;
            _fbButton.isLoggedIn = YES;
            [_fbButton updateImage];            
        }
        else if (result == FBAuthorizeResultUserDidCanceled) {
            NSLog(@"did not login");
        }
    }];
}

/**
 * Invalidate the access token and clear the cookie.
 */
- (void)logout {
    //[_facebook logout:self];
    [_facebook logoutWithCompletionHandler:^(FBAuthorizeResult result){
        if (result != FBAuthorizeResultUserDidLogout) {
            NSLog(@"%s:error during logout",__PRETTY_FUNCTION__);
            return;
        }
        NSLog(@"%s:logged out",__PRETTY_FUNCTION__);
    }];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// IBAction

/**
 * Called on a login/logout button click.
 */
- (IBAction)fbButtonClick:(id)sender {
    if (_fbButton.isLoggedIn) {
        [self logout];
    } else {
        [self login];
    }
}

/**
 * Make a Graph API Call to get information about the current logged in user.
 */
- (IBAction)getUserInfo:(id)sender {
    [[_facebook buildRequestWithGraphPath:@"me"] 
     performWithCompletionHandler:^(NSURLResponse* response, id result, NSError* error){
         NSLog(@"%s:%@ - %@ - %@",__PRETTY_FUNCTION__,response,result,error);
         if (error) {
             self.label.text = [error localizedDescription];
             return;
         }
         
         if ([result isKindOfClass:[NSArray class]]) {
             result = [result objectAtIndex:0];
         }
         
         self.label.text = [result objectForKey:@"name"];
     }];
}


/**
 * Make a REST API call to get a user's name using FQL.
 */
- (IBAction)getPublicInfo:(id)sender {    
    NSMutableDictionary* params = [NSMutableDictionary 
                                   dictionaryWithObject:@"SELECT uid,name FROM user WHERE uid=4" 
                                   forKey:@"query"];
    
    FBRequest *request = [_facebook buildRequestWithMethodName:@"fql.query" params:params httpMethod:@"POST"];
    [request performWithCompletionHandler:^(NSURLResponse* response, id result, NSError* error){
        NSLog(@"%s:%@ - %@ - %@",__PRETTY_FUNCTION__,response,result,error);
        if (error) {
            NSLog(@"%s:%@",__PRETTY_FUNCTION__,error);
            self.label.text = [error localizedDescription];
            return;
        }
        
        if ([result isKindOfClass:[NSArray class]]) {
            result = [result objectAtIndex:0];
        }
        
        [self.label setText:[result objectForKey:@"name"]];
    }];
}

/**
 * Open an inline dialog that allows the logged in user to publish a story to his or
 * her wall.
 */
- (IBAction)publishStream:(id)sender {
    
    SBJSON *jsonWriter = [[SBJSON new] autorelease];
    
    NSDictionary* actionLinks = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           @"Always Running",@"text",@"http://itsti.me/",@"href", nil], nil];
    
    NSString *actionLinksStr = [jsonWriter stringWithObject:actionLinks];
    NSDictionary* attachment = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"a long run", @"name",
                                @"The Facebook Running app", @"caption",
                                @"it is fun", @"description",
                                @"http://itsti.me/", @"href", nil];
    NSString *attachmentStr = [jsonWriter stringWithObject:attachment];
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"Share on Facebook",  @"user_message_prompt",
                                   actionLinksStr, @"action_links",
                                   attachmentStr, @"attachment",
                                   nil];
    
    FBDialog *dialog = [_facebook buildDialogWithAction:@"feed" params:params];
    
    [dialog showWithCompletionHandler:^(FBDialogCompletionStatus comletionStatus, NSURL *url, NSError *error){
        if (comletionStatus != FBDialogCompletionStatusSuccess){
            NSLog(@"%s:%@",__PRETTY_FUNCTION__,error);
            return;
        }
        [self.label setText:@"publish successfully"];
    }];
}

/**
 * Upload a photo.
 */
- (IBAction)uploadPhoto:(id)sender {
    NSString *path = @"http://www.facebook.com/images/devsite/iphone_connect_btn.jpg";
    NSURL *url = [NSURL URLWithString:path];
    NSData *data = [NSData dataWithContentsOfURL:url];
    UIImage *img  = [[UIImage alloc] initWithData:data];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   img, @"picture",
                                   nil];
    
    FBRequest *request = [_facebook buildRequestWithGraphPath:@"me/photos" params:params httpMethod:@"POST"];
    [request performWithCompletionHandler:^(NSURLResponse* response, id result, NSError* error){
        NSLog(@"%s:%@ - %@ - %@",__PRETTY_FUNCTION__,response,result,error);
        if (error) {
            NSLog(@"%s:%@",__PRETTY_FUNCTION__,error);
            self.label.text = [error localizedDescription];
            return;
        }
        
        if ([result isKindOfClass:[NSArray class]]) {
            result = [result objectAtIndex:0];
        }
        
        if ([result objectForKey:@"owner"]) {
            [self.label setText:@"Photo upload Success"];
        } 
        
    }];
    
    [img release];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


///**
// * Called when the user has logged in successfully.
// */
//- (void)fbDidLogin {
//    [self.label setText:@"logged in"];
//    _getUserInfoButton.hidden = NO;
//    _getPublicInfoButton.hidden = NO;
//    _publishButton.hidden = NO;
//    _uploadPhotoButton.hidden = NO;
//    _fbButton.isLoggedIn = YES;
//    [_fbButton updateImage];
//}
//
///**
// * Called when the user canceled the authorization dialog.
// */
//-(void)fbDidNotLogin:(BOOL)cancelled {
//    NSLog(@"did not login");
//}

/**
 * Called when the request logout has succeeded.
 */
- (void)fbDidLogout {
    [self.label setText:@"Please log in"];
    _getUserInfoButton.hidden    = YES;
    _getPublicInfoButton.hidden   = YES;
    _publishButton.hidden        = YES;
    _uploadPhotoButton.hidden = YES;
    _fbButton.isLoggedIn         = NO;
    [_fbButton updateImage];
}

@end
