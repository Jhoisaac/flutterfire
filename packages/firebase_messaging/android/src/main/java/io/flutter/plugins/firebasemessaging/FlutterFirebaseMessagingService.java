// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.firebasemessaging;

import android.app.ActivityManager;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Handler;
import android.os.Process;
import android.text.format.DateUtils;
import android.util.Log;

import androidx.annotation.RequiresApi;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicBoolean;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;
import android.media.RingtoneManager;
import android.widget.RemoteViews;

import androidx.core.app.NotificationCompat;
import androidx.core.app.RemoteInput;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;

import static android.R.drawable.ic_delete;

public class FlutterFirebaseMessagingService extends FirebaseMessagingService {

  public static final String ACTION_REMOTE_MESSAGE = "io.flutter.plugins.firebasemessaging.NOTIFICATION";
  public static final String EXTRA_REMOTE_MESSAGE = "notification";

  public static final String ACTION_TOKEN = "io.flutter.plugins.firebasemessaging.TOKEN";
  public static final String EXTRA_TOKEN = "token";

  private static final String SHARED_PREFERENCES_KEY = "io.flutter.android_fcm_plugin";
  private static final String BACKGROUND_SETUP_CALLBACK_HANDLE_KEY = "background_setup_callback";
  private static final String BACKGROUND_MESSAGE_CALLBACK_HANDLE_KEY = "background_message_callback";
  private static final String SETUP_ACTIVITY_CLASS_HANDLE_KEY = "setup_activity_class_callback";
  private static final String SETUP_ACTIVITY_PACKAGE_HANDLE_KEY = "setup_activity_package_callback";
  private static final String SETUP_ACTIVITY_IC_LAUNCHER_HANDLE_KEY = "setup_ic_launcher_callback";
  private static final String SETUP_ACTIVITY_VIEW_COLLAPSE_HANDLE_KEY = "setup_view_collapse_callback";
  private static final String SETUP_ACTIVITY_TIMESTAMP_HANDLE_KEY = "setup_timestamp_callback";

  // TODO(kroikie): make isIsolateRunning per-instance, not static.
  private static AtomicBoolean isIsolateRunning = new AtomicBoolean(false);

  /** Background Dart execution context. */
  private static FlutterNativeView backgroundFlutterView;

  private static MethodChannel backgroundChannel;
  private static Class<?> classNameActivity;
  private static String packageNameActivity;
  private static int icLauncherActivity;
  private static Class<?> classNameReceiver;
  private static int viewCollapseNotify;
  private static int timeStamp;

  private static Long backgroundMessageHandle;

  private static List<RemoteMessage> backgroundMessageQueue = Collections.synchronizedList(new LinkedList<RemoteMessage>());

  private static PluginRegistry.PluginRegistrantCallback pluginRegistrantCallback;

  private static final String TAG = "FlutterFcmService";

  private static Context backgroundContext;

  public static final String NOTIFICATION_REPLY = "NotificationReply";
  public static final int NOTIFICATION_ID = 200;
  public static final int REQUEST_CODE_APPROVE = 101;
  public static final String KEY_INTENT_APPROVE = "keyintentaccept";

  public static final String NOTIFICATION_CHANNEL_ID = "channel_id";
  public static final String CHANNEL_NAME = "Notificaciones de mensage";

  private int numMessages = 0;

  public static String REPLY_ACTION = "io.flutter.plugins.firebasemessaging.REPLY_ACTION";

  private int mNotificationId;
  private int mMessageId;

  private static final String KEY_MESSAGE_ID = "key_message_id";
  private static final String KEY_NOTIFY_ID = "key_notify_id";

