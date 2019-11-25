// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FirebaseMessagingPlugin.h"
#import "UserAgent.h"

#import "Firebase/Firebase.h"

#import "ChatworkService.h"
#import "MessagingService.h"

//#import <UserNotifications/UserNotifications.h>   flutter 1.10.2

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FLTFirebaseMessagingPlugin () <FIRMessagingDelegate, UNUserNotificationCenterDelegate>

- (void) sendNotificationWithTitle:(NSString *_Nonnull)title body:(NSString *_Nonnull)body userId:(NSString *_Nonnull)userId channelId:(NSString *_Nonnull)channelId color:(NSString *_Nonnull)color userImage:(NSString *_Nonnull)userImage action:(NSString *_Nonnull)action fromId:(NSString *_Nonnull)fromId codPedido:(NSString *_Nonnull)codPedido description:(NSString *_Nonnull)description estadoPedido:(NSString *_Nonnull)estadoPedido valorPedido:(NSString *_Nonnull)valorPedido dataChat:(NSDictionary *_Nonnull)dataChat;

- (NSDictionary *_Nonnull) getDataChatWithChannelId:(NSString *_Nonnull)channelId messageText:(NSString *_Nonnull)messageText topicSenderId:(NSString *_Nonnull)topicSenderId senderId:(NSString *_Nonnull)senderId tipoUser:(NSString *_Nonnull)tipoUser pedido:(NSDictionary *_Nonnull)pedido logoProveedor:(NSString *_Nonnull)logoProveedor foto:(NSString *_Nonnull)foto currentPage:(NSString *_Nonnull)currentPage;

@end
#endif

static FlutterError *getFlutterError(NSError *error) {
  if (error == nil) return nil;
  return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %ld", error.code]
                             message:error.domain
                             details:error.localizedDescription];
}

@implementation FLTFirebaseMessagingPlugin {
  FlutterMethodChannel *_channel;
  NSDictionary *_launchNotification;
  BOOL _resumingFromBackground;
}

NSString *const kGCMMessageIDKey = @"gcm.message_id";

