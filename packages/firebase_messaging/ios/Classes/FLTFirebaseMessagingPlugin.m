// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UserNotifications/UserNotifications.h>

#import "FLTFirebaseMessagingPlugin.h"
#import "UserAgent.h"

#import "Firebase/Firebase.h"

#import "ChatworkService.h"
#import "MessagingService.h"
#import "Constants.h"

NSString *const kGCMMessageIDKey = @"gcm.message_id";

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FLTFirebaseMessagingPlugin () <FIRMessagingDelegate, UNUserNotificationCenterDelegate>

- (void) sendNotificationWithTitle:(NSString *_Nonnull)title body:(NSString *_Nonnull)body userId:(NSString *_Nonnull)userId channelId:(NSString *_Nonnull)channelId color:(NSString *_Nonnull)color userImage:(NSString *_Nonnull)userImage action:(NSString *_Nonnull)action fromId:(NSString *_Nonnull)fromId codPedido:(NSString *_Nonnull)codPedido description:(NSString *_Nonnull)description estadoPedido:(NSString *_Nonnull)estadoPedido valorPedido:(NSString *_Nonnull)valorPedido dataChat:(NSDictionary *_Nonnull)dataChat completionHandler:(void (^)(void))completionHandler;

- (NSDictionary *_Nonnull) getDataChatWithChannelId:(NSString *_Nonnull)channelId messageText:(NSString *_Nonnull)messageText topicSenderId:(NSString *_Nonnull)topicSenderId senderId:(NSString *_Nonnull)senderId tipoUser:(NSString *_Nonnull)tipoUser pedido:(NSDictionary *_Nonnull)pedido logoProveedor:(NSString *_Nonnull)logoProveedor foto:(NSString *_Nonnull)foto currentPage:(NSString *_Nonnull)currentPage usuario:(NSDictionary *_Nonnull)usuario messageId:(NSInteger *_Nonnull)messageId;

@end
#endif

static FlutterError *getFlutterError(NSError *error) {
  if (error == nil) return nil;
  return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %ld", (long)error.code]
                             message:error.domain
                             details:error.localizedDescription];
}

static NSObject<FlutterPluginRegistrar> *_registrar;

@implementation FLTFirebaseMessagingPlugin {
  FlutterMethodChannel *_channel;
  NSDictionary *_launchNotification;
  BOOL _resumingFromBackground;
}

