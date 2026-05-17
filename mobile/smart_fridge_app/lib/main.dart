import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/alerts_screen.dart';
import 'screens/camera_view_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/settings_screen.dart';
import 'services/firebase_service.dart';
import 'utils/status_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialise Firebase. With the committed placeholder config this
  // succeeds structurally; data calls only work once the user runs
  // `flutterfire configure`. If init throws, the app still opens.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseService.ready =
        DefaultFirebaseOptions.currentPlatform.projectId != 'your-project-id';
  } catch (e) {
    FirebaseService.ready = false;
    debugPrint('Firebase init failed: $e');
  }

  runApp(const SmartFridgeApp());
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero Waste Smart Fridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: StatusColors.fresh,
          primary: StatusColors.fresh,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F5),
        cardTheme: const CardThemeData(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.symmetric(vertical: 6),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: StatusColors.fresh,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

/// Bottom-navigation shell holding the five primary screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _screens = <Widget>[
    DashboardScreen(),
    ProductListScreen(),
    CameraViewScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (FirebaseService.demoMode) const _DemoBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Products'),
          NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam),
              label: 'Camera'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alerts'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}

/// Thin strip shown when the app runs on built-in demo data.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFFFFF3CD),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: <Widget>[
              Icon(Icons.info_outline, size: 16, color: Color(0xFF8A6D00)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo mode - sample data. Run "flutterfire configure" '
                  'to connect your own Firebase project.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A6D00)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