NSString *const replyAction = @"REPLY_IDENTIFIER";
NSString *const generalCategory = @"FLUTTER_NOTIFICATION_CLICK";
NSString *const SERVER_DOMAIN = @"amazingwork.com";
NSString *const COLOR_PROVEEDOR = @"0x4caf50";
NSString *const COLOR_CONSUMIDOR = @"0x0288D1";

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    NSLog(@"47 registerWithRegistrar() executed!");
    
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_messaging"
                                  binaryMessenger:[registrar messenger]];
  FLTFirebaseMessagingPlugin *instance =
      [[FLTFirebaseMessagingPlugin alloc] initWithChannel:channel];
  [registrar addApplicationDelegate:instance];
  [registrar addMethodCallDelegate:instance channel:channel];

  SEL sel = NSSelectorFromString(@"registerLibrary:withVersion:");
  if ([FIRApp respondsToSelector:sel]) {
    [FIRApp performSelector:sel withObject:LIBRARY_NAME withObject:LIBRARY_VERSION];
  }
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
    NSLog(@"64 initWithChannel() executed!");
    
  self = [super init];

  if (self) {
      NSLog(@"69 if (self) es true");
    _channel = channel;
    _resumingFromBackground = NO;
    if (![FIRApp appNamed:@"__FIRAPP_DEFAULT"]) {
      NSLog(@"Configuring the default Firebase app...");
      [FIRApp configure];
      NSLog(@"Configured the default Firebase app %@.", [FIRApp defaultApp].name);
    }
    [FIRMessaging messaging].delegate = self;
    // For iOS 10 display notification (sent via APNS)
    if (@available(iOS 10.0, *)) {
        NSLog(@"80 @available(iOS 10.0, * is true");
        [UNUserNotificationCenter currentNotificationCenter].delegate = (id<UNUserNotificationCenterDelegate>) self;
    } else {
        // Fallback on earlier versions
        NSLog(@"84 @available(iOS 10.0, * is false");
    }
      
      // For iOS 10 data message (sent via FCM)
//      [FIRMessaging messaging].remoteMessageDelegate = self;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSLog(@"94 handleMethodCall() executed!");
    
  NSString *method = call.method;
  NSLog(@"97 method es: %@", method);
  if ([@"requestNotificationPermissions" isEqualToString:method]) {
    if (@available(iOS 10.0, *)) {
        //UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        UNAuthorizationOptions authOptions = 0;
        NSDictionary *arguments = call.arguments;
        if ([arguments[@"sound"] boolValue]) {
          authOptions |= UIUserNotificationTypeSound;
        }
        if ([arguments[@"alert"] boolValue]) {
          authOptions |= UIUserNotificationTypeAlert;
        }
        if ([arguments[@"badge"] boolValue]) {
          authOptions |= UIUserNotificationTypeBadge;
        }
        
        [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:authOptions
         completionHandler:^(BOOL granted, NSError *_Nullable error) {
            if (error) {
                NSLog( @"117 Push registration FAILED" );
                NSLog( @"118 ERROR: %@ - %@", error.localizedFailureReason, error.localizedDescription );
                NSLog( @"119 SUGGESTIONS: %@ - %@", error.localizedRecoveryOptions, error.localizedRecoverySuggestion );
                
                result(getFlutterError(error));
                
            } else {
                
                NSLog(@"125 Permission granted: %d", granted);
                NSLog( @"126 Push registration success." );
                
                UNNotificationAction* replyAct = [UNTextInputNotificationAction
                                                      actionWithIdentifier: replyAction
                                                      title:@"Responder"
                                                      options:UNNotificationActionOptionNone];  //UNNotificationActionOptionForeground
                
                /*UNNotificationAction* approveAct = [UNNotificationAction
                                                    actionWithIdentifier: @"APPROVE_ACTION"
                                                    title:@"Aprobar"
                                                    options:UNNotificationActionOptionNone];  //UNNotificationActionOptionForeground*/
                
                UNNotificationCategory* generalCat = [UNNotificationCategory
                                                      categoryWithIdentifier: generalCategory
                                                      actions:@[replyAct]
                                                      intentIdentifiers:@[]
                                                      options:UNNotificationCategoryOptionCustomDismissAction];

                [[UNUserNotificationCenter currentNotificationCenter]
                 setNotificationCategories:[NSSet setWithObjects:generalCat, nil]];
            
                result([NSNumber numberWithBool:granted]);
            }
        }];
    } else {
        // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
        UIUserNotificationType notificationTypes = 0;
        NSDictionary *arguments = call.arguments;
        if ([arguments[@"sound"] boolValue]) {
          notificationTypes |= UIUserNotificationTypeSound;
        }
        if ([arguments[@"alert"] boolValue]) {
          notificationTypes |= UIUserNotificationTypeAlert;
        }
        if ([arguments[@"badge"] boolValue]) {
          notificationTypes |= UIUserNotificationTypeBadge;
        }
        UIUserNotificationSettings *settings =
            [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
      [[UIApplication sharedApplication] registerForRemoteNotifications];
      if (!@available(iOS 10.0, *)) {
        result([NSNumber numberWithBool:YES]);
      }
      
  } else if ([@"configure" isEqualToString:method]) {
    [FIRMessaging messaging].shouldEstablishDirectChannel = true;
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    if (_launchNotification != nil) {
      [_channel invokeMethod:@"onLaunch" arguments:_launchNotification];
    }
    result(nil);
  } else if ([@"subscribeToTopic" isEqualToString:method]) {
    NSString *topic = call.arguments;
    [[FIRMessaging messaging] subscribeToTopic:topic
                                    completion:^(NSError *error) {
                                      result(getFlutterError(error));
                                    }];
  } else if ([@"unsubscribeFromTopic" isEqualToString:method]) {
    NSString *topic = call.arguments;
    [[FIRMessaging messaging] unsubscribeFromTopic:topic
                                        completion:^(NSError *error) {
                                          result(getFlutterError(error));
                                        }];
  } else if ([@"getToken" isEqualToString:method]) {
    [[FIRInstanceID instanceID]
        instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable instanceIDResult,
                                NSError *_Nullable error) {
          if (error != nil) {
            NSLog(@"getToken, error fetching instanceID: %@", error);
            result(nil);
          } else {
            result(instanceIDResult.token);
          }
        }];
  } else if ([@"deleteInstanceID" isEqualToString:method]) {
    [[FIRInstanceID instanceID] deleteIDWithHandler:^void(NSError *_Nullable error) {
      if (error.code != 0) {
        NSLog(@"deleteInstanceID, error: %@", error);
        result([NSNumber numberWithBool:NO]);
      } else {
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
        result([NSNumber numberWithBool:YES]);
      }
    }];
  } else if ([@"autoInitEnabled" isEqualToString:method]) {
    BOOL value = [[FIRMessaging messaging] isAutoInitEnabled];
    result([NSNumber numberWithBool:value]);
  } else if ([@"setAutoInitEnabled" isEqualToString:method]) {
    NSNumber *value = call.arguments;
    [FIRMessaging messaging].autoInitEnabled = value.boolValue;
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Receive data message on iOS 10 devices while app is in the foreground.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"227 #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0");
    NSLog(@"228 applicationReceivedRemoteMessage() executed!");
  [self didReceiveRemoteNotification:remoteMessage.appData];
}
#endif

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"234 didReceiveRemoteNotification() executed!");
  if (_resumingFromBackground) {
      NSLog(@"236 _resumingFromBackground es true");
    [_channel invokeMethod:@"onResume" arguments:userInfo];
  } else {
      NSLog(@"239 _resumingFromBackground es false");
    [_channel invokeMethod:@"onMessage" arguments:userInfo];
  }
}

