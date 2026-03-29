import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'login_screen.dart';
import 'employee_home.dart';
import 'admin_dashboard.dart';
import 'register_screen.dart';
import 'location_form_screen.dart';
import 'location_list_screen.dart';
import 'schedule_form_screen.dart';
import 'schedule_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kabbeyypgbvtkjlrrtem.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImthYmJleXlwZ2J2dGtqbHJydGVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MTY1MjQsImV4cCI6MjA5MDE5MjUyNH0.SEDDdJfFTF8oS3_B0yiP_qaCRTFpkki3cDzKUGqRbvE',
  );
  runApp(MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/employee', builder: (context, state) => EmployeeHome()),
    GoRoute(path: '/admin', builder: (context, state) => AdminDashboard()),
    GoRoute(path: '/register',builder: (context, state) => RegisterScreen()),
    GoRoute(path: '/add-location',builder: (context, state) {final initialLoc = state.extra as Map<String, dynamic>?;
    return LocationFormScreen(initialLocation: initialLoc);}),
    GoRoute(path: '/locations',builder: (context, state) => LocationListScreen()),
    GoRoute(path: '/schedules',builder: (context, state) => ScheduleListScreen()),
    GoRoute(path: '/add-schedule',builder: (context, state) {final initialSched = state.extra as Map<String, dynamic>?;
    return ScheduleFormScreen(initialSchedule: initialSched);},),  
  ],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'PunchClock',
    );
  }
}