NSString *const replyAction = @"REPLY_IDENTIFIER";
NSString *const generalCategory = @"FLUTTER_NOTIFICATION_CLICK";
NSString *const COLOR_PROVEEDOR = @"0x4caf50";
NSString *const COLOR_CONSUMIDOR = @"0x0288D1";

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  _registrar = registrar;

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
  self = [super init];

  if (self) {
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
      [UNUserNotificationCenter currentNotificationCenter].delegate = (id<UNUserNotificationCenterDelegate>) self;
      //[UNUserNotificationCenter currentNotificationCenter].delegate = self;
    }/* else {
        // Fallback on earlier versions
        NSLog(@"84 @available(iOS 10.0, * is false");
    }*/
    // For iOS 10 data message (sent via FCM)
    // [FIRMessaging messaging].remoteMessageDelegate = self;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *method = call.method;
  if ([@"requestNotificationPermissions" isEqualToString:method]) {
    NSDictionary *arguments = call.arguments;
    if (@available(iOS 10.0, *)) {
      /*UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;*/
      /*UNAuthorizationOptions authOptions = 0;
      NSDictionary *arguments = call.arguments;
      if ([arguments[@"sound"] boolValue]) {
        authOptions |= UIUserNotificationTypeSound;
      }
      if ([arguments[@"alert"] boolValue]) {
        authOptions |= UIUserNotificationTypeAlert;
      }
      if ([arguments[@"badge"] boolValue]) {
        authOptions |= UIUserNotificationTypeBadge;
      }*/

      UNAuthorizationOptions authOptions = 0;
      NSNumber *provisional = arguments[@"provisional"];
      if ([arguments[@"sound"] boolValue]) {
        authOptions |= UNAuthorizationOptionSound;
      }
      if ([arguments[@"alert"] boolValue]) {
        authOptions |= UNAuthorizationOptionAlert;
      }
      if ([arguments[@"badge"] boolValue]) {
        authOptions |= UNAuthorizationOptionBadge;
      }

      NSNumber *isAtLeastVersion12;
      if (@available(iOS 12, *)) {
        isAtLeastVersion12 = [NSNumber numberWithBool:YES];
        if ([provisional boolValue]) authOptions |= UNAuthorizationOptionProvisional;
      } else {
        isAtLeastVersion12 = [NSNumber numberWithBool:NO];
      }

      [[UNUserNotificationCenter currentNotificationCenter]
          requestAuthorizationWithOptions:authOptions
                        completionHandler:^(BOOL granted, NSError *_Nullable error) {
                          if (error) {
                            NSLog( @"133 Push registration FAILED" );
                            NSLog( @"134 ERROR: %@ - %@", error.localizedFailureReason, error.localizedDescription );
                            NSLog( @"135 SUGGESTIONS: %@ - %@", error.localizedRecoveryOptions, error.localizedRecoverySuggestion );

                            result(getFlutterError(error));
                            return;
                          }
                          // This works for iOS >= 10. See
                          // [UIApplication:didRegisterUserNotificationSettings:notificationSettings]
                          // for ios < 10.

                          NSLog(@"144 Permission granted: %d", granted);
                          NSLog( @"145 Push registration success." );
                          
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

                          /*[[UNUserNotificationCenter currentNotificationCenter]
                            setNotificationCategories:[NSSet setWithObjects:generalCat, nil]];
                          result([NSNumber numberWithBool:granted]);*/

                          [[UNUserNotificationCenter currentNotificationCenter]
                            setNotificationCategories:[NSSet setWithObjects:generalCat, nil]];

                          [[UNUserNotificationCenter currentNotificationCenter]
                              getNotificationSettingsWithCompletionHandler:^(
                                  UNNotificationSettings *_Nonnull settings) {
                                NSDictionary *settingsDictionary = @{
                                  @"sound" : [NSNumber numberWithBool:settings.soundSetting ==
                                                                      UNNotificationSettingEnabled],
                                  @"badge" : [NSNumber numberWithBool:settings.badgeSetting ==
                                                                      UNNotificationSettingEnabled],
                                  @"alert" : [NSNumber numberWithBool:settings.alertSetting ==
                                                                      UNNotificationSettingEnabled],
                                  @"provisional" :
                                      [NSNumber numberWithBool:granted && [provisional boolValue] &&
                                                               isAtLeastVersion12],
                                };
                                [self->_channel invokeMethod:@"onIosSettingsRegistered"
                                                   arguments:settingsDictionary];
                              }];
                          result([NSNumber numberWithBool:granted]);
                        }];
      [[UIApplication sharedApplication] registerForRemoteNotifications];
      
    } else {
      // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
      UIUserNotificationType notificationTypes = 0;
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

      [[UIApplication sharedApplication] registerForRemoteNotifications];
      result([NSNumber numberWithBool:YES]);
    }
  } else if ([@"configure" isEqualToString:method]) {
    [FIRMessaging messaging].shouldEstablishDirectChannel = true;
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    if (_launchNotification != nil && _launchNotification[kGCMMessageIDKey]) {
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
// Received data message on iOS 10 devices while app is in the foreground.
// Only invoked if method swizzling is enabled.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"267 - (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage() executed!");
    NSLog(@"Only invoked if method swizzling is enabled!!!");
  [self didReceiveRemoteNotification:remoteMessage.appData];
}
#endif

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"346 - (void)didReceiveRemoteNotification");
  if (_resumingFromBackground) {
    [_channel invokeMethod:@"onResume" arguments:userInfo];
  } else {
    [_channel invokeMethod:@"onMessage" arguments:userInfo];
  }
}