#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"248 didFinishLaunchingWithOptions() executed!");
    NSLog(@"249 launchOptions es: %@", launchOptions);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"options" message:[launchOptions[UIApplicationLaunchOptionsLocalNotificationKey] description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    //return YES;
    
  if (launchOptions != nil) {
      NSLog(@"256 launchOptions es != nil");
    _launchNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
  }
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  _resumingFromBackground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  _resumingFromBackground = NO;
  // Clears push notifications from the notification center, with the
  // side effect of resetting the badge count. We need to clear notifications
  // because otherwise the user could tap notifications in the notification
  // center while the app is in the foreground, and we wouldn't be able to
  // distinguish that case from the case where a message came in and the
  // user dismissed the notification center without tapping anything.
  // TODO(goderbauer): Revisit this behavior once we provide an API for managing
  // the badge number, or if we add support for running Dart in the background.
  // Setting badgeNumber to 0 is a no-op (= notifications will not be cleared)
  // if it is already 0,
  // therefore the next line is setting it to 1 first before clearing it again
  // to remove all notifications.
  application.applicationIconBadgeNumber = 1;
  application.applicationIconBadgeNumber = 0;
}

// [START receive_message]  *** Event FCM se sobreescribe cuando se declara method native userNotificationCenter:didReceiveNotificationResponse
- (BOOL)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    NSLog(@"289 application:didReceiveRemoteNotification::fetchCompletionHandler: executed!");
    
  [self didReceiveRemoteNotification:userInfo];
  completionHandler(UIBackgroundFetchResultNoData);
  return YES;
}
// [END receive_message]

// [START ios_10_message_handling]  ***
// Receive displayed notifications for iOS 10 devices.
// Handle incoming notification messages while app is in the foreground.
/*- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler  API_AVAILABLE(ios(10.0)){
  NSDictionary *userInfo = notification.request.content.userInfo;
    
    NSLog(@"305 userNotificationCenter:willPresentNotification::withCompletionHandler: executed!");

  // With swizzling disabled you must let Messaging know about the message, for Analytics
  // [[FIRMessaging messaging] appDidReceiveMessage:userInfo];

  // Print message ID.
  if (userInfo[kGCMMessageIDKey]) {
    NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
  }

  // Print full message.
  NSLog(@"userInfo es: %@", userInfo);

  // Change this to your preferred presentation option
  completionHandler(UNNotificationPresentationOptionAlert);
}*/

