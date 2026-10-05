import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'pages/login.dart';
import 'pages/signup.dart';
import 'pages/home.dart';
import 'pages/create_post.dart';
import 'services/notification_service.dart';
import 'services/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initializeSessionStorage();

  // 안드로이드 맵 렌더러 최적화 (버퍼 문제 방지)
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  await NotificationService.initialize();
  await NotificationService.syncFcmTokenWithServer();
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '밥동무',
      // 앱 전체 테마 설정
      theme: ThemeData(
        primaryColor: const Color(0xFF81C784),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF81C784)),
      ),
      // 시작 경로 설정
      initialRoute: '/login',
      // 앱 전체 화면 이동 경로 정의
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const MainPage(),
        '/create-post': (context) => const CreatePostPage(),
      },
      // 디버그 배너 제거
      debugShowCheckedModeBanner: false,
    );
  }
}
