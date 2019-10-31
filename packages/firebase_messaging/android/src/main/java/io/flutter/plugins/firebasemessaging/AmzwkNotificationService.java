package io.flutter.plugins.firebasemessaging;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
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
import android.text.format.DateUtils;
import android.util.Log;
import android.widget.EditText;
import android.widget.RemoteViews;

import androidx.core.app.NotificationCompat;
import androidx.core.app.RemoteInput;

import com.google.firebase.messaging.RemoteMessage;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.Map;

import static android.R.drawable.ic_delete;

//import android.support.v4.app.RemoteInput;
//import android.support.v4.app.NotificationCompat;

public class AmzwkNotificationService {
    public static final String NOTIFICATION_REPLY = "NotificationReply";
    public static final int NOTIFICATION_ID = 200;
    public static final int REQUEST_CODE_APPROVE = 101;
    public static final String KEY_INTENT_APPROVE = "keyintentaccept";

    public static final String NOTIFICATION_CHANNEL_ID = "channel_id";
    public static final String CHANNEL_NAME = "Notificaciones de mensage";

    private int numMessages = 0;

    EditText mEditText;

    private void sendNotification(RemoteMessage.Notification notification, Map<String, String> data, Context context) {
        //Bitmap icon = BitmapFactory.decodeResource(getResources(), R.mipmap.ic_launcher);

        PendingIntent approvePendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_APPROVE,
                new Intent(context, FirebaseMessagingPlugin.class).putExtra(KEY_INTENT_APPROVE, REQUEST_CODE_APPROVE),
                PendingIntent.FLAG_UPDATE_CURRENT
        );

        RemoteInput remoteInput = new RemoteInput.Builder((NOTIFICATION_REPLY))
                .setLabel("Enviar mensaje")
                .build();

        NotificationCompat.Action action = new NotificationCompat.Action.Builder(ic_delete, "Responder", approvePendingIntent)
                .addRemoteInput(remoteInput)
                .build();

        Bitmap bmpIcon = null;
        try {
//            InputStream in = new URL(notification.getImageUrl().toString()).openStream();
            InputStream in = new URL(data.get("image")).openStream();
            bmpIcon = BitmapFactory.decodeStream(in);
        } catch (IOException e) {
            e.printStackTrace();
        }

        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                //.setSmallIcon(R.mipmap.ic_launcher, 10)
                .setSmallIcon(R.drawable.common_google_signin_btn_text_dark)
                .setContentTitle(data.get("title"))   //notification.getTitle()
                .setContentText(data.get("body"))     //notification.getBody()
                .setAutoCancel(true)
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                .setContentIntent(approvePendingIntent)
                //.setContentIntent(PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class), 0))
                .setContentInfo("setContentInfo")
                .setLargeIcon(getCircleBitmap(bmpIcon))
                .setColor(Color.GREEN)
                .setLights(Color.GRAY, 1000, 300)
                .setDefaults(Notification.DEFAULT_VIBRATE)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVibrate(new long[] { 1000, 1000, 1000, 1000, 1000 })
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setBadgeIconType(NotificationCompat.BADGE_ICON_SMALL)
                .setContentInfo("setContentInfo")
                //.setNumber(++numMessages)
                //.setCustomContentView(collapsedView)
                //.setCustomBigContentView(expandedView)
                //.setStyle(new NotificationCompat.DecoratedCustomViewStyle());
                .addAction(action);

        NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            //CharSequence description = getString(R.string.default_notification_channel_id);
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

        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build());
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
}
