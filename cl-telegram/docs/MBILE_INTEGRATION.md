# Mobile Integration Guide

**cl-telegram** v0.16.0 - iOS and Android Platform Integration

---

## Overview

cl-telegram provides comprehensive mobile platform integration for iOS and Android, enabling:

- Push notifications (APNs/FCM)
- Background task execution
- Device capabilities access
- File system integration
- Biometric authentication
- Deep linking
- Network status monitoring

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    cl-telegram App                       │
├─────────────────────────────────────────────────────────┤
│              cl-telegram/mobile Package                  │
│  ┌─────────────────────┬─────────────────────────────┐  │
│  │   iOS Integration   │   Android Integration       │  │
│  │   - CFFI/UIKit      │   - JNI/Android SDK         │  │
│  │   - APNs            │   - FCM                     │  │
│  │   - BackgroundTasks │   - WorkManager             │  │
│  │   - CoreTelephony   │   - ConnectivityManager     │  │
│  └─────────────────────┴─────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│              Cross-Platform API Layer                    │
│  - Platform detection  - Unified push handling          │
│  - Network status      - Background task management     │
├─────────────────────────────────────────────────────────┤
│              cl-telegram Core (MTProto)                  │
└─────────────────────────────────────────────────────────┘
```

---

## Installation

### iOS

1. **Add cl-telegram to your iOS project:**

```bash
# Clone cl-telegram
git clone https://github.com/your-org/cl-telegram.git
```

2. **Configure Xcode project:**

```xml
<!-- Info.plist: Add URL scheme for deep linking -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>telegram</string>
    </array>
  </dict>
</array>

<!-- Add required capabilities -->
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
  <string>fetch</string>
  <string>processing</string>
</array>
```

3. **Load Lisp runtime in iOS app:**

```swift
import UIKit
import CLibTelegram  // CFFI bindings

@main
class TelegramAppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize cl-telegram
        cl_telegram_mobile_init()
        
        // Register for push notifications
        registerForPushNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to Lisp runtime
        let tokenHex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        cl_telegram_ios_set_device_token(tokenHex)
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle push notification in Lisp
        if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            cl_telegram_handle_push_notification(jsonString)
        }
        completionHandler(.newData)
    }
}
```

### Android

1. **Add cl-telegram to your Android project:**

```gradle
// settings.gradle
include ':cl-telegram'
project(':cl-telegram').projectDir = file('../cl-telegram/android')

// app/build.gradle
dependencies {
    implementation project(':cl-telegram')
    implementation 'com.google.firebase:firebase-messaging:23.3.1'
    implementation 'androidx.work:work-runtime-ktx:2.9.0'
}
```

2. **Configure AndroidManifest.xml:**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    
    <application>
        <!-- Deep link intent filter -->
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:scheme="telegram" />
            </intent-filter>
        </activity>
        
        <!-- FCM service -->
        <service
            android:name=".TelegramMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

3. **Initialize in Android app:**

```kotlin
class MainActivity : AppCompatActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize cl-telegram
        CLibTelegram.init(this)
        
        // Register for FCM
        FirebaseMessaging.getInstance().token
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    CLibTelegram.setFcmToken(task.result)
                }
            }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle deep link
        intent.data?.let { uri ->
            CLibTelegram.handleDeepLink(uri.toString())
        }
    }
}

class TelegramMessagingService : FirebaseMessagingService() {
    
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        remoteMessage.data["update"]?.let { updateJson ->
            CLibTelegram.handlePushNotification(updateJson)
        }
    }
    
    override fun onNewToken(token: String) {
        CLibTelegram.setFcmToken(token)
    }
}
```

---

## API Reference

### Platform Detection

```lisp
;; Check if running on mobile
(cl-telegram/mobile:mobile-platform-p)  ; => T or NIL

;; Check specific platform
(cl-telegram/mobile:ios-p)      ; => T if iOS
(cl-telegram/mobile:android-p)  ; => T if Android