// Handle notification messages after display notification is tapped by the user.   ***
/*- (void)userNotificationCenter:(UNUserNotificationCenter *)center
           didReceiveNotificationResponse:(UNTextInputNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler  API_AVAILABLE(ios(10.0)){
    NSLog(@"326 userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler executed! :)");
    //fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {


    if ([response.notification.request.content.categoryIdentifier isEqualToString:generalCategory]) {
        // Handle the actions for the expired timer.
        if ([response.actionIdentifier isEqualToString:replyAction]) {
            //NSLog(@"333 Button responder pressed! :)");
            //NSLog(@"334 response.userText es: %@", response.userText);
            
            [self handleReplyActionWithResponse:response];

        } else if ([response.actionIdentifier isEqualToString:@"APPROVE_ACTION"]) {
            NSLog(@"339 Button aprobar pressed! :)");
        }

    }
    
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    // Must be called when finished
    [self didReceiveRemoteNotification:userInfo];
    completionHandler();    //completionHandler(UIBackgroundFetchResultNoData);
}*/

- (void) handleReplyActionWithResponse:(UNTextInputNotificationResponse *)response  API_AVAILABLE(ios(10.0)){
    NSLog(@"351 handleReplyActionWithNotification() executed! :)");
    NSLog(@"352 response es: %@", response);
    
    ChatworkService *chatService = [[ChatworkService alloc] init];
    
    NSDictionary *userInfo = response.notification.request.content.userInfo;

    if (userInfo[kGCMMessageIDKey]) {
      NSLog(@"359 Message ID: %@", userInfo[kGCMMessageIDKey]);
    }

     //Print full message.
    NSLog(@"363 userInfo es: %@", userInfo);
    
    NSString *messageText = response.userText;
    NSString *channelId = userInfo[@"tag"];
    
    [chatService saveMessageWithTextMessage:messageText andChannelId:channelId andCompletionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if(httpResponse.statusCode == 201) {
            NSLog(@"372 Android data es: %@", data);
            NSLog(@"373 Android response es: %@", response);
            
            NSError *parseError = nil;
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            NSLog(@"377 Android The response is - %@", responseDictionary);
            NSInteger success = [[responseDictionary objectForKey:@"success"] integerValue];
            if(success == 1) {
                NSLog(@"380 Android Login SUCCESS");
            } else {
                NSLog(@"382 Android Login FAILURE");
            }
            
            NSString *userId = userInfo[@"from_id"];
            NSString *logoProveedor = userInfo[@"fcm_options"][@"image"];

            NSString *estadoPedido = userInfo[@"estado_pedido"];
            NSString *valorPedido = userInfo[@"valor_pedido"];

            NSLog(@"391 userId: %@", userId);
            NSLog(@"392 logoProveedor: %@", logoProveedor);
            
            NSLog(@"394 estadoPedido: %@", estadoPedido);
            NSLog(@"395 valorPedido: %@", valorPedido);
            
            //try {
            NSString *title = [responseDictionary objectForKey:@"empresa"]; //response.getString("empresa") + " - Chatwork";
            NSString *tipoUser = [responseDictionary objectForKey:@"tipoUsuario"];
            NSString *idUser = [[responseDictionary objectForKey:@"idUser"] stringValue];
            NSString *fromId = [NSString stringWithFormat:@"%@-%@", tipoUser, idUser];
            NSString *userImage = [NSString stringWithFormat:@"https://%@/uploads/logosProveedor/%@", SERVER_DOMAIN, [responseDictionary objectForKey:@"fotoLogo"]];
            
            NSString *dataChat = userInfo[@"data_chat"];
            NSData *chatData = [dataChat dataUsingEncoding:NSUTF8StringEncoding];
            NSError *errorParse = nil;
            
            //NSDictionary pedido = new JSONObject(bundle.getString("data_chat"));
            //pedido.put("nombre", response.getString("nombre"));
            //pedido.put("celular", response.getString("celular"));
            
            NSMutableDictionary *chatPedido = [NSJSONSerialization JSONObjectWithData:chatData options:0 error:&errorParse];
            NSMutableDictionary *pedido = [[NSMutableDictionary alloc] initWithDictionary:chatPedido copyItems:TRUE];
            
            [pedido setValue:[responseDictionary objectForKey:@"nombre"] forKey:@"nombre"];
            [pedido setValue:[responseDictionary objectForKey:@"celular"] forKey:@"celular"];
            
            //NSString *currentPage = pedido.getString("currentPage").equals("misCompras") ? "misVentas" : "misCompras";
            //NSString *idProv = pedido.getString("idProv");
            //NSString *color = Objects.requireNonNull(idUser).equals(idProv) ? COLOR_CONSUMIDOR : COLOR_PROVEEDOR;

            NSLog(@"422 [pedido objectForKey:@\"currentPage\"] es: %@", [pedido objectForKey:@"currentPage"]);
            
            NSString *currentPage = [[pedido objectForKey:@"currentPage"] isEqualToString:@"misCompras"] ? @"misVentas" : @"misCompras";
            NSString *idProv = [pedido objectForKey:@"idProv"];
            NSLog(@"426 idUser es: %@", idUser);
            NSLog(@"427 idProv es: %@", idProv);
            
            NSString *color = [idUser isEqualToString:idProv] ? COLOR_CONSUMIDOR : COLOR_PROVEEDOR;

            NSLog(@"431 idUser es: %@", idUser);
            NSLog(@"432 idProv es: %@", idProv);
            NSLog(@"433 color es: %@", color);
            NSLog(@"434 currentPage es:  %@", currentPage);
            
            [self sendNotificationWithTitle:title body:messageText userId:userId channelId:channelId color:color userImage:userImage action:@"envio_chat" fromId:fromId codPedido:[NSString stringWithFormat:@"Pedido %@", [pedido objectForKey:@"codPedido"]] description:[pedido objectForKey:@"description"] estadoPedido:estadoPedido valorPedido:valorPedido dataChat:[self getDataChatWithChannelId:channelId messageText:messageText topicSenderId:idUser senderId:userId tipoUser:tipoUser pedido:pedido logoProveedor:logoProveedor foto:userImage currentPage:currentPage]];
            
        } else {
            NSLog(@"Error es: %@", error);
        }
    }];
}

