import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/firebase/auth_service.dart';
import 'services/supabase/supabase_config.dart';
import 'services/supabase/supabase_service.dart';
import 'struct/document_struct.dart';
import 'struct/search_struct.dart';

/// Entry point của ứng dụng StudyDocs
/// - Xác thực (Auth): Firebase Auth
/// - Cơ sở dữ liệu (Database) & Lưu trữ file (Storage): Supabase
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase cho Xác thực (Authentication)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Khởi tạo Supabase cho Cơ sở dữ liệu (Database) và Tệp tin (Storage)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final authService = AuthService();
  final supabaseService = SupabaseService(auth: FirebaseAuth.instance);
  final documentStruct = DocumentStruct(supabaseService);
  final searchStruct = SearchStruct(supabaseService);

  runApp(
    StudyDocsApp(
      authService: authService,
      supabaseService: supabaseService,
      documentStruct: documentStruct,
      searchStruct: searchStruct,
    ),
  );
}

/// Root widget - Cung cấp AuthService, SupabaseService và Structs qua Provider
class StudyDocsApp extends StatelessWidget {
  final AuthService authService;
  final SupabaseService supabaseService;
  final DocumentStruct documentStruct;
  final SearchStruct searchStruct;

  const StudyDocsApp({
    super.key,
    required this.authService,
    required this.supabaseService,
    required this.documentStruct,
    required this.searchStruct,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<SupabaseService>.value(value: supabaseService),
        Provider<DocumentStruct>.value(value: documentStruct),
        Provider<SearchStruct>.value(value: searchStruct),
      ],
      child: MaterialApp(
        title: 'StudyDocs',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// Cổng kiểm tra đăng nhập - tự động chuyển hướng theo Firebase Auth
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