;; Get platform info
(cl-telegram/mobile:get-platform-info)
;; => (:PLATFORM :IOS :MODEL "iPhone 15 Pro" :SYSTEM-VERSION "17.0" ...)
;; => (:PLATFORM :ANDROID :MODEL "Pixel 8 Pro" :SDK-VERSION 34 ...)
```

### Push Notifications

```lisp
;; Register for push (cross-platform)
(cl-telegram/mobile:register-push-notification
  :badge t    ; iOS only
  :sound t
  :alert t    ; iOS only
  :sender-id "123456789")  ; Android FCM sender ID

;; Returns device token
;; iOS: APNs device token (hex string)
;; Android: FCM registration token

;; Unregister from push
(cl-telegram/mobile:unregister-push-notification)

;; Handle incoming push
(cl-telegram/mobile:handle-push-notification
  "{\"update\":{\"message_id\":123,\"text\":\"Hello\"}}")

;; Send local notification
(cl-telegram/mobile:send-local-notification
  "New Message"
  "You have a new message"
  :badge 1
  :sound "default")
```

### Background Tasks

```lisp
;; Begin background task
(let ((task-id (cl-telegram/mobile:begin-background-task "sync-messages")))
  ;; Perform sync work
  (sync-pending-messages)
  ;; End background task
  (cl-telegram/mobile:end-background-task task-id))

;; Schedule periodic background task
(cl-telegram/mobile:schedule-background-task
  3600  ; Run every hour
  :name "periodic-sync")

;; Handle background task execution
(cl-telegram/mobile:handle-background-task task-id)
```

### Network Status

```lisp
;; Get network status
(cl-telegram/mobile:get-network-status)
;; => (:REACHABLE T :CONNECTION-TYPE 1 :NETWORK-NAME "WiFi")
;; CONNECTION-TYPE: 0=none, 1=wifi, 2=cellular, 3=bluetooth

;; Check if network reachable
(cl-telegram/mobile:network-reachable-p)  ; => T or NIL

;; Check connection type
(cl-telegram/mobile:is-wifi-connection)    ; => T or NIL
(cl-telegram/mobile:is-cellular-connection) ; => T or NIL
```

### Device Info

```lisp
;; Get device information
(cl-telegram/mobile:ios-get-device-info)
;; => (:MODEL "iPhone 15 Pro"
;;     :SYSTEM-VERSION "17.0"
;;     :DEVICE-NAME "iPhone 15 Pro"
;;     :SCREEN-WIDTH 1179
;;     :SCREEN-HEIGHT 2556
;;     :SCALE-FACTOR 3.0)

(cl-telegram/mobile:android-get-device-info)
;; => (:MODEL "Pixel 8 Pro"
;;     :SDK-VERSION 34
;;     :ANDROID-VERSION "14"
;;     :DEVICE-NAME "Pixel 8 Pro"
;;     :SCREEN-WIDTH 1344
;;     :SCREEN-HEIGHT 2992
;;     :DENSITY 3.5)

;; Check device capabilities
(cl-telegram/mobile:device-has-camera-p)      ; => T or NIL
(cl-telegram/mobile:device-has-microphone-p)  ; => T or NIL
(cl-telegram/mobile:device-supports-video-p)  ; => T or NIL

;; Get memory/storage info
(cl-telegram/mobile:get-device-memory)
;; => (:TOTAL 6144 :USED 2048 :FREE 4096 :UNIT "MB")

(cl-telegram/mobile:get-storage-info)
;; => (:TOTAL 256000 :USED 128000 :FREE 128000 :UNIT "MB")
```

### File System

```lisp
;; Get directory paths
(cl-telegram/mobile:get-app-data-directory)  ; Documents (iOS) / files (Android)
(cl-telegram/mobile:get-cache-directory)     ; Caches (iOS) / cache (Android)
(cl-telegram/mobile:get-temp-directory)      ; tmp (iOS) / code_cache (Android)

;; Save/load photo library
(cl-telegram/mobile:save-to-photo-library
  "/path/to/image.jpg"
  :album-name "Telegram")

(cl-telegram/mobile:load-from-photo-library :limit 10)
;; => ("/photos/image_1.jpg" "/photos/image_2.jpg" ...)
```

### Biometric Authentication

```lisp
;; Check if biometrics available
(cl-telegram/mobile:biometrics-available-p)  ; => T or NIL

