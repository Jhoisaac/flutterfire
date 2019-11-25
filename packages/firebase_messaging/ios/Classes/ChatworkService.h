//
//  ChatworkService.h
//  firebase_messaging
//
//  Created by Jhonatan Casaliglla on 11/19/19.
//

#ifndef ChatworkService_h
#define ChatworkService_h

#import <Foundation/Foundation.h>

@interface ChatworkService : NSObject

- (int) saveMessageWithTextMessage:(NSString *_Nonnull)textMessage andChannelId:(NSString *_Nonnull)channelId andCompletionHandler:(void (^_Nonnull)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

#endif /* ChatworkService_h */