// [END ios_10_message_handling]

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  NSLog(@"447 Unable to register for remote notifications: %@", error);
}

// Flutter requestNotificationPermissions() event ***
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"453 application:didRegisterForRemoteNotificationsWithDeviceToken() executed! %@", deviceToken);
#ifdef DEBUG
    NSLog(@"455 DEBUG es TRUE");
  [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeSandbox];
#else
    NSLog(@"458 DEBUG es FALSE");
  [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeProd];
#endif
    NSLog(@"461 _channel invokeMethod:onToken");
  [_channel invokeMethod:@"onToken" arguments:[FIRMessaging messaging].FCMToken];
}

// Flutter onIosSettingsRegistered() event ???
- (void)application:(UIApplication *)application
    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
  NSDictionary *settingsDictionary = @{
    @"sound" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeSound],
    @"badge" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeBadge],
    @"alert" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeAlert],
  };
    NSLog(@"473 _channel invokeMethod:onIosSettingsRegistered");
  [_channel invokeMethod:@"onIosSettingsRegistered" arguments:settingsDictionary];
}

// Flutter onToken() event ***
- (void)messaging:(nonnull FIRMessaging *)messaging
    didReceiveRegistrationToken:(nonnull NSString *)fcmToken {
    NSLog(@"480 _channel invokeMethod:onToken");
  [_channel invokeMethod:@"onToken" arguments:fcmToken];
}

// [START ios_10_data_message] ??? enlace FCM Se sobreescribe si se declara method iOS native
// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
// To enable direct data messages, you can set [Messaging messaging].shouldEstablishDirectChannel to YES.
- (void)messaging:(FIRMessaging *)messaging
    didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"489 didReceiveMessage() executed!");
  [_channel invokeMethod:@"onMessage" arguments:remoteMessage.appData];
}
// [END ios_10_data_message]

