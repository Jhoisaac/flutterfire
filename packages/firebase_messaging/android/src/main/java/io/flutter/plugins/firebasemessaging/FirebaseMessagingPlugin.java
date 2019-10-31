// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.firebasemessaging;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.InstanceIdResult;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.RemoteMessage;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.NewIntentListener;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/** FirebaseMessagingPlugin */
public class FirebaseMessagingPlugin extends BroadcastReceiver
        implements MethodCallHandler, NewIntentListener {
  private final Registrar registrar;
  private final MethodChannel channel;

  private static final String CLICK_ACTION_VALUE = "FLUTTER_NOTIFICATION_CLICK";
  private static final String TAG = "FirebaseMessagingPlugin";

  public static void registerWith(Registrar registrar) {
    Log.d(TAG, "42 registerWith() executed!");
    Log.d(TAG, "43 registrar.messenger() es: " + registrar.messenger());
    Log.d(TAG, "44 registrar.activeContext().getClass() es: " + registrar.activeContext().getClass());
    Log.d(TAG, "45 registrar.context().getClass() es: " + registrar.context().getClass());
    Log.d(TAG, "46 registrar.activity() es: " + registrar.activity());
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "plugins.flutter.io/firebase_messaging");
    Log.d(TAG, "48 channel.toString() es: " + channel.toString());
    Log.d(TAG, "49 channel.getClass().getName() es: " + channel.getClass().getName());
    final MethodChannel backgroundCallbackChannel = new MethodChannel(registrar.messenger(), "plugins.flutter.io/firebase_messaging_background");

    final FirebaseMessagingPlugin plugin = new FirebaseMessagingPlugin(registrar, channel);

    registrar.addNewIntentListener(plugin);
    channel.setMethodCallHandler(plugin);
    backgroundCallbackChannel.setMethodCallHandler(plugin);

    FlutterFirebaseMessagingService.setBackgroundChannel(backgroundCallbackChannel);
    Log.d(TAG, "59 FIN registerWith() executed!");

    int imageId = registrar.activeContext().getResources().getIdentifier("ic_launcher", "mipmap", registrar.activeContext().getPackageName());

    FlutterFirebaseMessagingService.getPluginRegistryRegistrar();

    if(registrar.activity() != null) {
      int viewCollapseNotify = registrar.activeContext().getResources().getIdentifier("view_collapsed_notification", "layout", registrar.activeContext().getPackageName());
      int timeStamp = registrar.activeContext().getResources().getIdentifier("timestamp", "id", registrar.activeContext().getPackageName());
      FlutterFirebaseMessagingService.setPluginRegistryRegistrar(registrar.context(), registrar.activeContext().getClass().getName(), registrar.activeContext().getPackageName(), imageId, viewCollapseNotify, timeStamp);
      Log.d(TAG, "69 FIN setPluginRegistryRegistrar(registrar) executed!");
    } else if( registrar.activity() == null ) {
      FlutterFirebaseMessagingService.getPluginRegistryRegistrar();
    }
  }

  private FirebaseMessagingPlugin(Registrar registrar, MethodChannel channel) {
    Log.d(TAG, "99 FirebaseMessagingPlugin() constructor executed!");

    this.registrar = registrar;
    this.channel = channel;
    FirebaseApp.initializeApp(registrar.context());

    Log.d(TAG, "105 registrar.toString() es: " + registrar.toString());
    Log.d(TAG, "106 registrar.activeContext().getPackageName() es: " + registrar.activeContext().getPackageName());
    Log.d(TAG, "107 registrar.getPackageResourcePath() es: " + registrar.activeContext().getPackageResourcePath());
    Log.d(TAG, "108 registrar.getApplicationContext() es: " + registrar.activeContext().getApplicationContext());
    Log.d(TAG, "109 registrar.activity() es: " + registrar.activity());
    Log.d(TAG, "110 registrar.getPackageName() es: " + registrar.context().getPackageName());
    Log.d(TAG, "111 registrar.getClass() es: " + registrar.context().getClass());
    Log.d(TAG, "112 registrar.activeContext().getClass() es: " + registrar.activeContext().getClass());

    IntentFilter intentFilter = new IntentFilter();
    intentFilter.addAction(FlutterFirebaseMessagingService.ACTION_TOKEN);
    intentFilter.addAction(FlutterFirebaseMessagingService.ACTION_REMOTE_MESSAGE);
    LocalBroadcastManager manager = LocalBroadcastManager.getInstance(registrar.context());
    manager.registerReceiver(this, intentFilter);

    Log.d(TAG, "122 manager.registerReceiver(this, intentFilter) enviado!!!");
  }

  // BroadcastReceiver implementation.
  @Override
  public void onReceive(Context context, Intent intent) {
    Log.d(TAG, "103 @Override onReceive() executed!");

    Log.d(TAG, "105 registrar.activeContext() es: " + registrar.activeContext());
    Log.d(TAG, "106 registrar.activeContext().getClass() es: " + registrar.activeContext().getClass());
    Log.d(TAG, "107 registrar.activeContext().getClass().getName() es: " + registrar.activeContext().getClass().getName());


    String action = intent.getAction();

    Log.d(TAG, "112 action es: " + action);
    Log.d(TAG, "113 action == null es: " + (action == null));

    if (action == null) {
      return;
    }

    if (action.equals(FlutterFirebaseMessagingService.ACTION_TOKEN)) {
      Log.d(TAG, "120 action.equals es: " + action);
      String token = intent.getStringExtra(FlutterFirebaseMessagingService.EXTRA_TOKEN);
      Log.d(TAG, "122 token es: " + token);
      Log.d(TAG, "123 channel.invokeMethod() onToken()!");
      channel.invokeMethod("onToken", token);
    } else if (action.equals(FlutterFirebaseMessagingService.ACTION_REMOTE_MESSAGE)) {
      Log.d(TAG, "126 action.equals es: " + action);

      RemoteMessage message = intent.getParcelableExtra(FlutterFirebaseMessagingService.EXTRA_REMOTE_MESSAGE);
      Map<String, Object> content = parseRemoteMessage(message);
      Log.d(TAG, "130 channel.invokeMethod() onMessage()!");

      channel.invokeMethod("onMessage", content);
      Log.d(TAG, "133 channel.invokeMethod() onMessage()!");
    }
  }

  @NonNull
  private Map<String, Object> parseRemoteMessage(RemoteMessage message) {
    Map<String, Object> content = new HashMap<>();
    content.put("data", message.getData());

    RemoteMessage.Notification notification = message.getNotification();

    Map<String, Object> notificationMap = new HashMap<>();

    String title = notification != null ? notification.getTitle() : null;
    notificationMap.put("title", title);

    String body = notification != null ? notification.getBody() : null;
    notificationMap.put("body", body);

    content.put("notification", notificationMap);
    return content;
  }

  @Override
  public void onMethodCall(final MethodCall call, final Result result) {
    Log.d(TAG, "\n158 @Override onMethodCall() executed!");
    Log.d(TAG, "159 call.method es: " + call.method);
    Log.d(TAG, "160 call.arguments es: " + call.arguments);

    /*  Even when the app is not active the `FirebaseMessagingService` extended by
     *  `FlutterFirebaseMessagingService` allows incoming FCM messages to be handled.
     *
     *  `FcmDartService#start` and `FcmDartService#initialized` are the two methods used
     *  to optionally setup handling messages received while the app is not active.
     *
     *  `FcmDartService#start` sets up the plumbing that allows messages received while
     *  the app is not active to be handled by a background isolate.
     *
     *  `FcmDartService#initialized` is called by the Dart side when the plumbing for
     *  background message handling is complete.
     */
    if ("FcmDartService#start".equals(call.method)) {
      Log.d(TAG, "175 if (\"FcmDartService#start\")");
      Log.d(TAG, "176 call.method es: " + call.method);

      long setupCallbackHandle = 0;
      long backgroundMessageHandle = 0;
      try {
        Log.d(TAG, "181 call.arguments es: " + call.arguments);

        Map<String, Long> callbacks = ((Map<String, Long>) call.arguments);

        Log.d(TAG, "185 callbacks es: " + callbacks);

        setupCallbackHandle = callbacks.get("setupHandle");
        backgroundMessageHandle = callbacks.get("backgroundHandle");

        Log.d(TAG, "190 setupCallbackHandle es: " + setupCallbackHandle);
        Log.d(TAG, "191 backgroundMessageHandle es: " + backgroundMessageHandle);

      } catch (Exception e) {
        Log.e(TAG, "There was an exception when getting callback handle from Dart side");
        e.printStackTrace();
      }

      FlutterFirebaseMessagingService.setBackgroundSetupHandle(this.registrar.context(), setupCallbackHandle);
      FlutterFirebaseMessagingService.startBackgroundIsolate(this.registrar.context(), setupCallbackHandle);
      FlutterFirebaseMessagingService.setBackgroundMessageHandle(this.registrar.context(), backgroundMessageHandle);

      result.success(true);

    } else if ("FcmDartService#initialized".equals(call.method)) {
      Log.d(TAG, "205 else if (\"FcmDartService#initialized\")");
      Log.d(TAG, "206 call.method es: " + call.method);

      FlutterFirebaseMessagingService.onInitialized();

      Log.d(TAG, "210 result.success(true)");
      result.success(true);

    } else if ("configure".equals(call.method)) {
      Log.d(TAG, "214 else if (\"configure\")");
      Log.d(TAG, "215 call.method es: " + call.method);

      FirebaseInstanceId.getInstance()
              .getInstanceId()
              .addOnCompleteListener(
                      new OnCompleteListener<InstanceIdResult>() {
                        @Override
                        public void onComplete(@NonNull Task<InstanceIdResult> task) {
                          if (!task.isSuccessful()) {
                            Log.w(TAG, "getToken, error fetching instanceID: ", task.getException());
                            return;
                          }
                          Log.d(TAG, "227 channel.invokeMethod(onToken!) Invocando");
                          channel.invokeMethod("onToken", task.getResult().getToken());
                          Log.d(TAG, "229 channel.invokeMethod(onToken!) Invocado");
                        }
                      });

      Log.d(TAG, "233 (registrar.activity() != null) es: " + (registrar.activity() != null));

      if (registrar.activity() != null) {
        Log.d(TAG, "236 channel.invokeMethod(onLaunch!) Invocando");
        sendMessageFromIntent("onLaunch", registrar.activity().getIntent());
        Log.d(TAG, "238 channel.invokeMethod(onLaunch!) Invocado");
      }
      Log.d(TAG, "240 ANTES result.success(null) executed!");
      result.success(null);
      Log.d(TAG, "241 DESPUES result.success(null) executed!");

    } else if ("subscribeToTopic".equals(call.method)) {
      Log.d(TAG, "245 else if (\"subscribeToTopic\")");
      Log.d(TAG, "246 call.method es: " + call.method);

      String topic = call.arguments();
      FirebaseMessaging.getInstance()
              .subscribeToTopic(topic)
              .addOnCompleteListener(
                      new OnCompleteListener<Void>() {
                        @Override
                        public void onComplete(@NonNull Task<Void> task) {
                          if (!task.isSuccessful()) {
                            Exception e = task.getException();
                            Log.w(TAG, "subscribeToTopic error", e);
                            result.error("subscribeToTopic", e.getMessage(), null);
                            return;
                          }
                          Log.d(TAG, "261 result.success(null)");
                          result.success(null);
                          Log.d(TAG, "263 result.success(null)");
                        }
                      });

    } else if ("unsubscribeFromTopic".equals(call.method)) {
      Log.d(TAG, "268 else if (\"unsubscribeFromTopic\")");
      Log.d(TAG, "269 call.method es: " + call.method);

      String topic = call.arguments();
      FirebaseMessaging.getInstance()
              .unsubscribeFromTopic(topic)
              .addOnCompleteListener(
                      new OnCompleteListener<Void>() {
                        @Override
                        public void onComplete(@NonNull Task<Void> task) {
                          if (!task.isSuccessful()) {
                            Exception e = task.getException();
                            Log.w(TAG, "unsubscribeFromTopic error", e);
                            result.error("unsubscribeFromTopic", e.getMessage(), null);
                            return;
                          }
                          Log.d(TAG, "284 result.success(null)");
                          result.success(null);
                          Log.d(TAG, "286 result.success(null)");
                        }
                      });

    } else if ("getToken".equals(call.method)) {
      Log.d(TAG, "291 else if (\"getToken\")");
      Log.d(TAG, "292 call.method es: " + call.method);

      FirebaseInstanceId.getInstance()
              .getInstanceId()
              .addOnCompleteListener(
                      new OnCompleteListener<InstanceIdResult>() {
                        @Override
                        public void onComplete(@NonNull Task<InstanceIdResult> task) {
                          if (!task.isSuccessful()) {
                            Log.w(TAG, "getToken, error fetching instanceID: ", task.getException());
                            result.success(null);
                            return;
                          }

                          Log.d(TAG, "306 result.success(null)");
                          result.success(task.getResult().getToken());
                          Log.d(TAG, "308 result.success(null)");
                        }
                      });
    } else if ("deleteInstanceID".equals(call.method)) {
      Log.d(TAG, "312 else if (\"deleteInstanceID\")");
      Log.d(TAG, "313 call.method es: " + call.method);

      new Thread(
              new Runnable() {
                @Override
                public void run() {
                  try {
                    FirebaseInstanceId.getInstance().deleteInstanceId();
                    if (registrar.activity() != null) {
                      registrar
                              .activity()
                              .runOnUiThread(
                                      new Runnable() {
                                        @Override
                                        public void run() {
                                          Log.d(TAG, "328 result.success(true)");
                                          result.success(true);
                                          Log.d(TAG, "330 result.success(true)");
                                        }
                                      });
                    }
                  } catch (IOException ex) {
                    Log.e(TAG, "335 deleteInstanceID, error:", ex);
                    if (registrar.activity() != null) {
                      registrar
                              .activity()
                              .runOnUiThread(
                                      new Runnable() {
                                        @Override
                                        public void run() {
                                          Log.d(TAG, "343 result.success(false)");
                                          result.success(false);
                                          Log.d(TAG, "344 result.success(false)");
                                        }
                                      });
                    }
                  }
                }
              })
              .start();
    } else if ("autoInitEnabled".equals(call.method)) {
      Log.d(TAG, "354 else if (\"autoInitEnabled\")");
      Log.d(TAG, "355 call.method es: " + call.method);

      Log.d(TAG, "357 result.success(FirebaseMessaging.getInstance().isAutoInitEnabled())");
      result.success(FirebaseMessaging.getInstance().isAutoInitEnabled());
      Log.d(TAG, "359 result.success(FirebaseMessaging.getInstance().isAutoInitEnabled())");

    } else if ("setAutoInitEnabled".equals(call.method)) {
      Log.d(TAG, "362 else if (\"setAutoInitEnabled\")");
      Log.d(TAG, "363 call.method es: " + call.method);

      Boolean isEnabled = (Boolean) call.arguments();
      FirebaseMessaging.getInstance().setAutoInitEnabled(isEnabled);
      Log.d(TAG, "367 result.success(null)");
      result.success(null);
      Log.d(TAG, "369 result.success(null)");

    } else {
      Log.d(TAG, "372 result.notImplemented()");
      result.notImplemented();
    }
  }

  @Override
  public boolean onNewIntent(Intent intent) {
    Log.d(TAG, "379 onNewIntent() executed!");

    Log.d(TAG, "381 intent.getAction() es: " + intent.getAction());
    Log.d(TAG, "382 intent.getDataString() es: " + intent.getDataString());
    Log.d(TAG, "383 intent.getData() es: " + intent.getData());
    Log.d(TAG, "384 intent.getPackage() es: " + intent.getPackage());
    Log.d(TAG, "385 intent.getScheme() es: " + intent.getScheme());
    Log.d(TAG, "386 intent.getType() es: " + intent.getType());
    Log.d(TAG, "387 intent.getComponent() es: " + intent.getComponent());
    Log.d(TAG, "388 intent.getExtras() es: " + intent.getExtras());
    Log.d(TAG, "389 intent.getFlags() es: " + intent.getFlags());

    boolean res = sendMessageFromIntent("onResume", intent);
    Log.d(TAG, "392 res es: " + (res));
    Log.d(TAG, "393 registrar.activity() es: " + (registrar.activity()));
    Log.d(TAG, "394 res && registrar.activity() != null es: " + (res && registrar.activity() != null));
    if (res && registrar.activity() != null) {

      Log.d(TAG, "397 registrar.activity().setIntent(intent)");
      registrar.activity().setIntent(intent);
      Log.d(TAG, "3999 registrar.activity().setIntent(intent)");
    }

    Log.d(TAG, "402 retornando sin registrar.activity().setIntent(intent)" + (res));

    return res;
  }

  /** @return true if intent contained a message to send. */
  private boolean sendMessageFromIntent(String method, Intent intent) {
    Log.d(TAG, "409 sendMessageFromIntent() executed!");
    Log.d(TAG, "410 method es: " + method);
    Log.d(TAG, "411 extras es: " + intent.getExtras());

    Log.d(TAG, "413 CLICK_ACTION_VALUE es: " + CLICK_ACTION_VALUE);
    Log.d(TAG, "414 intent.getAction() es: " + intent.getAction());
    Log.d(TAG, "415 CLICK_ACTION_VALUE.equals(intent.getAction() es: " + CLICK_ACTION_VALUE.equals(intent.getAction()));

    Log.d(TAG, "417 intent.getStringExtra(\"click_action\") es: " + intent.getStringExtra("click_action"));
    Log.d(TAG, "418 CLICK_ACTION_VALUE.equals(intent.getAction() es: " + (CLICK_ACTION_VALUE.equals(intent.getStringExtra("click_action"))));


    if (CLICK_ACTION_VALUE.equals(intent.getAction())
            || CLICK_ACTION_VALUE.equals(intent.getStringExtra("click_action"))) {
      Map<String, Object> message = new HashMap<>();
      Bundle extras = intent.getExtras();

      Log.d(TAG, "426 extras es: " + extras);

      if (extras == null) {
        Log.d(TAG, "429 extras es NULL retornando :( ");
        return false;
      }

      Map<String, Object> notificationMap = new HashMap<>();
      Map<String, Object> dataMap = new HashMap<>();

      for (String key : extras.keySet()) {
        Object extra = extras.get(key);
        if (extra != null) {
          dataMap.put(key, extra);
        }
      }

      Log.d(TAG, "443 notificationMap es: " + notificationMap);
      Log.d(TAG, "444 dataMap es: " + dataMap);

      message.put("notification", notificationMap);
      message.put("data", dataMap);

      channel.invokeMethod(method, message);
      Log.d(TAG, "450 channel.invokeMethod(" + method +", message) executed");

      return true;
    }
    return false;
  }
}
