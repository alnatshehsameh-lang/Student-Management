import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/students_screen.dart';
import 'screens/attendance_report_screen.dart';
import 'models/user_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://stjaqnjspyfvvwdzjnbi.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN0amFxbmpzcHlmdnZ3ZHpqbmJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwNTQ1NTIsImV4cCI6MjA3NDYzMDU1Mn0.PnWz3ISGVz88FaA8GR7rYudaAQdVLpuJKBHMMXPi7dE',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Modern theme inspired by Gospel Dashboard: purple primary, soft backgrounds
    final seed = const Color(0xFF6366F1); // vibrant purple/indigo
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light).copyWith(
      primary: const Color(0xFF6366F1),
      secondary: const Color(0xFF3B82F6),
      tertiary: const Color(0xFF10B981),
      surface: Colors.white,
    );

    final darkColorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF818CF8),
      secondary: const Color(0xFF60A5FA),
      tertiary: const Color(0xFF34D399),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Test Application',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        // Typography: use Tajawal from Google Fonts for a modern Arabic-friendly UI
        textTheme: GoogleFonts.tajawalTextTheme().copyWith(
          displayLarge: GoogleFonts.tajawal(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
          displayMedium: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
          titleLarge: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
          bodyLarge: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
          bodyMedium: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF6B7280)),
          labelLarge: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.primary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.05),
          centerTitle: true,
          titleTextStyle: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
          iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w600),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
          labelStyle: GoogleFonts.tajawal(color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
        ),
        cardColor: Colors.white,
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(8),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF6366F1)),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          headingTextStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF6B7280)),
          dataTextStyle: GoogleFonts.tajawal(fontSize: 14, color: const Color(0xFF374151)),
          dividerThickness: 1,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        primaryColor: darkColorScheme.primary,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        // Dark typography using Tajawal
        textTheme: GoogleFonts.tajawalTextTheme(ThemeData(brightness: Brightness.dark).textTheme).copyWith(
          displayLarge: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700),
          bodyLarge: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
          bodyMedium: GoogleFonts.tajawal(fontSize: 14, color: Colors.white70),
          labelLarge: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: darkColorScheme.primary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.surfaceContainerHighest,
          foregroundColor: darkColorScheme.onSurfaceVariant,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w700, color: darkColorScheme.onSurfaceVariant),
          iconTheme: IconThemeData(color: darkColorScheme.onSurfaceVariant),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkColorScheme.primary,
            foregroundColor: darkColorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            textStyle: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1220),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkColorScheme.outline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkColorScheme.outline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkColorScheme.primary, width: 2)),
          labelStyle: GoogleFonts.tajawal(color: darkColorScheme.primary, fontWeight: FontWeight.w600),
        ),
        cardColor: const Color(0xFF071226),
        iconTheme: IconThemeData(color: darkColorScheme.primary),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(darkColorScheme.surfaceContainerHighest.withOpacity(0.12)),
          headingTextStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: Colors.white70),
          dataTextStyle: GoogleFonts.tajawal(color: Colors.white70),
          dividerThickness: 0.5,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(),
      // Ensure Arabic/RTL hints — the screens also use Directionality where appropriate.
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _client = Supabase.instance.client;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور';
        _isLoading = false;
      });
      return;
    }

    // Check hardcoded admin credentials first
    if (username == 'admin' && password == 'admin') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userSession: UserSession(isAdmin: true, username: 'admin'),
            ),
          ),
        );
      }
      return;
    }

    try {
      // Query Users table for matching username and password
      final response = await _client
          .from('Users')
          .select('id, username, email')
          .eq('username', username)
          .eq('password', password)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Login successful - create user session without class_id (will fetch on Groups screen)
        final userSession = UserSession(
          userId: response['id'],
          username: response['username'],
          classId: null,
          isAdmin: false,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(userSession: userSession),
            ),
          );
        }
      } else {
        // No matching user found
        setState(() {
          _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في الاتصال: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F3FF), Color(0xFFDEEBFF), Color(0xFFDCFCE7), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.92 * 255).round()),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withAlpha((0.08 * 255).round()),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              width: 370,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF185A9D)),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      labelStyle: const TextStyle(color: Color(0xFF185A9D)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFBEE3F8)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFBEE3F8).withAlpha((0.25 * 255).round()),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      labelStyle: const TextStyle(color: Color(0xFF185A9D)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFE0E6)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFFE0E6).withAlpha((0.25 * 255).round()),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Color(0xFF185A9D)),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 18),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'دخول',
                              style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final UserSession userSession;
  const HomeScreen({super.key, required this.userSession});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _client = Supabase.instance.client;
  int _totalStudents = 0;
  int _totalGroups = 0;
  int _weeklyAttendance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    try {
      // Get total students count using limit with high value
      final studentsRes = await _client
          .from('Students')
          .select('id', const FetchOptions(count: CountOption.exact))
          .range(0, 0);
      _totalStudents = studentsRes.count ?? 0;

      // Get total groups count
      final groupsRes = await _client
          .from('Groups')
          .select('id', const FetchOptions(count: CountOption.exact))
          .range(0, 0);
      _totalGroups = groupsRes.count ?? 0;

      // Get weekly attendance (last 7 days from both tables)
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoStr = weekAgo.toIso8601String();

      final tadaburRes = await _client.from('Attendance_Tadabur')
        .select('id')
        .gte('Report_date', weekAgoStr);
      final sardRes = await _client.from('Attendance_Sard')
        .select('id')
        .gte('Report_date', weekAgoStr);
      
      final tadCount = tadaburRes is List ? tadaburRes.length : 0;
      final sardCount = sardRes is List ? sardRes.length : 0;
      _weeklyAttendance = tadCount + sardCount;
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            // Left Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo and title
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.menu_book, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لوحة التحكم',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'نظام إدارة الحلقات',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      children: [
                        _NavItem(
                          icon: Icons.home,
                          label: 'الرئيسية',
                          isActive: true,
                          onTap: () {},
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            'إدارة الحلقات',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _NavItem(
                          icon: Icons.school,
                          label: 'الطلاب',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentsScreen(userSession: widget.userSession),
                              ),
                            );
                          },
                        ),
                        _NavItem(
                          icon: Icons.group,
                          label: 'المجموعات',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupsScreen(userSession: widget.userSession),
                              ),
                            );
                          },
                        ),
                        _NavItem(
                          icon: Icons.supervisor_account,
                          label: 'المشرفون',
                          onTap: () {},
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            'التقارير',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _NavItem(
                          icon: Icons.assessment,
                          label: 'تقرير الحضور',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AttendanceReportScreen(userSession: widget.userSession),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            'الإعدادات',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _NavItem(
                          icon: Icons.settings,
                          label: 'الإعدادات',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _NavItem(
                      icon: Icons.logout,
                      label: 'تسجيل الخروج',
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Main content area
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'نظرة عامة على لوحة التحكم',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'مرحباً بعودتك! إليك ما يحدث في نظام إدارة الحلقات.',
                            style: TextStyle(
                              fontSize: 16,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dashboard content
                    Expanded(
                      child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stat cards grid
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    int columns = 4;
                                    if (constraints.maxWidth < 1200) columns = 3;
                                    if (constraints.maxWidth < 900) columns = 2;
                                    if (constraints.maxWidth < 600) columns = 1;

                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 20,
                                      crossAxisSpacing: 20,
                                      childAspectRatio: 1.8,
                                      children: [
                                        _StatCard(
                                          title: 'إجمالي الطلاب',
                                          value: _totalStudents.toString(),
                                          icon: Icons.school,
                                          color: const Color(0xFFF5F3FF),
                                          iconColor: const Color(0xFF6366F1),
                                          subtitle: 'طالب مسجل',
                                        ),
                                        _StatCard(
                                          title: 'إجمالي المجموعات',
                                          value: _totalGroups.toString(),
                                          icon: Icons.group,
                                          color: const Color(0xFFDEEBFF),
                                          iconColor: const Color(0xFF3B82F6),
                                          subtitle: 'مجموعة نشطة',
                                        ),
                                        _StatCard(
                                          title: 'الحضور الأسبوعي',
                                          value: _weeklyAttendance.toString(),
                                          icon: Icons.calendar_today,
                                          color: const Color(0xFFDCFCE7),
                                          iconColor: const Color(0xFF10B981),
                                          subtitle: 'آخر 7 أيام',
                                        ),
                                        _StatCard(
                                          title: 'التقارير النشطة',
                                          value: '0',
                                          icon: Icons.assessment,
                                          color: const Color(0xFFFEF3C7),
                                          iconColor: const Color(0xFFF59E0B),
                                          subtitle: 'قيد المراجعة',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}



class GroupsScreen extends StatefulWidget {
  final UserSession userSession;
  const GroupsScreen({super.key, required this.userSession});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];
  // per-group students
  bool _studentsLoading = false;
  List<Map<String, dynamic>> _students = [];
  final Map<dynamic, String> _classesMap = {};
  final Map<dynamic, String> _typesMap = {};
  int? _selectedGroupId;
  // per-group distinct type entries (id,label) to show immediately after selecting group
  List<Map<String, String>> _typeEntries = [];
  dynamic _selectedTypeId;
  // class entries under selected type
  List<Map<String, String>> _classEntries = [];
  dynamic _selectedClassId;
  // Report date shown above the table
  DateTime _reportDate = DateTime.now();
  bool _savingAttendance = false;
  // Active report tab: 'tadabur' or 'sard'
  String _activeReportTab = 'tadabur';
  bool _hasUnsavedChanges = false;
  // track whether Tadabur or Sard has already been submitted for the current class+date
  bool _tadaburSubmitted = false;
  bool _sardSubmitted = false;
  // in-app debug log (recent first)
  final List<String> _debugLogs = [];
  // User's restrictions (fetched from Managers table)
  int? _userClassId;
  int? _userGroupId;
  int? _userTypeId;

  @override
  void initState() {
    super.initState();
    _fetchUserRestrictions();
    _fetchGroups();
  }

  Future<void> _fetchUserRestrictions() async {
    // Skip if admin or no userId
    if (widget.userSession.isAdmin || widget.userSession.userId == null) {
      return;
    }

    try {
      final response = await _client
          .from('Managers')
          .select('Class_id, Group_id, Type_id')
          .eq('User_id', widget.userSession.userId!)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _userClassId = response['Class_id'];
          _userGroupId = response['Group_id'];
          _userTypeId = response['Type_id'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch user restrictions from Managers: $e');
    }
  }

  Future<void> _fetchGroups() async {
    setState(() => _loading = true);
    try {
      // Fetch groups and include nested Students to compute counts on the client.
      // Apply Group_id filter if user has restriction
      var builder = _client.from('Groups').select('id, "Group_Name", Students(id)');
      if (!widget.userSession.isAdmin && _userGroupId != null) {
        builder = builder.eq('id', _userGroupId!);
      }
      final res = await builder.range(0, 1000);
      if (res is List) {
        _groups = List<Map<String, dynamic>>.from(res);
      } else {
        _groups = [];
      }
    } catch (e) {
      _groups = [];
      debugPrint('GroupsScreen: fetch error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading groups: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المجموعات'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchGroups)],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // horizontal list of group cards (with counts and selected highlight)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المجموعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_selectedGroupId != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedGroupId = null;
                                _students = [];
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('مسح الاختيار'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: _groups.isEmpty
                          ? const Center(child: Text('لا توجد مجموعات'))
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _groups.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final g = _groups[idx];
                                final gid = g['id'];
                                final name = g['Group_Name'] ?? g['group_name'] ?? g['GroupName'] ?? '';
                                final studentsList = (g['Students'] is List) ? List.from(g['Students']) : <dynamic>[];
                                final count = studentsList.length;
                                final selected = _selectedGroupId != null && _selectedGroupId == gid;
                                return GestureDetector(
                                  onTap: () => _fetchStudentsForGroup(gid),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFFBEE3F8) : const Color(0xFFE2E0FF),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: selected ? [BoxShadow(color: Colors.black12.withAlpha(40), blurRadius: 8)] : [BoxShadow(color: Colors.black12.withAlpha(20), blurRadius: 6)],
                                      border: selected ? Border.all(color: const Color(0xFF185A9D), width: 2) : null,
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          children: [
                                            const Center(child: Icon(Icons.group, size: 28, color: Colors.black54)),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                                child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(name.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Report date selector (above the chips/table)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Text('تاريخ التقرير', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _reportDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('ar'),
                            );
                            if (picked != null && mounted) setState(() => _reportDate = picked);
                            // Refresh submission status when date changes
                            if (mounted) await _refreshTabSubmissionStatus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(_reportDate.toLocal().toIso8601String().split('T').first, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: (_selectedClassId != null && _students.isNotEmpty && !_savingAttendance && _hasUnsavedChanges && !(_activeReportTab == 'tadabur' ? _tadaburSubmitted : _sardSubmitted))
                              ? () async {
                                  await _saveAttendance();
                                }
                              : null,
                          child: _savingAttendance
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('حفظ'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: (_selectedClassId != null && _students.isNotEmpty) ? () async { await _showAttendanceForClassDate(); } : null,
                          icon: const Icon(Icons.list_alt),
                          label: const Text('عرض السجلات'),
                        ),
                        const SizedBox(width: 8),
                        if (_hasUnsavedChanges) const Text('غير محفوظة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    // types list for selected group and (later) students table
                    Expanded(
                      child: _studentsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // If a group is selected, show distinct Type chips for the group
                                if (_selectedGroupId == null)
                                  const Center(child: Text('اختر مجموعة لعرض الأنواع'))
                                else if (_typeEntries.isEmpty)
                                  Center(child: Text('لا توجد أنواع لهذه المجموعة'))
                                else
                                  SizedBox(
                                    height: 56,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _typeEntries.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (context, idx) {
                                        final t = _typeEntries[idx];
                                        final tidStr = t['id']!;
                                        final label = t['label']!;
                                        final selected = _selectedTypeId != null && _selectedTypeId.toString() == tidStr;
                                        return GestureDetector(
                                          onTap: () async {
                                            setState(() {
                                              _selectedTypeId = int.tryParse(tidStr) ?? tidStr;
                                              _selectedClassId = null;
                                              _students = [];
                                              _classEntries = [];
                                            });
                                            // fetch class entries for the chosen group+type (do not load students yet)
                                            if (_selectedGroupId != null) await _fetchClassEntriesForGroupType(_selectedGroupId!, _selectedTypeId);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: selected ? const Color(0xFF185A9D) : Colors.white,
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: selected ? const Color(0xFF185A9D) : Colors.grey.shade300),
                                            ),
                                            child: Center(child: Text(label.toString(), style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600))),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                // After selecting a type, show class-number chips for that type
                                if (_selectedTypeId != null) ...[
                                  if (_classEntries.isEmpty)
                                    Center(child: Text('لا توجد حلقات لهذه الرواية'))
                                  else
                                    SizedBox(
                                      height: 56,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _classEntries.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                                        itemBuilder: (context, idx) {
                                          final c = _classEntries[idx];
                                          final cidStr = c['id']!;
                                          final label = c['label']!;
                                          final selected = _selectedClassId != null && _selectedClassId.toString() == cidStr;
                                          return GestureDetector(
                                            onTap: () async {
                                              setState(() {
                                                _selectedClassId = int.tryParse(cidStr) ?? cidStr;
                                                _students = [];
                                              });
                                              if (_selectedGroupId != null) await _fetchStudentsForGroupTypeClass(_selectedGroupId!, _selectedTypeId, _selectedClassId);
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: selected ? const Color(0xFF185A9D) : Colors.white,
                                                borderRadius: BorderRadius.circular(18),
                                                border: Border.all(color: selected ? const Color(0xFF185A9D) : Colors.grey.shade300),
                                              ),
                                              child: Center(child: Text(label.toString(), style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600))),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  // Tabs: Tadabur / Sard (appear after class selected)
                                  if (_selectedClassId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          ChoiceChip(
                                            label: const Text('تدبر'),
                                            selected: _activeReportTab == 'tadabur',
                                            onSelected: (v) {
                                              if (v) setState(() => _activeReportTab = 'tadabur');
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          ChoiceChip(
                                            label: const Text('سرد'),
                                            selected: _activeReportTab == 'sard',
                                            onSelected: (v) {
                                              if (v) setState(() => _activeReportTab = 'sard');
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                // show students table only after a class is selected and students fetched
                                if (_selectedClassId != null && _students.isNotEmpty)
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: DataTable(
                                          columns: [
                                            const DataColumn(label: Text('اسم الطالب')),
                                            const DataColumn(label: Text('رقم الطالب')),
                                            const DataColumn(label: Text('الرواية')),
                                            const DataColumn(label: Text('الحلقة')),
                                            const DataColumn(label: Text('حاضرة')),
                                            const DataColumn(label: Text('غائبة')),
                                            const DataColumn(label: Text('معتذرة')),
                                            const DataColumn(label: Text('الإجراءات')),
                                          ],
                                          rows: _students.map((row) {
                                            final student = row['Student_Name'] ?? row['student_name'] ?? row['StudentName'] ?? '';
                                            final studentCode = row['Student_Code'] ?? row['student_code'] ?? row['StudentCode'] ?? '';
                                            final classId = row['Class_id'] ?? row['class_id'] ?? row['ClassId'];
                                            final typeId = row['Type_id'] ?? row['type_id'] ?? row['TypeId'];
                                            final classLabel = (row['Class_Number'] != null && row['Class_Number'].toString().isNotEmpty) ? row['Class_Number'].toString() : _resolveLookup(_classesMap, classId);
                                            final typeLabel = (row['Type'] != null && row['Type'].toString().isNotEmpty) ? row['Type'].toString() : _resolveLookup(_typesMap, typeId);
                                            return DataRow(cells: [
                                              DataCell(Align(alignment: Alignment.centerRight, child: Text(student.toString(), textAlign: TextAlign.right))),
                                              DataCell(Align(alignment: Alignment.centerRight, child: Text(studentCode.toString(), textAlign: TextAlign.right))),
                                              DataCell(Align(alignment: Alignment.centerRight, child: Text(typeLabel, textAlign: TextAlign.right))),
                                              DataCell(Align(alignment: Alignment.centerRight, child: Text(classLabel, textAlign: TextAlign.right))),
                                              // Flags: Attend / Absent / Excuse / Tadabur / Sard
                                              DataCell(Center(child: Checkbox(
                                                value: _readFlag(row, _flagKeysFor('Attend')),
                                                onChanged: (v) async {
                                                  setState(() {
                                                    final val = v ?? false;
                                                    _setFlagForRow(row, 'Attend', val);
                                                    if (val) {
                                                      // enforce single-choice per-tab: uncheck others for this tab
                                                      _setFlagForRow(row, 'Absent', false);
                                                      _setFlagForRow(row, 'Excuse', false);
                                                    }
                                                    _hasUnsavedChanges = true;
                                                  });
                                                },
                                              ))),
                                              DataCell(Center(child: Checkbox(
                                                value: _readFlag(row, _flagKeysFor('Absent')),
                                                onChanged: (v) async {
                                                  setState(() {
                                                    final val = v ?? false;
                                                    _setFlagForRow(row, 'Absent', val);
                                                    if (val) {
                                                      // enforce single-choice per-tab: uncheck others for this tab
                                                      _setFlagForRow(row, 'Attend', false);
                                                      _setFlagForRow(row, 'Excuse', false);
                                                    }
                                                    _hasUnsavedChanges = true;
                                                  });
                                                },
                                              ))),
                                              DataCell(Center(child: Checkbox(
                                                value: _readFlag(row, _flagKeysFor('Excuse')),
                                                onChanged: (v) async {
                                                  setState(() {
                                                    final val = v ?? false;
                                                    _setFlagForRow(row, 'Excuse', val);
                                                    if (val) {
                                                      // enforce single-choice per-tab: uncheck others for this tab
                                                      _setFlagForRow(row, 'Attend', false);
                                                      _setFlagForRow(row, 'Absent', false);
                                                    }
                                                    _hasUnsavedChanges = true;
                                                  });
                                                },
                                              ))),
                                              DataCell(PopupMenuButton<String>(
                                                onSelected: (v) async {
                                                  if (v == 'view') {
                                                    showDialog(context: context, builder: (c) => AlertDialog(
                                                      title: const Text('تفاصيل الطالب'),
                                                      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                        Text('اسم: ${student.toString()}'),
                                                        Text('الرواية: $typeLabel'),
                                                        Text('الحلقة: $classLabel'),
                                                      ]),
                                                      actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('إغلاق'))],
                                                    ));
                                                  } else if (v == 'delete') {
                                                    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                                      title: const Text('حذف'),
                                                      content: const Text('هل تريد حذف هذا السجل؟'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('لا')),
                                                        TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('نعم')),
                                                      ],
                                                    ));
                                                      if (confirm == true) {
                                                      try {
                                                        await _client.from('Students').delete().eq('id', row['id']);
                                                        if (_selectedGroupId != null) {
                                                          if (_selectedClassId != null) {
                                                            await _fetchStudentsForGroupTypeClass(_selectedGroupId!, _selectedTypeId, _selectedClassId);
                                                          } else if (_selectedTypeId != null) {
                                                            await _fetchClassEntriesForGroupType(_selectedGroupId!, _selectedTypeId);
                                                          }
                                                        }
                                                      } catch (e) {
                                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حذف فشل: $e')));
                                                      }
                                                    }
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  const PopupMenuItem(value: 'view', child: Text('عرض')),
                                                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                                ],
                                              )),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _loadLookupTable(String tableName, String nameColumn, Map<dynamic, String> dest) async {
    try {
      final res = await _client.from(tableName).select('id, "$nameColumn"');
      if (res is List) {
        for (final r in List<Map<String, dynamic>>.from(res)) {
          final id = r['id'];
          final name = r[nameColumn] ?? r['title'] ?? r['name'];
          if (id != null && name != null) dest[id] = name.toString();
        }
      }
    } catch (_) {
      // ignore
    }
  }

  // Helper to resolve an id to a friendly name from a lookup map.
  String _resolveLookup(Map<dynamic, String> map, dynamic id) {
    if (id == null) return '';
    // direct hit
    if (map.containsKey(id)) return map[id] ?? id.toString();
    // try numeric conversion
    try {
      final i = int.tryParse(id.toString());
      if (i != null && map.containsKey(i)) return map[i] ?? i.toString();
    } catch (_) {}
    // fallback to string key
    final s = id.toString();
    if (map.containsKey(s)) return map[s] ?? s;
    return id.toString();
  }

  bool _readFlag(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      if (row.containsKey(k)) {
        final v = row[k];
        if (v is bool) return v;
        if (v is int) return v != 0;
        if (v is String) return v.toLowerCase() == 'true' || v == '1';
      }
    }
    return false;
  }

  // Return a list of possible keys for a logical flag name taking the active
  // report tab into account. This allows Tadabur and Sard to keep independent
  // checkbox state in the in-memory `_students` rows.
  List<String> _flagKeysFor(String logical) {
    final pref = _activeReportTab == 'tadabur' ? 'Tadabur' : 'Sard';
    final lower = logical.toLowerCase();
    return [
      '${pref}_${logical}_Flag',
      '${pref}_${lower}_flag',
      '${pref}_$lower',
      '${logical}_Flag',
      '${lower}_flag',
      lower,
    ];
  }

  // Set the tab-scoped keys for a logical flag on a given student row.
  void _setFlagForRow(Map<String, dynamic> row, String logical, bool val) {
    final pref = _activeReportTab == 'tadabur' ? 'Tadabur' : 'Sard';
    final lower = logical.toLowerCase();
    row['${pref}_${logical}_Flag'] = val;
    row['${pref}_${lower}_flag'] = val;
    row['${pref}_$lower'] = val;
  }

  // We no longer write flags immediately when checkboxes are tapped; writes happen on Save.

  Future<void> _fetchStudentsForGroup(int groupId) async {
    // When selecting a group we first load the distinct Types available for that group
    // The UI will display type chips; students table is only loaded after a type is selected.
    setState(() {
      _studentsLoading = true;
      _students = [];
      _typeEntries = [];
      _selectedTypeId = null;
      _selectedGroupId = groupId;
    });
    try {
      await _fetchTypeEntriesForGroup(groupId);
    } catch (e) {
      debugPrint('GroupsScreen: fetch types error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل الأنواع: $e')));
    } finally {
      if (mounted) setState(() => _studentsLoading = false);
    }
  }

  Future<void> _fetchTypeEntriesForGroup(int groupId) async {
    // Fetch distinct type ids and names for a given group so we can show chips immediately
    try {
      var builder = _client.from('Students').select('Type_id, Types(id, "Type")').eq('Group_id', groupId);
      // Apply restrictions if user has them
      if (!widget.userSession.isAdmin) {
        if (_userClassId != null) builder = builder.eq('Class_id', _userClassId!);
        if (_userTypeId != null) builder = builder.eq('Type_id', _userTypeId!);
      }
      final res = await builder.range(0, 1000);
      final seen = <String, String>{};
      if (res is List) {
        for (final r in List<Map<String, dynamic>>.from(res)) {
          final tid = r['Type_id'] ?? r['type_id'];
          String label = '';
          if (r['Types'] is List && (r['Types'] as List).isNotEmpty) {
            final t = (r['Types'] as List).first;
            label = t['Type'] ?? t['type'] ?? '';
          }
          final key = tid?.toString() ?? '';
          if (key.isNotEmpty && !seen.containsKey(key)) {
            seen[key] = label;
          }
        }
      }
      // Fallback: if any label is empty, load Types lookup table
  final needsLookup = seen.values.any((v) => v.isEmpty);
      if (needsLookup) {
        await _loadLookupTable('Types', 'Type', _typesMap);
        final updated = <Map<String, String>>[];
        for (final k in seen.keys) {
          final label = seen[k]!.isNotEmpty ? seen[k]! : (_typesMap.containsKey(int.tryParse(k) ?? k) ? _typesMap[int.tryParse(k) ?? k] ?? _typesMap[k] ?? k : k);
          updated.add({'id': k, 'label': label});
        }
        _typeEntries = updated;
      } else {
        _typeEntries = seen.entries.map((e) => {'id': e.key, 'label': e.value}).toList();
      }
      // sort by label if available
      _typeEntries.sort((a, b) => a['label']!.compareTo(b['label']!));
    } catch (e) {
      debugPrint('fetchTypeEntriesForGroup error: $e');
      _typeEntries = [];
    }
  }

  Future<void> _fetchClassEntriesForGroupType(int groupId, dynamic typeId) async {
    // Fetch distinct class ids and numbers for a given group+type so we can show class chips
    setState(() {
      _studentsLoading = true;
      _classEntries = [];
    });
    try {
      var builder = _client.from('Students').select('Class_id, Classes(id, "Class_Number")').eq('Group_id', groupId).eq('Type_id', typeId);
      // Apply class restriction if user has class_id
      if (!widget.userSession.isAdmin && _userClassId != null) {
        builder = builder.eq('Class_id', _userClassId!);
      }
      final res = await builder.range(0, 1000);
      final seen = <String, String>{};
      if (res is List) {
        for (final r in List<Map<String, dynamic>>.from(res)) {
          final cid = r['Class_id'] ?? r['class_id'];
          String label = '';
          if (r['Classes'] is List && (r['Classes'] as List).isNotEmpty) {
            final c = (r['Classes'] as List).first;
            label = c['Class_Number'] ?? c['class_number'] ?? '';
          }
          final key = cid?.toString() ?? '';
          if (key.isNotEmpty && !seen.containsKey(key)) seen[key] = label;
        }
      }
      // Fallback: if any label is empty, load Classes lookup table
      final needsLookup = seen.values.any((v) => v.isEmpty);
      if (needsLookup) {
        await _loadLookupTable('Classes', 'Class_Number', _classesMap);
        final updated = <Map<String, String>>[];
        for (final k in seen.keys) {
          final label = seen[k]!.isNotEmpty ? seen[k]! : (_classesMap.containsKey(int.tryParse(k) ?? k) ? _classesMap[int.tryParse(k) ?? k] ?? _classesMap[k] ?? k : k);
          updated.add({'id': k, 'label': label});
        }
        _classEntries = updated;
      } else {
        _classEntries = seen.entries.map((e) => {'id': e.key, 'label': e.value}).toList();
      }
      // numeric-aware sort ascending by Class_Number when possible
      int parseNum(String s) {
        final n = int.tryParse(s);
        return n ?? 1 << 30; // non-numeric large value to push to end
      }
      _classEntries.sort((a, b) {
        final la = a['label'] ?? '';
        final lb = b['label'] ?? '';
        final na = parseNum(la);
        final nb = parseNum(lb);
        if (na != (1 << 30) && nb != (1 << 30)) return na.compareTo(nb);
        if (na != (1 << 30) && nb == (1 << 30)) return -1;
        if (na == (1 << 30) && nb != (1 << 30)) return 1;
        return la.compareTo(lb);
      });
    } catch (e) {
      debugPrint('fetchClassEntriesForGroupType error: $e');
      _classEntries = [];
    } finally {
      if (mounted) setState(() => _studentsLoading = false);
    }
  }

  Future<void> _fetchStudentsForGroupTypeClass(int groupId, dynamic typeId, dynamic classId) async {
    setState(() {
      _studentsLoading = true;
      _students = [];
    });
    try {
      var builder = _client.from('Students').select('id, "Student_Name", "Student_Code", "Class_id", "Type_id", Classes(id, "Class_Number"), Types(id, "Type")').eq('Group_id', groupId).eq('Type_id', typeId);
      if (classId != null) builder = builder.eq('Class_id', classId);
      // Apply restrictions if user has them
      if (!widget.userSession.isAdmin) {
        if (_userClassId != null) builder = builder.eq('Class_id', _userClassId!);
        if (_userGroupId != null) builder = builder.eq('Group_id', _userGroupId!);
        if (_userTypeId != null) builder = builder.eq('Type_id', _userTypeId!);
      }
      final res = await builder.order('id', ascending: true).range(0, 1000);
      if (res is List) {
        final rows = List<Map<String, dynamic>>.from(res);
        _students = rows.map((r) {
          final out = <String, dynamic>{};
          out['id'] = r['id'];
          out['Student_Name'] = r['Student_Name'] ?? r['student_name'] ?? r['StudentName'];
          out['Student_Code'] = r['Student_Code'] ?? r['student_code'] ?? r['StudentCode'];
          out['Class_id'] = r['Class_id'] ?? r['class_id'];
          out['Type_id'] = r['Type_id'] ?? r['type_id'];
          if (r['Classes'] is List && (r['Classes'] as List).isNotEmpty) {
            final c = (r['Classes'] as List).first;
            out['Class_Number'] = c['Class_Number'] ?? c['class_number'];
          }
          if (r['Types'] is List && (r['Types'] as List).isNotEmpty) {
            final t = (r['Types'] as List).first;
            out['Type'] = t['Type'] ?? t['type'];
          }
          return out;
        }).toList();
        if (_classesMap.isEmpty && _students.any((r) => r['Class_Number'] == null)) {
          await _loadLookupTable('Classes', 'Class_Number', _classesMap);
        }
        if (_typesMap.isEmpty && _students.any((r) => r['Type'] == null)) {
          await _loadLookupTable('Types', 'Type', _typesMap);
        }
      } else {
        _students = [];
      }
    } catch (e) {
      _students = [];
      debugPrint('GroupsScreen: fetch students by type+class error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading students for selection: $e')));
    } finally {
      if (mounted) setState(() => _studentsLoading = false);
      // Refresh whether tadabur/sard were already submitted for this class+date
      if (mounted) await _refreshTabSubmissionStatus();
    }
  }

  // Checks the per-tab Attendance tables for the current class and date and sets
  // `_tadaburSubmitted` / `_sardSubmitted` to disable saving the same tab twice.
  Future<void> _refreshTabSubmissionStatus() async {
    _tadaburSubmitted = false;
    _sardSubmitted = false;
    if (_selectedClassId == null || _students.isEmpty) return;
    try {
      final dt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day);
      final dateStr = dt.toIso8601String();
      final studentIds = _students.map((s) => s['id']).whereType<int>().toList();
      if (studentIds.isEmpty) return;

      // Check if any student has a row in Attendance_Tadabur for this date
      for (final id in studentIds) {
        try {
          final tadRow = await _client.from('Attendance_Tadabur').select('id').eq('Student_id', id).eq('Report_date', dateStr).limit(1).maybeSingle();
          if (tadRow != null) {
            _tadaburSubmitted = true;
            break;
          }
        } catch (e) {
          _logDebug('warning: checking Tadabur for $id failed: $e');
        }
      }

      // Check if any student has a row in Attendance_Sard for this date
      for (final id in studentIds) {
        try {
          final sardRow = await _client.from('Attendance_Sard').select('id').eq('Student_id', id).eq('Report_date', dateStr).limit(1).maybeSingle();
          if (sardRow != null) {
            _sardSubmitted = true;
            break;
          }
        } catch (e) {
          _logDebug('warning: checking Sard for $id failed: $e');
        }
      }
    } catch (e) {
      _logDebug('refreshTabSubmissionStatus error: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

    void _logDebug(String msg) {
      // keep console output and an in-app buffer for inspection
      debugPrint(msg);
      final line = '${DateTime.now().toIso8601String()} - $msg';
      if (mounted) {
        setState(() {
        _debugLogs.insert(0, line);
        if (_debugLogs.length > 500) _debugLogs.removeRange(500, _debugLogs.length);
      });
      }
    }

    // Get the attendance table name based on the active report tab.
    String _getAttendanceTable() {
      return _activeReportTab == 'tadabur' ? 'Attendance_Tadabur' : 'Attendance_Sard';
    }

  Future<void> _saveAttendance() async {
    if (_selectedClassId == null || _students.isEmpty) return;
    
    // Validate restrictions: verify user is authorized for selected group/type/class
    if (!widget.userSession.isAdmin) {
      if (_userGroupId != null && _selectedGroupId != _userGroupId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('غير مصرح لك بحفظ الحضور لهذه المجموعة')),
          );
        }
        return;
      }
      if (_userTypeId != null && _selectedTypeId?.toString() != _userTypeId.toString()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('غير مصرح لك بحفظ الحضور لهذه الرواية')),
          );
        }
        return;
      }
      if (_userClassId != null) {
        final selectedClassIdInt = int.tryParse(_selectedClassId?.toString() ?? '');
        if (selectedClassIdInt != _userClassId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('غير مصرح لك بحفظ الحضور لهذه الحلقة')),
            );
          }
          return;
        }
      }
    }
    
    setState(() => _savingAttendance = true);
    try {
      final dt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day);
      final dateStr = dt.toIso8601String();
      final tableName = _getAttendanceTable();

      int inserted = 0;
      int updated = 0;
      int verified = 0;
      final List<String> failures = [];

      for (final s in _students) {
        final id = s['id'];
        final attend = _readFlag(s, _flagKeysFor('Attend'));
        final absent = _readFlag(s, _flagKeysFor('Absent'));
        final excuse = _readFlag(s, _flagKeysFor('Excuse'));

        try {
          // Check if a row exists for this student+date in the active tab's table
          final existingRow = await _client.from(tableName).select('id').eq('Student_id', id).eq('Report_date', dateStr).limit(1).maybeSingle();

          final payload = <String, dynamic>{
            'Student_id': id,
            'Attend_flag': attend,
            'Absent_flag': absent,
            'Execuse_flag': excuse,
            'Report_date': dateStr,
          };

          if (existingRow != null) {
            // Update existing row
            await _client.from(tableName).update(payload).eq('id', existingRow['id']);
            updated += 1;
            _logDebug('$tableName updated for student $id');
          } else {
            // Insert new row
            await _client.from(tableName).insert(payload);
            inserted += 1;
            _logDebug('$tableName inserted for student $id');
          }

          // Verify
          final verifyRow = await _client.from(tableName).select('id').eq('Student_id', id).eq('Report_date', dateStr).limit(1).maybeSingle();
          if (verifyRow != null) {
            verified += 1;
          } else {
            failures.add('verify: no row for $id in $tableName');
          }
        } catch (e) {
          failures.add('$id: $e');
          _logDebug('Failed to save attendance for $id in $tableName: $e');
        }
      }

      if (mounted) setState(() => _hasUnsavedChanges = false);
      if (mounted) await _refreshTabSubmissionStatus();

      final msg = 'حفظ: $inserted مدرج، $updated محدث، $verified تم التحقق';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (failures.isNotEmpty) {
        _logDebug('Attendance failures: ${failures.join('; ')}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('بعض السجلات فشلت: ${failures.length}')));
      }
    } catch (e) {
      _logDebug('Save attendance error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ حفظ الحضور: $e')));
    } finally {
      if (mounted) setState(() => _savingAttendance = false);
    }
  }

  Future<void> _showAttendanceForClassDate() async {
    if (_selectedClassId == null || _students.isEmpty) return;
    final dt = DateTime(_reportDate.year, _reportDate.month, _reportDate.day);
    final dateStr = dt.toIso8601String();
    final results = <Map<String, dynamic>>[];

    for (final s in _students) {
      final id = s['id'];
      // Fetch from Attendance_Tadabur
      try {
        final tadRows = await _client.from('Attendance_Tadabur').select('*').eq('Student_id', id).eq('Report_date', dateStr).range(0, 1000);
        if (tadRows is List) {
          for (final r in List<Map<String, dynamic>>.from(tadRows)) {
            r['_table'] = 'Tadabur';
            results.add(Map<String, dynamic>.from(r));
          }
        }
      } catch (e) {
        _logDebug('error fetching Tadabur for $id: $e');
      }

      // Fetch from Attendance_Sard
      try {
        final sardRows = await _client.from('Attendance_Sard').select('*').eq('Student_id', id).eq('Report_date', dateStr).range(0, 1000);
        if (sardRows is List) {
          for (final r in List<Map<String, dynamic>>.from(sardRows)) {
            r['_table'] = 'Sard';
            results.add(Map<String, dynamic>.from(r));
          }
        }
      } catch (e) {
        _logDebug('error fetching Sard for $id: $e');
      }
    }

    // Show dialog with found rows
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (c) {
      return AlertDialog(
        title: const Text('سجلات الحضور لهذه الحلقة/التاريخ'),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? const Text('لا توجد سجلات')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: results.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(r.toString()),
                    )).toList(),
                  ),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('إغلاق'))],
      );
    });
  }


  // old grid-based build removed; new build renders top cards and per-group student list
}

// StudentsScreen is now provided by lib/screens/students_screen.dart