- (void) sendNotificationWithTitle:(NSString *_Nonnull)title body:(NSString *_Nonnull)body userId:(NSString *_Nonnull)userId channelId:(NSString *_Nonnull)channelId color:(NSString *_Nonnull)color userImage:(NSString *_Nonnull)userImage action:(NSString *_Nonnull)action fromId:(NSString *_Nonnull)fromId codPedido:(NSString *_Nonnull)codPedido description:(NSString *_Nonnull)description estadoPedido:(NSString *_Nonnull)estadoPedido valorPedido:(NSString *_Nonnull)valorPedido dataChat:(NSDictionary *_Nonnull)dataChat {
    NSLog(@"495 sendNotificationWithTitle() executed!");
    
    MessagingService *msgService = [[MessagingService alloc] init];
    NSLog(@"498 msgService instanciado :)");
    
    [msgService
     sendToTopicWithTitle:title
     body:body
     topic:userId
     tagId:channelId
     colorIcon:color
     imageName:userImage
     action:action
     fromId:fromId
     codPedido:codPedido
     description:description
     estadoPedido:estadoPedido
     valorPedido:valorPedido
     payload:dataChat
     andCompletionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if(httpResponse.statusCode == 200) {
            NSLog(@"519 Android data es: %@", data);
            NSLog(@"520 Android response es: %@", response);
            
            NSError *parseError = nil;
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            NSLog(@"524 Android The response is - %@",responseDictionary);
            NSInteger success = [[responseDictionary objectForKey:@"success"] integerValue];
            if(success == 1) {
                NSLog(@"527 Android success es: %d", success);
            } else {
                NSLog(@"529 Android success es: %d", success);
            }
            
        } else {
            NSLog(@"533 Android Error es: %@", error);
        }
    }];
}

- (NSDictionary *_Nonnull) getDataChatWithChannelId:(NSString *_Nonnull)channelId messageText:(NSString *_Nonnull)messageText topicSenderId:(NSString *_Nonnull)topicSenderId senderId:(NSString *_Nonnull)senderId tipoUser:(NSString *_Nonnull)tipoUser pedido:(NSDictionary *_Nonnull)pedido logoProveedor:(NSString *_Nonnull)logoProveedor foto:(NSString *_Nonnull)foto currentPage:(NSString *_Nonnull)currentPage {
    
    NSLog(@"540 getDataChatWithChannelId() executed!");
    
    NSLog(@"542 logoProveedor es: %@", logoProveedor);
    NSLog(@"543 foto es: %@", foto);
    NSLog(@"544 topicSenderId es: %@", topicSenderId);
    
    NSLog(@"546 pedido es: %@", pedido);
    
    NSDictionary * dataChat = @{
        @"idPedido": channelId,
        @"codPedido": [pedido objectForKey:@"codPedido"],
        @"descriPedido": [pedido objectForKey:@"descriPedido"],
        @"estadoPedido": [pedido objectForKey:@"estadoPedido"],
        @"celular": @"celular",
        @"propuesta": [pedido objectForKey:@"propuesta"],
        @"representante": @"representante",
        @"requerimiento": [pedido objectForKey:@"requerimiento"],
        @"subtotalPedido": [pedido objectForKey:@"subtotalPedido"],
        @"idProv": [pedido objectForKey:@"idProv"],
        @"logoProveedor": logoProveedor,
        @"foto": foto,
        @"tipoUsuario": tipoUser,
        @"channel": channelId,
        @"proveedor": @"proveedor",
        @"senderId": senderId,
        @"datePedi": [pedido objectForKey:@"datePedi"],
        @"tipoChat": @"tipoChat",
        @"message": messageText,
        @"image": foto,
        @"description": messageText,
        @"tipoAdj": @"",
        @"nombretoChat": [pedido objectForKey:@"nombre"],
        @"topicSenderId": topicSenderId,
        @"celulartoChat": [pedido objectForKey:@"celular"],
        @"logoCliente": foto,
        @"logoProv": logoProveedor,
        @"currentPage": currentPage,
        @"typeCliente": tipoUser,
        @"typeNotify": @"Android"
    };
    
    return dataChat;
}

@end