  @Override
  public void onCreate() {
    super.onCreate();

    backgroundContext = getApplicationContext();
    FlutterMain.ensureInitializationComplete(backgroundContext, null);

    if( classNameReceiver == null) {
      try {
        classNameReceiver = Class.forName("com.amazingwork.amazingwork.NotificationReceiver");
      } catch (ClassNotFoundException e) {
        e.printStackTrace();
      }
    }

    if(classNameActivity == null || packageNameActivity == null) {
      SharedPreferences p = backgroundContext.getSharedPreferences(SHARED_PREFERENCES_KEY, 0);

      String activityClassName = p.getString(SETUP_ACTIVITY_CLASS_HANDLE_KEY, "com.amazingwork.amazingwork.MainActivity");
      packageNameActivity = p.getString(SETUP_ACTIVITY_PACKAGE_HANDLE_KEY, "com.amazingwork.amazingworkmobile");
      icLauncherActivity = p.getInt(SETUP_ACTIVITY_IC_LAUNCHER_HANDLE_KEY, 2131361792);
      viewCollapseNotify = p.getInt(SETUP_ACTIVITY_VIEW_COLLAPSE_HANDLE_KEY, 0);

      classNameActivity = null;
      try {
        assert activityClassName != null;
        classNameActivity = Class.forName(activityClassName);
      } catch (ClassNotFoundException e) {
        e.printStackTrace();
      }
    }

    // If background isolate is not running start it.
    if (!isIsolateRunning.get()) {
      SharedPreferences p = backgroundContext.getSharedPreferences(SHARED_PREFERENCES_KEY, 0);
      long callbackHandle = p.getLong(BACKGROUND_SETUP_CALLBACK_HANDLE_KEY, 0);
      
      startBackgroundIsolate(backgroundContext, callbackHandle);
    }
  }

  /**
   * Called when message is received.
   *
   * @param remoteMessage Object representing the message received from Firebase Cloud Messaging.
   */
  @RequiresApi(api = Build.VERSION_CODES.KITKAT)
  @Override
  public void onMessageReceived(final RemoteMessage remoteMessage) {
    // If application is running in the foreground use local broadcast to handle message.
    // Otherwise use the background isolate to handle message.
    if (isApplicationForeground(this)) {
      Intent intent = new Intent(ACTION_REMOTE_MESSAGE);
      intent.putExtra(EXTRA_REMOTE_MESSAGE, remoteMessage);
      LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    } else {
      sendNotification(remoteMessage, this);
      // If background isolate is not running yet, put message in queue and it will be handled
      // when the isolate starts.
      /*if (!isIsolateRunning.get()) {
        backgroundMessageQueue.add(remoteMessage);
      } else {
        final CountDownLatch latch = new CountDownLatch(1);
        new Handler(getMainLooper())
                .post(
                        new Runnable() {
                          @Override
                          public void run() {
                            executeDartCallbackInBackgroundIsolate(
                                    FlutterFirebaseMessagingService.this, remoteMessage, latch);
                          }
                        });
        try {
          latch.await();
        } catch (InterruptedException ex) {
          Log.i(TAG, "Exception waiting to execute Dart callback", ex);
        }
      }*/
    }
  }

  /**
   * Called when a new token for the default Firebase project is generated.
   *
   * @param token The token used for sending messages to this application instance. This token is
   *     the same as the one retrieved by getInstanceId().
   */
  @Override
  public void onNewToken(String token) {
    Intent intent = new Intent(ACTION_TOKEN);
    intent.putExtra(EXTRA_TOKEN, token);
    LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
  }

  /**
   * Setup the background isolate that would allow background messages to be handled on the Dart
   * side. Called either by the plugin when the app is starting up or when the app receives a
   * message while it is inactive.
   *
   * @param context Registrar or FirebaseMessagingService context.
   * @param callbackHandle Handle used to retrieve the Dart function that sets up background
   *     handling on the dart side.
   */
  public static void startBackgroundIsolate(Context context, long callbackHandle) {
    FlutterMain.ensureInitializationComplete(context, null);
    String appBundlePath = FlutterMain.findAppBundlePath(context);
    FlutterCallbackInformation flutterCallback = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);
    
    if (flutterCallback == null) {
      Log.e(TAG, "Fatal: failed to find callback");
      return;
    }

