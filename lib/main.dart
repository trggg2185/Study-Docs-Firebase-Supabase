import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/firebase/auth_service.dart';
import 'services/supabase/borrow_service.dart';
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
    publishableKey: SupabaseConfig.anonKey, // anon key cũ = publishable key
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
        Provider<BorrowService>(create: (_) => BorrowService(supabaseService)),
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
          return _ProfileBootstrap(key: ValueKey(user.uid), user: user);
        }
        return const LoginPage();
      },
    );
  }
}

/// Tạo hồ sơ Supabase một lần sau khi đăng nhập, không chặn vào app nếu lỗi.
class _ProfileBootstrap extends StatefulWidget {
  final User user;

  const _ProfileBootstrap({super.key, required this.user});

  @override
  State<_ProfileBootstrap> createState() => _ProfileBootstrapState();
}

class _ProfileBootstrapState extends State<_ProfileBootstrap> {
  @override
  void initState() {
    super.initState();
    _ensureProfile();
  }

  Future<void> _ensureProfile() async {
    final supabase = context.read<SupabaseService>();
    try {
      await supabase.ensureProfile(
        uid: widget.user.uid,
        email: widget.user.email ?? '',
        fullName: widget.user.displayName ?? '',
      );
    } catch (e) {
      debugPrint('Không tạo được profile Supabase: $e');
    }

    // Lấy FCM token sau khi profile đã tồn tại; lỗi messaging không chặn vào app.
    await BorrowService.setupFcmToken(supabase);
  }

  @override
  Widget build(BuildContext context) => const HomePage();
}
