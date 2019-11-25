//
//  AmzwkHttpUtil.m
//  firebase_messaging
//
//  Created by Jhonatan Casaliglla on 11/19/19.
//

#import "AmzwkHttpUtil.h"

@interface AmzwkHttpUtil()

- (NSData *_Nonnull) getBodyParamsWithJsonParams:(NSDictionary *_Nonnull)jsonParams;
- (int) clientHttpPostWithDataParams:(NSData *)dataParams headers:(NSString *)headers contentType:(NSString *)contentType completionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

@implementation AmzwkHttpUtil {
    NSString *_url;
}

- (instancetype) initWithUrl:(NSString *)url {
    self = [super init];
    if(self) {
        _url = url;
    }
    return self;
}

- (int) postDataWithParams:(NSData *)paramsData andHeaders:(NSString *)headers andContentType:(NSString *)contentType andCompletionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    NSLog(@"30 postDataWithParams() executed!");
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_url]];
    
    //create the Method "GET" or "POST"
    [urlRequest setHTTPMethod:@"POST"];
    
    //Apply authentication header
    [urlRequest addValue:headers forHTTPHeaderField:@"Authorizationz"];
    
    //Apply the data to the body
    [urlRequest setHTTPBody:paramsData];
    
    //NSLog(@"42 _url es: %@", _url);
    //NSLog(@"43 params es: %@", paramsData);
    //NSLog(@"44 headers es: %@", headers);
    //NSLog(@"45 contentType es: %@", contentType);

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:completionHandler];
    
    [dataTask resume];
    
    return 0;
}

- (int) postDataNotifyWithDataBodyParams:(NSArray *_Nonnull)dataBodyParams headers:(NSString *)headers contentType:(NSString *)contentType completionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    NSLog(@"56 postDataNotifyWithParams() executed!");
    [self sendToPlatformsWithBodyAndroid:[self getBodyParamsWithJsonParams:dataBodyParams[0]] bodyIOS:[self getBodyParamsWithJsonParams:dataBodyParams[1]] headers:headers contentType:contentType completionHandler:completionHandler];
    
    return 0;
}

- (NSData *_Nonnull) getBodyParamsWithJsonParams:(NSDictionary *_Nonnull)jsonParams {
    // Make sure that the above dictionary can be converted to JSON data
    if([NSJSONSerialization isValidJSONObject:jsonParams]) {
        // Convert the JSON object to NSData
        //NSData * httpBodyData = [NSJSONSerialization dataWithJSONObject:dataNotifyMap options:0 error:nil];
        NSLog(@"67 isValidJSONObject es true :)");
    }
    
    NSData * httpBodyData = [NSJSONSerialization dataWithJSONObject:jsonParams options:0 error:nil];
    
    NSLog(@"72 httpBodyData es: %@", httpBodyData);
    
    return httpBodyData;
}

- (int) sendToPlatformsWithBodyAndroid:(NSData *)bodyAndroid bodyIOS:(NSData *)bodyIOS headers:(NSString *)headers contentType:(NSString *)contentType completionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    NSLog(@"78 sendToPlatformsWithBodyAndroid() executed!");
    
    [self clientHttpPostWithDataParams:bodyIOS headers:headers contentType:contentType completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if(httpResponse.statusCode == 200) {
            NSLog(@"85 iOS data es: %@", data);
            NSLog(@"86 iOS response es: %@", response);
            
            NSError *parseError = nil;
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            NSLog(@"90 iOS The response is - %@",responseDictionary);
            NSInteger success = [[responseDictionary objectForKey:@"success"] integerValue];
            if(success == 1) {
                NSLog(@"93 iOS Login SUCCESS");
            } else {
                NSLog(@"95 iOS Login FAILURE");
            }
            
        } else {
            NSLog(@"99 iOS Error es: %@", error);
        }
    }];
    
    return [self clientHttpPostWithDataParams:bodyAndroid headers:headers contentType:contentType completionHandler:completionHandler];
}

- (int) clientHttpPostWithDataParams:(NSData *)dataParams headers:(NSString *)headers contentType:(NSString *)contentType completionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    NSLog(@"107 clientHttpPostWithDataParams() executed!");
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_url]];
    
    //create the Method "GET" or "POST"
    [urlRequest setHTTPMethod:@"POST"];
    
    //Apply authentication header
    [urlRequest addValue:headers forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    //Apply the data to the body
    [urlRequest setHTTPBody:dataParams];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:completionHandler];
    
    [dataTask resume];
    
    return 0;
}

@end