    // Note that we're passing `true` as the second argument to our
    // FlutterNativeView constructor. This specifies the FlutterNativeView
    // as a background view and does not create a drawing surface.
    backgroundFlutterView = new FlutterNativeView(context, true);
    if (appBundlePath != null && !isIsolateRunning.get()) {
      if (pluginRegistrantCallback == null) {
        throw new RuntimeException("PluginRegistrantCallback is not set.");
      }
      FlutterRunArguments args = new FlutterRunArguments();
      args.bundlePath = appBundlePath;
      args.entrypoint = flutterCallback.callbackName;
      args.libraryPath = flutterCallback.callbackLibraryPath;
      backgroundFlutterView.runFromBundle(args);
      pluginRegistrantCallback.registerWith(backgroundFlutterView.getPluginRegistry());
    }
  }

  /**
   * Acknowledge that background message handling on the Dart side is ready. This is called by the
   * Dart side once all background initialization is complete via `FcmDartService#initialized`.
   */
  public static void onInitialized() {
    isIsolateRunning.set(true);
    synchronized (backgroundMessageQueue) {
      // Handle all the messages received before the Dart isolate was
      // initialized, then clear the queue.
      Iterator<RemoteMessage> i = backgroundMessageQueue.iterator();
      while (i.hasNext()) {
        executeDartCallbackInBackgroundIsolate(backgroundContext, i.next(), null);
      }
      backgroundMessageQueue.clear();
    }
  }

  /**
   * Set the method channel that is used for handling background messages. This method is only
   * called when the plugin registers.
   *
   * @param channel Background method channel.
   */
  public static void setBackgroundChannel(MethodChannel channel) {
    backgroundChannel = channel;
  }

  public static void setPluginRegistryRegistrar(Context context, String classNameActivity, String packageNameActivity, int icLauncherId, int viewCollapseNotify, int timeStamp) {
    // Store background setup handle in shared preferences so it can be retrieved by other application instances.
    SharedPreferences prefs = context.getSharedPreferences(SHARED_PREFERENCES_KEY, 0);
    prefs.edit().putString(SETUP_ACTIVITY_CLASS_HANDLE_KEY, classNameActivity).apply();
    prefs.edit().putString(SETUP_ACTIVITY_PACKAGE_HANDLE_KEY, packageNameActivity).apply();
    prefs.edit().putInt(SETUP_ACTIVITY_IC_LAUNCHER_HANDLE_KEY, icLauncherId).apply();
    prefs.edit().putInt(SETUP_ACTIVITY_VIEW_COLLAPSE_HANDLE_KEY, viewCollapseNotify).apply();
    prefs.edit().putInt(SETUP_ACTIVITY_TIMESTAMP_HANDLE_KEY, timeStamp).apply();
  }

  public static void getPluginRegistryRegistrar() {
    Log.e(TAG, "getPluginRegistryRegistrar()");
    Log.e(TAG, "classNameActivity  es: " + classNameActivity);
  }

  /**
   * Set the background message handle for future use. When background messages need to be handled
   * on the Dart side the handler must be retrieved in the background isolate to allow processing of
   * the incoming message. This method is called by the Dart side via `FcmDartService#start`.
   *
   * @param context Registrar context.
   * @param handle Handle representing the Dart side method that will handle background messages.
   */
  public static void setBackgroundMessageHandle(Context context, Long handle) {
    backgroundMessageHandle = handle;

    // Store background message handle in shared preferences so it can be retrieved
    // by other application instances.
    SharedPreferences prefs = context.getSharedPreferences(SHARED_PREFERENCES_KEY, 0);
    prefs.edit().putLong(BACKGROUND_MESSAGE_CALLBACK_HANDLE_KEY, handle).apply();
  }

  /**
   * Set the background message setup handle for future use. The Dart side of this plugin has a
   * method that sets up the background method channel. When ready to setup the background channel
   * the Dart side needs to be able to retrieve the setup method. This method is called by the Dart
   * side via `FcmDartService#start`.
   *
   * @param context Registrar context.
   * @param setupBackgroundHandle Handle representing the dart side method that will setup the
   *     background method channel.
   */
  public static void setBackgroundSetupHandle(Context context, long setupBackgroundHandle) {
    // Store background setup handle in shared preferences so it can be retrieved
    // by other application instances.
    SharedPreferences prefs = context.getSharedPreferences(SHARED_PREFERENCES_KEY, 0);
    prefs.edit().putLong(BACKGROUND_SETUP_CALLBACK_HANDLE_KEY, setupBackgroundHandle).apply();
  }

  /**
   * Retrieve the background message handle. When a background message is received and must be
   * processed on the dart side the handle representing the Dart side handle is retrieved so the
   * appropriate method can be called to process the message on the Dart side. This method is called
   * by FlutterFirebaseMessagingServcie either when a new background message is received or if
   * background messages were queued up while background message handling was being setup.
   *
   * @param context Application context.
   * @return Dart side background message handle.
   */
  public static Long getBackgroundMessageHandle(Context context) {
    return context
        .getSharedPreferences(SHARED_PREFERENCES_KEY, 0)
        .getLong(BACKGROUND_MESSAGE_CALLBACK_HANDLE_KEY, 0);
  }

  /**
   * Process the incoming message in the background isolate. This method is called only after
   * background method channel is setup, it is called by FlutterFirebaseMessagingServcie either when
   * a new background message is received or after background method channel setup for queued
   * messages received during setup.
   *
   * @param context Application or FirebaseMessagingService context.
   * @param remoteMessage Message received from Firebase Cloud Messaging.
   * @param latch If set will count down when the Dart side message processing is complete. Allowing
   *     any waiting threads to continue.
   */
  private static void executeDartCallbackInBackgroundIsolate(Context context, RemoteMessage remoteMessage, final CountDownLatch latch) {
    if (backgroundChannel == null) {
      throw new RuntimeException(
          "setBackgroundChannel was not called before messages came in, exiting.");
    }

    // If another thread is waiting, then wake that thread when the callback returns a result.
    MethodChannel.Result result = null;
    if (latch != null) {
      result = new LatchResult(latch).getResult();
    }

    Map<String, Object> args = new HashMap<>();
    Map<String, Object> messageData = new HashMap<>();
    if (backgroundMessageHandle == null) {
      backgroundMessageHandle = getBackgroundMessageHandle(context);
    }
    args.put("handle", backgroundMessageHandle);

    if (remoteMessage.getData() != null) {
      messageData.put("data", remoteMessage.getData());
    }
    if (remoteMessage.getNotification() != null) {
      messageData.put("notification", remoteMessage.getNotification());
    }

    args.put("message", messageData);
    
    backgroundChannel.invokeMethod("handleBackgroundMessage", args, result);
  }

  /**
   * Set the registrant callback. This is called by the app's Application class if background
   * message handling is enabled.
   *
   * @param callback Application class which implements PluginRegistrantCallback.
   */
  public static void setPluginRegistrant(PluginRegistry.PluginRegistrantCallback callback) {
    pluginRegistrantCallback = callback;
  }

  /**
   * Identify if the application is currently in a state where user interaction is possible. This
   * method is only called by FlutterFirebaseMessagingService when a message is received to
   * determine how the incoming message should be handled.
   *
   * @param context FlutterFirebaseMessagingService context.
   * @return True if the application is currently in a state where user interaction is possible,
   *     false otherwise.
   */
  // TODO(kroikie): Find a better way to determine application state.
  private static boolean isApplicationForeground(Context context) {
    KeyguardManager keyguardManager =
        (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);

    if (keyguardManager.inKeyguardRestrictedInputMode()) {
      return false;
    }
    int myPid = Process.myPid();

    ActivityManager activityManager =
        (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);

    List<ActivityManager.RunningAppProcessInfo> list;
    
    if ((list = activityManager.getRunningAppProcesses()) != null) {
      for (ActivityManager.RunningAppProcessInfo aList : list) {
        ActivityManager.RunningAppProcessInfo info;
        
        if ((info = aList).pid == myPid) {
          return info.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND;
        }
      }
    }
    
    return false;
  }

  // TODO(jh0n4): Improve implementation
  @RequiresApi(api = Build.VERSION_CODES.KITKAT)
  private void sendNotification(RemoteMessage remoteMessage, Context context) {
    // Check if message contains a data payload.
    if (remoteMessage.getData().size() == 0 || remoteMessage.toIntent().getExtras() == null) {
      return;
    }

    // Check if message contains a notification payload.
    if (remoteMessage.getNotification() != null) {
      Log.e(TAG, "Message Notification Body: " + remoteMessage.getNotification().getBody());
    }

    final Map<String, String> data = remoteMessage.getData();

    JSONObject dataChat = null;
    String subtotalPed = "0.00";

    try {
      dataChat = new JSONObject(data.get("data_chat"));

      subtotalPed = dataChat.getString("subtotalPedido");
    } catch (JSONException e) {
      e.printStackTrace();
    }

    int colorNotify = Color.GRAY;

    try {
      colorNotify = Integer.decode(data.get("color"));
    } catch (Exception e) {
      Log.e(TAG, "Could not parse " + e);
    }

    int NotifyId = 0;

    try {
      NotifyId = Integer.parseInt(data.get("tag"));
    } catch(NumberFormatException nfe) {
      Log.e(TAG, "Could not parse " + nfe);
    }

    Intent replyIntent = new Intent(context, classNameReceiver);
    replyIntent.putExtra("channelId", data.get("tag"));
    replyIntent.putExtra(KEY_INTENT_APPROVE, REQUEST_CODE_APPROVE);
    replyIntent.putExtra("data", remoteMessage.toIntent().getExtras());

    PendingIntent approvePendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_APPROVE,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT
    );

    // 1. Build label
    String replyLabel = "Enviar mensaje";
    RemoteInput remoteInput = new RemoteInput.Builder(NOTIFICATION_REPLY)
            .setLabel(replyLabel)
            .build();

    // 2. Build action
    NotificationCompat.Action replyAction = new NotificationCompat.Action.Builder(
            ic_delete, "Responder", approvePendingIntent)
            .addRemoteInput(remoteInput)
