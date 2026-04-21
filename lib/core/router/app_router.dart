import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_app/features/auth/presentation/screens/login_screen.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/features/drivers/presentation/screens/driver_home_screen.dart';
import 'package:taxi_app/features/drivers/presentation/screens/driver_history_screen.dart';
import 'package:taxi_app/features/rides/presentation/screens/admin_dashboard_screen.dart';
import 'package:taxi_app/features/rides/presentation/screens/new_ride_screen.dart';
import 'package:taxi_app/features/rides/presentation/screens/assign_driver_screen.dart';
import 'package:taxi_app/features/history/presentation/history_screen.dart';
import 'package:taxi_app/features/drivers/presentation/screens/driver_profile_screen.dart';
import 'package:taxi_app/features/drivers/presentation/screens/admin_drivers_screen.dart';
import 'package:taxi_app/features/settings/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isLoggingIn = state.matchedLocation == '/login';

      if (user == null) return isLoggingIn ? null : '/login';
      if (isLoggingIn) {
        return user.isAdmin ? '/admin' : '/driver';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'new-ride',
            builder: (context, state) => const NewRideScreen(),
          ),
          GoRoute(
            path: 'assign/:rideId',
            builder: (context, state) =>
                AssignDriverScreen(rideId: state.pathParameters['rideId']!),
          ),
          GoRoute(
            path: 'history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: 'drivers',
            builder: (context, state) => const AdminDriversScreen(),
          ),
          GoRoute(
            path: 'driver-history/:driverId',
            builder: (context, state) => DriverHistoryScreen(
              driverId: state.pathParameters['driverId']!,
              driverName: state.extra as String? ?? 'Conductor',
            ),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverHomeScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const DriverProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Página no encontrada: ${state.error}')),
    ),
  );
});