#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    /*UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"options" message:[launchOptions[UIApplicationLaunchOptionsLocalNotificationKey] description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];*/
    
  if (launchOptions != nil) {
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
/*- (BOOL)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    NSLog(@"394 - (BOOL)application:didReceiveRemoteNotification:fetchCompletionHandler()");
    NSLog(@"395 Event FCM se sobreescribe cuando se declara method native userNotificationCenter:didReceiveNotificationResponse");
    
    NSLog(@"Message[action] es:  %@", userInfo[@"action"]);
    
    if(application.applicationState == UIApplicationStateInactive) {
        NSLog(@"Inactive");

        //Show the view with the content of the push
        //completionHandler(UIBackgroundFetchResultNewData);

    } else if (application.applicationState == UIApplicationStateBackground) {
        NSLog(@"Background");

        //Refresh the local model
        //completionHandler(UIBackgroundFetchResultNewData);
        if([userInfo[@"action"] isEqualToString:@"descartar_pedido"]
           || [userInfo[@"action"] isEqualToString:@"descartar_pedido_cliente"]
           || [userInfo[@"action"] isEqualToString:@"entregar_pedido"]
           || [userInfo[@"action"] isEqualToString:@"recibir_pedido"]
           || [userInfo[@"action"] isEqualToString:@"completar_pedido"]
           || [userInfo[@"action"] isEqualToString:@"finalizar_pedido"]) {
            
            _resumingFromBackground = NO;
        }

    } else {
        NSLog(@"Active");

        //Show an in-app banner
        //completionHandler(UIBackgroundFetchResultNewData);
    }
    
    [self didReceiveRemoteNotification:userInfo];
    completionHandler(UIBackgroundFetchResultNoData);
    return YES;
} // [END receive_message]
*/

// [START ios_10_message_handling]
// Receive displayed notifications for iOS 10 devices.
// Received data message on iOS 10 devices while app is in the foreground.
// Only invoked if method swizzling is disabled and UNUserNotificationCenterDelegate has been
// registered in AppDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
    NS_AVAILABLE_IOS(10.0) {
    NSLog(@"281 - (void)userNotificationCenter:willPresentNotification::withCompletionHandler: executed!");
    NSLog(@"282 Only invoked if method swizzling is disabled and UNUserNotificationCenterDelegate has been registered in AppDelegate");

  NSDictionary *userInfo = notification.request.content.userInfo;

  // Print full message.
  // NSLog(@"userInfo es: %@", userInfo);

  // Print message ID.
  // NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);

  // Check to key to ensure we only handle messages from Firebase
  if (userInfo[kGCMMessageIDKey]) {
    // With swizzling disabled you must let Messaging know about the message, for Analytics
    [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
    [_channel invokeMethod:@"onMessage" arguments:userInfo];
    // Change this to your preferred presentation option  -- UNNotificationPresentationOptionAlert
    completionHandler(UNNotificationPresentationOptionNone);
  }
}

/* Override method Tap notification
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler NS_AVAILABLE_IOS(10.0) {
  NSDictionary *userInfo = response.notification.request.content.userInfo;
  // Check to key to ensure we only handle messages from Firebase
  if (userInfo[kGCMMessageIDKey]) {
    [_channel invokeMethod:@"onResume" arguments:userInfo];
    completionHandler();
  }
}*/

// Handle notification messages after display notification is tapped by the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
           didReceiveNotificationResponse:(UNTextInputNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler  API_AVAILABLE(ios(10.0)) {
    //fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    NSLog(@"409 - (void)userNotificationCenter:didReceiveNotificationResponsewithCompletionHandler");

    if ([response.notification.request.content.categoryIdentifier isEqualToString:generalCategory]) {
        // Handle the actions for the expired timer.
        if ([response.actionIdentifier isEqualToString:replyAction]) {
            /*NSLog(@"414 Button responder pressed! :)");*/
            /*NSLog(@"415 response.userText es: %@", response.userText);*/
            
            [self handleReplyActionWithResponse:response withCompletionHandler:completionHandler];
            /*completionHandler();*/
            return;

        } /*else if ([response.actionIdentifier isEqualToString:@"APPROVE_ACTION"]) {
            NSLog(@"325 Button aprobar pressed! :)");
        }*/
    }
    
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    if (userInfo[kGCMMessageIDKey]) {
      [self didReceiveRemoteNotification:userInfo];
      // Must be called when finished
      completionHandler();    //completionHandler(UIBackgroundFetchResultNoData);
    }
}

// Flutter requestNotificationPermissions() event ***
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
#ifdef DEBUG
  [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeSandbox];
#else
  [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeProd];
#endif
  [_channel invokeMethod:@"onToken" arguments:[FIRMessaging messaging].FCMToken];
}

// Flutter onIosSettingsRegistered() event ???
// This will only be called for iOS < 10. For iOS >= 10, we make this call when we request
// permissions.
- (void)application:(UIApplication *)application
    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
  NSDictionary *settingsDictionary = @{
    @"sound" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeSound],
    @"badge" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeBadge],
    @"alert" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeAlert],
    @"provisional" : [NSNumber numberWithBool:NO],
  };
  [_channel invokeMethod:@"onIosSettingsRegistered" arguments:settingsDictionary];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Unable to register for remote notifications: %@", error);
}