//            .setAllowGeneratedReplies(true)
            .build();

    // 3. Build notification
    Intent intent = new Intent(context, classNameActivity);
    intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .setPackage(packageNameActivity)
            .setAction(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .putExtras(remoteMessage.toIntent().getExtras());


    PendingIntent pi = PendingIntent.getActivity(context, NotifyId, intent, PendingIntent.FLAG_UPDATE_CURRENT); // FLAG_ONE_SHOT

//    int imageId = registrar.activeContext().getResources().getIdentifier("ic_launcher", "mipmap", registrar.activeContext().getPackageName());
//    Bitmap icon = BitmapFactory.decodeResource(getResources(), R.mipmap.ic_launcher);

//    String channelId = getString(R.string.default_notification_channel_id);
    NotificationCompat.Builder notificationBuilder =
            new NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                    .setSmallIcon(icLauncherActivity, 10)   //.setSmallIcon(R.mipmap.ic_launcher, 10)
                    .setContentTitle(data.get("title"))           //notification.getTitle()
                    .setContentText(data.get("body"))             //notification.getBody()  0x0288d1-Azul 0x4caf50-Verde
                    .setAutoCancel(true)
                    .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                    .setContentIntent(pi)
//                    .setContentInfo("setContentInfo")
//                    .setLargeIcon(getLargeIcon(data))
//                    .setTicker("setTicker")
                    .setColor(colorNotify)
                    .setLights(Color.GRAY, 1000, 300)
                    .setColorized(true)
//                    .setDefaults(Notification.DEFAULT_VIBRATE)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setVibrate(new long[] { 1000, 1000, 1000, 1000, 1000 })
                    .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                    .setBadgeIconType(NotificationCompat.BADGE_ICON_SMALL)
//                    .setContentInfo("setContentInfo")
                    .setNumber(++numMessages)
                    //.setStyle(new NotificationCompat.DecoratedCustomViewStyle());
                    //.setCustomContentView(collapsedView)
                    //.setCustomBigContentView(expandedView)
                    .setStyle(new NotificationCompat.BigPictureStyle()
                            .setBigContentTitle(data.get("title"))
                            .setSummaryText(data.get("description"))
                            .bigPicture(getLargeIcon(data))
                            .bigLargeIcon(null));

    NotificationManager notificationManager =
            (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

    // Since android Oreo notification channel is needed.
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
      CharSequence description = "Channel Description"; //CharSequence description = getString(R.string.default_notification_channel_id);
      String name = "YOUR_CHANNEL_NAME";      // CharSequence channelName = "Some Channel";
      int importance = NotificationManager.IMPORTANCE_HIGH;

      NotificationChannel channel = new NotificationChannel(NOTIFICATION_CHANNEL_ID, CHANNEL_NAME, importance);
      channel.setDescription("YOUR_NOTIFICATION_CHANNEL_DISCRIPTION");

      channel.enableLights(true);
      channel.setLightColor(Color.RED);
      channel.enableVibration(true);
      channel.setVibrationPattern(new long[]{100, 200, 300, 400, 500, 400, 300, 200, 400});

      notificationManager.createNotificationChannel(channel);
    }

    if (android.os.Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
      notificationBuilder.addAction(replyAction);
    }

    /*if( data.get("action").equals("valor_enviado") ) {
      Intent approveReceive = new Intent(context, classNameReceiver);
      approveReceive.setAction("com.amazingwork.amazingwork.PEDIDO");

      approveReceive.putExtra("channelId", data.get("tag"));
      approveReceive.putExtra(KEY_INTENT_APPROVE, REQUEST_CODE_APPROVE);
      approveReceive.putExtra("data", remoteMessage.toIntent().getExtras());

      PendingIntent pendingIntentYes = PendingIntent.getBroadcast(this, 12345, approveReceive, PendingIntent.FLAG_UPDATE_CURRENT);
      notificationBuilder.addAction(ic_menu_send, "Aprobar", pendingIntentYes);
    }*/

    notificationManager.notify(NotifyId, notificationBuilder.build());
  }

  @RequiresApi(api = Build.VERSION_CODES.KITKAT)
  private Bitmap getLargeIcon(Map<String, String> data) {
    String imageNotif = data.get("image");
    Bitmap bmpIcon = null;
    try {
      InputStream in = new URL(data.get("image")).openStream();    //InputStream in = new URL(notification.getImageUrl().toString()).openStream();
      bmpIcon = BitmapFactory.decodeStream(in);

    } catch (IOException e) {
      e.printStackTrace();
    }

//    return getCircleBitmap(bmpIcon);
    return bmpIcon;
  }

  private Bitmap getCircleBitmap(Bitmap bitmap) {
    final Bitmap output = Bitmap.createBitmap(bitmap.getWidth(),
            bitmap.getHeight(), Bitmap.Config.ARGB_8888);
    final Canvas canvas = new Canvas(output);

    final int color = Color.RED;
    final Paint paint = new Paint();
    final Rect rect = new Rect(0, 0, bitmap.getWidth(), bitmap.getHeight());
    final RectF rectF = new RectF(rect);

    paint.setAntiAlias(true);
    canvas.drawARGB(0, 0, 0, 0);
    paint.setColor(color);
    canvas.drawOval(rectF, paint);

    paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN));
    canvas.drawBitmap(bitmap, rect, rect, paint);

    bitmap.recycle();

    return output;
  }

  private PendingIntent getReplyPendingIntent(Context context, Class<?> broadCastReceiver) {
    Intent intent;
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
      intent = getReplyMessageIntent(context, mNotificationId, mMessageId, broadCastReceiver);

      return PendingIntent.getBroadcast(
              context,
              REQUEST_CODE_APPROVE, // 100
              intent,
              PendingIntent.FLAG_UPDATE_CURRENT
      );

    } else {
      // start your activity
      intent = getReplyMessageIntent(context, mNotificationId, mMessageId, broadCastReceiver);
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      return PendingIntent.getActivity(
              context,
              REQUEST_CODE_APPROVE, // 100
              intent,
              PendingIntent.FLAG_UPDATE_CURRENT
      );
    }
  }

  private Intent getReplyMessageIntent(Context context, int notificationId, int messageId, Class<?> broadCastReceiver) {
    Intent intent = new Intent(context, broadCastReceiver);
    intent.setAction(REPLY_ACTION);
    intent.putExtra(KEY_NOTIFY_ID, notificationId);
    intent.putExtra(KEY_MESSAGE_ID, messageId);
    return intent;
  }
}