;; Authenticate with FaceID/TouchID/Fingerprint
(cl-telegram/mobile:authenticate-with-biometrics
  "Authenticate to view secret chat")
;; => T if successful, NIL if failed
```

### Deep Linking

```lisp
;; Register deep link scheme (do once at app launch)
(cl-telegram/mobile:register-deep-link-scheme "telegram")

;; Handle incoming deep link
(cl-telegram/mobile:handle-deep-link "telegram://chat?id=123")
(cl-telegram/mobile:handle-deep-link "telegram://msg?id=456&chat=789")
```

### Clipboard

```lisp
;; Copy to clipboard
(cl-telegram/mobile:copy-to-clipboard "Text to copy")

;; Get from clipboard
(cl-telegram/mobile:get-from-clipboard)
;; => "Clipboard content" or NIL
```

---

## Supported Deep Link URLs

| URL Pattern | Description |
|-------------|-------------|
| `telegram://chat?id={chat_id}` | Open chat |
| `telegram://msg?id={msg_id}&chat={chat_id}` | Open specific message |
| `telegram://user?id={user_id}` | Open user profile |
| `telegram://settings` | Open settings |
| `telegram://secret-chat?id={chat_id}` | Open secret chat |

---

## Background Task Types

### iOS (BGTaskScheduler)

| Task Type | Identifier | Purpose |
|-----------|------------|---------|
| App Refresh | `cl-telegram.refresh` | Periodic sync |
| Processing | `cl-telegram.processing` | Message sync |

### Android (WorkManager)

| Task Type | Constraints | Purpose |
|-----------|-------------|---------|
| Periodic Sync | Network available | Message sync every 15min |
| One-time Sync | None | Immediate sync |

---

## Performance Considerations

### Battery Optimization

- Use background tasks sparingly
- Batch network requests
- Respect system power restrictions

### Memory Management

```lisp
;; Monitor memory usage
(let ((memory (cl-telegram/mobile:get-device-memory)))
  (when (< (getf memory :free) 100)  ; Less than 100MB free
    (trigger-garbage-collection)
    (cleanup-cache)))
```

### Network Efficiency

```lisp
;; Only sync on WiFi unless urgent
(when (cl-telegram/mobile:is-wifi-connection)
  (sync-pending-messages))
```

---

## Troubleshooting

### Push Notifications Not Working

**iOS:**
- Check APNs certificate in Apple Developer portal
- Verify device token is being passed to Lisp runtime
- Ensure `UIBackgroundModes` includes `remote-notification`

**Android:**
- Check FCM project configuration
- Verify `google-services.json` is in app directory
- Ensure `POST_NOTIFICATIONS` permission granted (Android 13+)

### Background Tasks Not Running

**iOS:**
- BGTaskScheduler requires device to be unlocked and charging for first run
- System decides when to run background tasks based on usage patterns

**Android:**
- WorkManager may delay tasks due to battery optimization
- Check WorkManager logs: `adb shell am set-debug-app --persistent com.example.telegram`

### Deep Links Not Working

- Verify URL scheme is registered in Info.plist/AndroidManifest.xml
- Test with `xcrun simctl openurl booted telegram://chat?id=123` (iOS)
- Test with `adb shell am start -a android.intent.action.VIEW -d telegram://chat?id=123` (Android)

---

## Security Considerations

1. **Biometric Authentication**: Use for secret chats and sensitive operations
2. **Keychain/Keystore**: Store encryption keys in platform secure storage
3. **Certificate Pinning**: Pin MTProto server certificates
4. **Jailbreak/Root Detection**: Check for compromised devices before handling sensitive data

---

## Testing

```lisp
;; Load test system
(asdf:load-system :cl-telegram/tests)

;; Run mobile tests
(cl-telegram/tests:run-mobile-tests)
```

---

## Resources

- [iOS Background Tasks Documentation](https://developer.apple.com/documentation/backgroundtasks)
- [Android WorkManager Documentation](https://developer.android.com/topic/libraries/architecture/workmanager)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)

---

**Version**: v0.16.0  
**Last Updated**: 2026-04-19
