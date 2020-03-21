//
//  AmzwkHttpUtil.h
//  firebase_messaging
//
//  Created by Jhonatan Casaliglla on 11/19/19.
//

#ifndef AmzwkHttpUtil_h
#define AmzwkHttpUtil_h

#import <Foundation/Foundation.h>

@interface AmzwkHttpUtil : NSObject

- (instancetype _Nonnull ) initWithUrl:(NSString *_Nonnull)url;

- (int) postDataWithParams:(NSData *_Nonnull)params andHeaders:(NSString *_Nonnull)headers andContentType:(NSString *_Nonnull)contentType andCompletionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

- (int) postDataNotifyWithDataBodyParams:(NSData *_Nonnull)params headers:(NSString *_Nonnull)headers contentType:(NSString *_Nonnull)contentType completionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

#endif /* AmzwkHttpUtil_h */