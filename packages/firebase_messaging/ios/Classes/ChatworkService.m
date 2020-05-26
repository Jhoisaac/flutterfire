//
//  ChatworkService.m
//  firebase_messaging
//
//  Created by Jhonatan Casaliglla on 11/19/19.
//

#import "ChatworkService.h"
#import "AmzwkHttpUtil.h"
#import "Constants.h"

@interface ChatworkService()

- (NSString *_Nonnull) getAuthHeader;

@end

@implementation ChatworkService {
    NSString *_key;
}

NSString *const SHARED_PREFERENCES_NAME = @"FlutterSharedPreferences";

- (void) saveMessageWithTextMessage:(NSString *)textMessage andChannelId:(NSString *)channelId andCreateAt:(NSString *_Nonnull)createAt andCompletionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    AmzwkHttpUtil *networkHelper = [[AmzwkHttpUtil alloc] initWithUrl: [NSString stringWithFormat: @"%@/%@/%@", __CHAT_API_DOMAIN, channelId, @"message/save"]];
    
    NSString *bodyParams =[NSString stringWithFormat:@"message=%@&type=%@&createAt=%@", textMessage, @"text", createAt];
    /*NSLog(@"bodyParams es: %@", bodyParams);*/
    //Convert the String to Data
    NSData *dataParams = [bodyParams dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *authToken = [self getAuthHeader];
    NSString *authValueHeader = [NSString stringWithFormat:@"Bearer %@", authToken];
    
    [networkHelper postDataWithParams:dataParams andHeaders:authValueHeader andContentType:@"application/json" andCompletionHandler:completionHandler];
}

- (NSString *) getAuthHeader {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *token = [prefs stringForKey:@"flutter.token"];
    
    return token;
}

@end
