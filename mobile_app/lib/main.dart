import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/camera_service.dart';
import 'screens/splash_screen.dart';  // Changed from camera_screen

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (portrait only for better scanning)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MedicineLabelScannerApp());
}

class MedicineLabelScannerApp extends StatelessWidget {
  const MedicineLabelScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CameraService(),
      child: MaterialApp(
        title: 'Medicine Label Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        home: const SplashScreen(),  // Changed to SplashScreen
      ),
    );
  }
}