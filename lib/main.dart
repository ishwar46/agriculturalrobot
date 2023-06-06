import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'Styles/AppColor.dart';

late ConnectivityResult connectivityResult;
late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
GlobalKey<NavigatorState> gloablNavigatorKey = GlobalKey<NavigatorState>();
String? firebaseToken = "";
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColor.primary,
    ),
  );
  await CheckConnectivity();
  if (connectivityResult == ConnectivityResult.mobile) {
    await initializeFirebase();
  } else if (connectivityResult == ConnectivityResult.wifi) {
    await initializeFirebase();
  }
  runApp(const MyApp());
  configLoading();
}

Future CheckConnectivity() async {
  connectivityResult = await (Connectivity().checkConnectivity());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.notification?.title}");
}

void configLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.ripple
    ..loadingStyle = EasyLoadingStyle.custom
    ..backgroundColor = Colors.black38
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskType = EasyLoadingMaskType.clear
    ..maskColor = Colors.transparent
    ..indicatorColor = AppColor.primary
    ..textStyle = const TextStyle(
      color: Colors.white,
    )
    ..userInteractions = false
    ..fontSize = 12
    ..indicatorSize = 30.0
    ..dismissOnTap = false
    ..animationStyle = EasyLoadingAnimationStyle.scale
    ..toastPosition = EasyLoadingToastPosition.bottom;
}

Future initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      messaging.getToken().then((value) {
        firebaseToken = value;
        print("FIREBASE_TOKEN ${value!}");
      });
    } catch (ex) {
      print(ex);
    }
    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: "I am description",
      importance: Importance.high,
    );
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    try {
      await messaging.subscribeToTopic('uranus');
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (ex) {
      print(ex);
    }
    FirebaseCrashlytics.instance.app.setAutomaticDataCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (error) {
    EasyLoading.showToast("No Internet connection detected.",
        dismissOnTap: true);
  }
}

Future firebaseAppInitialize() async {
  await Firebase.initializeApp();
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  FirebaseMessaging.onMessage.listen((RemoteMessage event) {
    try {
      var data = event.data;
      flutterLocalNotificationsPlugin.show(
        data.hashCode,
        data.isNotEmpty ? data['title'].toString() : event.notification?.title,
        data.isNotEmpty ? data['body'].toString() : event.notification?.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            icon: '@mipmap/logo',
          ),
        ),
      );
    } catch (ex, s) {
      FirebaseCrashlytics.instance.recordError(ex, s, reason: "FCM Error");
    }
  });
  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    gloablNavigatorKey.currentState!.pushNamed('/notificationpage');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    if (connectivityResult == ConnectivityResult.mobile) {
      firebaseAppInitialize();
    } else if (connectivityResult == ConnectivityResult.wifi) {
      firebaseAppInitialize();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppLocale(),
      child: Consumer<AppLocale>(
        builder: (context, locale, child) {
          return MaterialApp(
            navigatorKey: gloablNavigatorKey,
            title: "SmartStaff",
            theme: lightThemeData,
            darkTheme: darkThemeData,
            themeMode: ThemeMode.light,
            home: SplashScreen(token: firebaseToken!),
            debugShowCheckedModeBanner: false,
            builder: EasyLoading.init(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: locale.locale,
            routes: const <String, WidgetBuilder>{},
          );
        },
      ),
    );
  }
}
