import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ocr/Login/login_screen.dart';
import 'package:ocr/MainScreen/main_screen.dart';
import 'package:ocr/providers/auth_provider.dart';
import 'package:ocr/providers/convert_provider.dart';
import 'package:ocr/providers/fileprovider.dart';
import 'package:ocr/providers/folderprovider.dart';
import 'package:ocr/providers/ocr_provider.dart';
import 'package:ocr/providers/subfolderprovider.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => FolderProvider()),
      ChangeNotifierProvider(create: (_) => SubFolderProvider()),
      ChangeNotifierProvider(create: (_) => FileProvider()),
      ChangeNotifierProvider(create: (_) => ConversionProvider()),
      ChangeNotifierProvider(create: (_) => OCRConversionProvider()),
    ],
    child: MaterialApp(title: 'OCR',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xC3000022)),
      useMaterial3: true
    ),
    initialRoute: '/Initial',
    routes: {
      '/Initial': (context) => const InitialScreen(),
      '/': (context) => const Login(),
      '/home': (context) => const MainScreen(),
    },),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
  }


  Future<void> _checkLoginStatus(BuildContext context) async {
    try{
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      bool isLoggedIn = await authProvider.isLoggedIn();

      if (isLoggedIn && !authProvider.expiredToken) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        await authProvider.logout();
        Navigator.pushReplacementNamed(context, '/');
      }
    }catch(e){
      if (kDebugMode) {
        print("Error in _checkLoginStatus: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkLoginStatus(context);
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0x000F32B4),)),
    );
  }
}