// Flutter onToken() event ***
- (void)messaging:(nonnull FIRMessaging *)messaging
    didReceiveRegistrationToken:(nonnull NSString *)fcmToken {
  [_channel invokeMethod:@"onToken" arguments:fcmToken];
}

// [START ios_10_data_message] ??? enlace FCM Se sobreescribe si se declara method iOS native
// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
// To enable direct data messages, you can set [Messaging messaging].shouldEstablishDirectChannel to YES.
- (void)messaging:(FIRMessaging *)messaging
    didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"440 - (void)messaging:didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage");
    NSLog(@"enlace FCM Se sobreescribe si se declara method iOS native");
    NSLog(@"Returning message data notification....");
//  [_channel invokeMethod:@"onMessage" arguments:remoteMessage.appData];
}
// [END ios_10_data_message]

- (void) handleReplyActionWithResponse:(UNTextInputNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(10.0)){
    /*NSLog(@"482 handleReplyActionWithResponse()");*/
    ChatworkService *chatService = [[ChatworkService alloc] init];
    
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    
    NSString *messageText = response.userText;
    NSString *channelId = userInfo[@"tag"];
    
    [chatService saveMessageWithTextMessage:messageText andChannelId:channelId andCompletionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        /*NSLog(@"492 chatService:saveMessage() httpResponse.statusCode es:  %ld", httpResponse.statusCode);*/
        
        if(httpResponse.statusCode == 201) {
            NSError *parseError = nil;
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            /*NSLog(@"responseDictionary es: %@",responseDictionary);*/
            
            NSMutableDictionary *datosPedido = [responseDictionary objectForKey:@"pedido"];
            /*NSLog(@"datosPedido es: %@",datosPedido);*/
            
            NSMutableDictionary *datosUsuario = [responseDictionary objectForKey:@"datosusuario"];
            /*NSLog(@"datosUsuario es: %@",datosUsuario);*/
            
            NSString *userId = userInfo[@"from_id"];
            NSString *logoProveedor = userInfo[@"fcm_options"][@"image"];

            NSString *estadoPedido = userInfo[@"estado_pedido"];
            NSString *valorPedido = userInfo[@"valor_pedido"];
            
            //try {
            NSString *title = [responseDictionary objectForKey:@"empresa"]; //response.getString("empresa") + " - Chatwork";
            NSString *tipoUser = [responseDictionary objectForKey:@"tipoUsuario"];
            NSString *idUser = [[responseDictionary objectForKey:@"idUser"] stringValue];
            NSString *fromId = [NSString stringWithFormat:@"%@-%@", tipoUser, idUser];
            NSString *userImage = [NSString stringWithFormat:@"https://%@/uploads/logosProveedor/%@", __SERVER_DOMAIN, [responseDictionary objectForKey:@"fotoLogo"]];
            NSInteger messageId = [[responseDictionary objectForKey:@"messageId"] intValue];
            
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
            
            NSString *currentPage = [[pedido objectForKey:@"currentPage"] isEqualToString:@"misCompras"] ? @"misVentas" : @"misCompras";
            NSString *idProv = [pedido objectForKey:@"idProv"];
            
            NSString *color = [idUser isEqualToString:idProv] ? COLOR_CONSUMIDOR : COLOR_PROVEEDOR;
            
            /*NSLog(@"userId es: %@", userId);*/
            /*NSLog(@"fromId es: %@", fromId);*/
            
            [self sendNotificationWithTitle:title body:messageText userId:userId channelId:channelId color:color userImage:userImage action:@"envio_chat" fromId:fromId codPedido:[NSString stringWithFormat:@"Pedido %@", [datosPedido objectForKey:@"codPedido"]] description:[datosPedido objectForKey:@"descriPedido"] estadoPedido:estadoPedido valorPedido:valorPedido dataChat:[self getDataChatWithChannelId:channelId messageText:messageText topicSenderId:idUser senderId:userId tipoUser:tipoUser pedido:datosPedido logoProveedor:logoProveedor foto:userImage currentPage:currentPage usuario:datosUsuario messageId:&messageId] completionHandler:completionHandler];
            
        } else {
            NSLog(@"Error es: %@", error);
        }
    }];
}

