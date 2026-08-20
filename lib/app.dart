import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/screens/dashboard_screen.dart';
import 'package:dhealth/screens/daily_log_screen.dart';
import 'package:dhealth/screens/predictions_screen.dart';
import 'package:dhealth/screens/recommendations_screen.dart';
import 'package:dhealth/screens/login_screen.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/services/firestore_daily_log_service.dart';

// TODO: rename to DHealth equivalent in V2 refactor
class DermCareApp extends StatefulWidget {
  const DermCareApp({super.key});

  @override
  State<DermCareApp> createState() => _DermCareAppState();
}

// TODO: rename to DHealth equivalent in V2 refactor
class _DermCareAppState extends State<DermCareApp> {
  int currentIndex = 0;
  String selectedCondition = 'psoriasis';

  final List<String> views = ['dashboard', 'daily-log', 'predictions', 'recommendations'];

  // Simple demo services for the bottom-nav shell
  final DailyLogService _dailyLogService = DailyLogService();
  final FirestoreDailyLogService _firestoreDailyLogService =
      FirestoreDailyLogService(userId: 'demo-user');

  void navigateToView(int index) {
    setState(() => currentIndex = index);
  }

  void handleConditionChanged(String condition) {
    setState(() => selectedCondition = condition);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DHealth',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('DHealth'),
        ),
        body: buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: navigateToView,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard, key: const ValueKey('dashboardButton')),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit, key: const ValueKey('dailyLogButton')),
              label: 'Daily Log',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up, key: const ValueKey('predictionsButton')),
              label: 'Predictions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb, key: const ValueKey('recommendationsButton')),
              label: 'Recommendations',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBody() {
    switch (currentIndex) {
      case 0:
        return DashboardScreen(
          selectedCondition: selectedCondition,
          onNavigateToDailyLog: () => navigateToView(1),
          onNavigateToPredictions: () => navigateToView(2),
          onNavigateToRecommendations: () => navigateToView(3),
          onConditionChanged: handleConditionChanged,
        );
      case 1:
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return const LoginScreen();
        }
        return DailyLogScreen(
          dailyLogService: _dailyLogService,
          firestoreService: _firestoreDailyLogService,
          condition: selectedCondition,
        );
      case 2:
        return PredictionsScreen(
          selectedCondition: selectedCondition,
          onBack: () => navigateToView(0),
        );
      case 3:
        return RecommendationsScreen(
          selectedCondition: selectedCondition,
          onBack: () => navigateToView(0),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
