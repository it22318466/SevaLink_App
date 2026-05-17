import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../features/auth/screens/role_selection_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/reset_success_screen.dart';
import '../features/auth/screens/email_verification_sent_screen.dart';
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isLoggedIn = authState.user != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/role-selection';
      }
      if (isLoggedIn && isAuthRoute) {
        return authState.user?.role == 'CLIENT' ? '/client/home' : '/worker/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/auth/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'CLIENT';
          return SignupScreen(role: role);
        },
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return ResetPasswordScreen(email: email);
        },
      ),
      GoRoute(
        path: '/auth/reset-success',
        builder: (context, state) => const ResetSuccessScreen(),
      ),
      GoRoute(
        path: '/auth/email-verification',
        builder: (context, state) => const EmailVerificationSentScreen(),
      ),
      GoRoute(
        path: '/client/home',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('Client Home'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              )
            ],
          ),
          body: const Center(child: Text("Welcome Client!")),
        ),
      ),
      GoRoute(
        path: '/worker/home',
        builder: (context, state) => Scaffold(
           appBar: AppBar(
            title: const Text('Worker Home'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              )
            ],
          ),
          body: const Center(child: Text("Welcome Worker!")),
        ),
      ),
    ],
  );
});
