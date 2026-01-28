import 'package:faculty_pedia/features/home/presentation/notifications_screen.dart';
import 'package:faculty_pedia/features/messages/presentation/messages_home_screen.dart';
import 'package:faculty_pedia/features/messages/presentation/new_chat_screen.dart';
import 'package:faculty_pedia/features/messages/presentation/student_chat_screen.dart';
import 'package:faculty_pedia/features/profile/presentation/following_educators_screen.dart';
import 'package:faculty_pedia/features/profile/presentation/my_test_results_screen.dart';
import 'package:faculty_pedia/features/profile/presentation/test_result_details_screen.dart';
import 'package:faculty_pedia/features/settings/presentation/change_passord_screen.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/educators/presentation/educators_screen.dart';
import '../../features/educators/presentation/educator_profile_screen.dart';
import '../../features/courses/presentation/courses_screen.dart';
import '../../features/exams/presentation/exams_screen.dart';
import '../../features/exams/presentation/exam_details_screen.dart';
import '../../features/test_series/presentation/test_series_screen.dart';
import '../../features/test_series/presentation/test_series_details_screen.dart';
import '../../features/live_test/presentation/live_test_screen.dart';
import '../../features/live_test/presentation/test_result_screen.dart';
import '../../features/webinars/presentation/webinars_screen.dart';
import '../../features/webinars/presentation/webinar_details_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/courses/presentation/enhanced_course_details_screen.dart';
import '../../features/courses/presentation/my_courses_screen.dart';
import '../../features/courses/presentation/course_content_screen.dart';
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/splash';
      // Don't redirect from splash - let it handle navigation
      if (isSplash) return null;

      // If not logged in and not on auth pages, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // If logged in and on auth pages, redirect to home
      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // Main Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/exams',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExamsScreen(),
            ),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagesHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      
      // Educator Profile
      GoRoute(
        path: '/educator/:id',
        builder: (context, state) => EducatorProfileScreen(
          educatorId: state.pathParameters['id']!,
        ),
      ),
      // Courses
      GoRoute(
        path: '/courses',
        builder: (context, state) => const CoursesScreen(),
      ),
      GoRoute(
        path: '/following-educators',
        builder: (context, state) => const FollowingEducatorsScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/chat/new',
        builder: (context, state) => const NewChatScreen(),
      ),

      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final extra = (state.extra is Map) ? (state.extra as Map) : {};

          final receiverId = (extra['receiverId'] ?? '').toString();
          final receiverType = (extra['receiverType'] ?? '').toString();

          if (receiverId.isEmpty || receiverType.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text("Invalid chat open: receiver not found"),
              ),
            );
          }

          return StudentChatScreen(
            conversationId: state.pathParameters['id']!,
            title: extra['title'] as String?,
            receiverId: receiverId,
            receiverType: receiverType,
          );
        },
      ),

      GoRoute(
        path: '/course/:id',
        builder: (context, state) => EnhancedCourseDetailsScreen(
          courseId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my-courses',
        builder: (context, state) => const MyCoursesScreen(),
      ),
      GoRoute(
        path: '/course-content/:id',
        builder: (context, state) => CourseContentScreen(
          courseId: state.pathParameters['id']!,
        ),
      ),
      
      // Exams Detail
      GoRoute(
        path: '/exam/:type',
        builder: (context, state) => ExamDetailsScreen(
          examType: state.pathParameters['type']!,
        ),
      ),
      
      // Test Series
      GoRoute(
        path: '/test-series',
        builder: (context, state) => const TestSeriesScreen(),
      ),
      GoRoute(
        path: '/test-series/:id',
        builder: (context, state) => TestSeriesDetailsScreen(
          testSeriesId: state.pathParameters['id']!,
        ),
      ),
      
      // Live Test
      GoRoute(
        path: '/live-test/:id',
        builder: (context, state) => LiveTestScreen(
          testId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my-test-results',
        builder: (context, state) => const MyTestResultsScreen(),
      ),
      GoRoute(
        path: '/my-test-results/details',
        builder: (context, state) {
          final r = state.extra as TestResult;
          return TestResultDetailsScreen(result: r);
        },
      ),
      GoRoute(
        path: '/test-result/:id',
        builder: (context, state) => TestResultScreen(
          resultId: state.pathParameters['id']!,
        ),
      ),
      
      // Webinars
      GoRoute(
        path: '/webinars',
        builder: (context, state) => const WebinarsScreen(),
      ),
      GoRoute(
        path: '/webinar/:id',
        builder: (context, state) => WebinarDetailsScreen(
          webinarId: state.pathParameters['id']!,
        ),
      ),
      
      // Profile
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: '/educators',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: EducatorsScreen(),
        ),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.matchedLocation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