- (void) sendNotificationWithTitle:(NSString *_Nonnull)title body:(NSString *_Nonnull)body userId:(NSString *_Nonnull)userId channelId:(NSString *_Nonnull)channelId color:(NSString *_Nonnull)color userImage:(NSString *_Nonnull)userImage action:(NSString *_Nonnull)action fromId:(NSString *_Nonnull)fromId codPedido:(NSString *_Nonnull)codPedido description:(NSString *_Nonnull)description estadoPedido:(NSString *_Nonnull)estadoPedido valorPedido:(NSString *_Nonnull)valorPedido dataChat:(NSDictionary *_Nonnull)dataChat completionHandler:(void (^)(void))completionHandler {
    MessagingService *msgService = [[MessagingService alloc] init];
    
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
        /*NSLog(@"Android httpResponse.statusCode es: %ld", httpResponse.statusCode);*/
        
        if(httpResponse.statusCode == 200) {
            NSError *parseError = nil;
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            NSLog(@"524 Android The response is - %@",responseDictionary);
            completionHandler();
            
        } else {
            NSError *parseError = nil;
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            NSLog(@"593 Android responseDictionary es: %@", responseDictionary);
            NSLog(@"594 Android Error es: %@", error);
            completionHandler();
        }
    }];
}

- (NSDictionary *_Nonnull) getDataChatWithChannelId:(NSString *_Nonnull)channelId messageText:(NSString *_Nonnull)messageText topicSenderId:(NSString *_Nonnull)topicSenderId senderId:(NSString *_Nonnull)senderId tipoUser:(NSString *_Nonnull)tipoUser pedido:(NSDictionary *_Nonnull)pedido logoProveedor:(NSString *_Nonnull)logoProveedor foto:(NSString *_Nonnull)foto currentPage:(NSString *_Nonnull)currentPage usuario:(NSDictionary *_Nonnull)usuario messageId:(NSInteger *_Nonnull)messageId {
    
    NSMutableDictionary *proveedor = [pedido objectForKey:@"proveedor"];
    /*NSLog(@"proveedor es: %@", proveedor);*/
    
    NSMutableDictionary *cliente = [pedido objectForKey:@"cliente"];
    /*NSLog(@"cliente es: %@", cliente);*/
    /*NSLog(@"cliente == NULL es: %d", cliente == [ NSNull null ]);
    NSLog(@"cliente != NULL es: %d", cliente != [ NSNull null ]);*/
    
    NSMutableDictionary *clienteProveedor = [pedido objectForKey:@"clienteProveedor"];
    /*NSLog(@"clienteProveedor es: %@", clienteProveedor);*/
    /*NSLog(@"clienteProveedor == NULL es: %d", clienteProveedor == [ NSNull null ]);
    NSLog(@"clienteProveedor != NULL es: %d", clienteProveedor != [ NSNull null ]);*/
    
    NSMutableDictionary *empresa = clienteProveedor != [ NSNull null ] ? [clienteProveedor objectForKey:@"empresa"] : [ NSNull null ];
    /*NSLog(@"empresa es: %@", empresa);*/
       
    NSDictionary * dataChat = @{
        @"_id": channelId,
        @"idPediProveedor": [pedido objectForKey:@"codPedido"],
        @"descriPedido": [pedido objectForKey:@"descriPedido"],
        @"estadoPedido": [pedido objectForKey:@"estadoPedido"],
        @"subtotalPedido": [pedido objectForKey:@"subTotal"],
        @"pathRequer": [pedido objectForKey:@"requerimiento"],
        @"estadoPedidoCliente": [pedido objectForKey:@"estadoPedidoCliente"],
        @"createAt": [pedido objectForKey:@"date"],
        @"pathPropuesta": [pedido objectForKey:@"propuesta"],
        @"tipoUser": [pedido objectForKey:@"tipoUser"],
        @"topicSenderId": [usuario objectForKey:@"id"],
        @"isOferta": [pedido objectForKey:@"isOferta"],
        @"imagenPublicacion": [pedido objectForKey:@"imagenPublicacion"],

        @"indexO": @0,

        @"idProveedor": [proveedor objectForKey:@"id"],
        @"nombreProveedor": [proveedor objectForKey:@"nombreProveedor"],
        @"apellidoProveedor": [proveedor objectForKey:@"apellidoProveedor"],
        @"apiLogoProveedor": [proveedor objectForKey:@"api_logo"],
        @"celularProveedor": [proveedor objectForKey:@"celular"],
        @"nombreEmpresaProveedor": [proveedor objectForKey:@"nombre_empresa"],
        @"ubicacionProveedor": [proveedor objectForKey:@"ubicacion"],
        @"actividadEconomicaProveedor": [proveedor objectForKey:@"actividadEconomicaProveedor"],
        @"paisProveedor": [proveedor objectForKey:@"paisProveedor"],
        @"ciudadProveedor": [proveedor objectForKey:@"ciudadProveedor"],

        @"idCliente": cliente != [NSNull null] ? [cliente objectForKey:@"id"] : [NSNull null],
        @"nombreCliente": cliente != [NSNull null] ? [cliente objectForKey:@"nombre"] : [NSNull null],
        @"apellidoCliente": cliente != [NSNull null] ? [cliente objectForKey:@"apellido"] : [NSNull null],
        @"apiLogoCliente": cliente != [NSNull null] ? [cliente objectForKey:@"api_logo"] : [NSNull null],
        @"celularCliente": cliente != [NSNull null] ? [cliente objectForKey:@"celular"] : [NSNull null],

        @"idClienteProveedor": clienteProveedor != [NSNull null] ? [clienteProveedor objectForKey:@"id"] : [NSNull null],
        @"nombreClienteProveedor": clienteProveedor != [NSNull null] ? [clienteProveedor objectForKey:@"nombreProveedor"] : [NSNull null],
        @"apellidoClienteProveedor": clienteProveedor != [NSNull null] ? [clienteProveedor objectForKey:@"apellidoProveedor"] : [NSNull null],
        @"apiLogoClienteProveedor": clienteProveedor != [NSNull null] ? [empresa objectForKey:@"api_logo"] : [NSNull null],
        @"celularClienteProveedor": clienteProveedor != [NSNull null] ? [clienteProveedor objectForKey:@"celularProveedor"] : [NSNull null],
        @"nombreEmpresaClienteProveedor": clienteProveedor != [NSNull null] ? [empresa objectForKey:@"nombre"] : [NSNull null],
        @"ubicacionClienteProveedor": clienteProveedor != [NSNull null] ? [clienteProveedor objectForKey:@"ubicacion"] : [NSNull null],

        @"messageId": [NSNumber numberWithInteger:*messageId],
        @"channel": channelId,
        @"asunto": @"chatwork",
        @"senderId": senderId,
        @"command": @"message",
        @"category": @"",
        @"message": messageText,
        @"type": @"text",
        @"createAtChat": @"createAtChat",
        @"width":@"width",
        @"height": @"height",

        @"celular": [pedido objectForKey:@"celular"],
        @"representante": [proveedor objectForKey:@"nombre_proveedor"],
        @"idProv": [proveedor objectForKey:@"id"],
        @"logoProveedor": [proveedor objectForKey:@"api_logo"],
        @"foto": foto,
        @"tipoChat": @true,
        @"navbarClnts": @true,
        @"logoProv": logoProveedor,
        @"celulartoChat": [usuario objectForKey:@"celular"],
        @"nombretoChat": [usuario objectForKey:@"nombre_consumidor"],
        @"logoProv": @"",

        @"image": foto,
        @"description": messageText,
        @"currentPage": currentPage,
        @"typeCliente": tipoUser,
        @"notificationColor": [pedido objectForKey:@"color"],

        @"tipoUserItem": @"js-clnts-pers",
        @"nombreUserItem": @"SCOTH WILIAMS",
        @"chatMsgNegoTipoUser": @"proveedor",
        @"chatMsgNegoEvento": @"ProveedorConsumidor",
        @"chatMsgNegoFrom": @"#js-add-chat",
        @"usuario": @"proveedor",
        @"toastrPos": @"toast-top-right",
    };
    
    return dataChat;
}

@end

