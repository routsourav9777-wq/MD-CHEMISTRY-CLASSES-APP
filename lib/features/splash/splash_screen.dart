import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/chemistry_background.dart';
import '../../core/theme.dart';
import '../admin/admin_dashboard.dart';
import '../student/student_dashboard.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController c;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _opening = false;

  @override
  void initState() {
    super.initState();

    c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _checkUser();
  }

  // ============================================================
  // CHECK USER
  // ============================================================

  Future<void> _checkUser() async {
    await Future.delayed(
      const Duration(milliseconds: 2600),
    );

    if (!mounted) return;

    try {
      // --------------------------------------------------------
      // FIREBASE CURRENT USER
      // --------------------------------------------------------

      final User? user = _auth.currentUser;

      debugPrint(
        '====================================',
      );

      debugPrint(
        'SPLASH USER CHECK',
      );

      debugPrint(
        'UID: ${user?.uid}',
      );

      debugPrint(
        'EMAIL: ${user?.email}',
      );

      debugPrint(
        '====================================',
      );

      // --------------------------------------------------------
      // NO USER
      // --------------------------------------------------------

      if (user == null) {
        _openLogin();
        return;
      }

      // --------------------------------------------------------
      // REFRESH USER
      // --------------------------------------------------------

      try {
        await user.reload();
      } catch (e) {
        debugPrint(
          'User reload error: $e',
        );
      }

      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        _openLogin();
        return;
      }

      // --------------------------------------------------------
      // GET FIRESTORE PROFILE
      // --------------------------------------------------------

      DocumentSnapshot<Map<String, dynamic>>? doc;

      try {
        doc = await _db.collection('users').doc(currentUser.uid).get();
      } catch (e) {
        debugPrint(
          'Firestore profile error: $e',
        );

        // IMPORTANT:
        // Do NOT logout the Firebase user.
        //
        // If profile cannot be loaded temporarily,
        // keep the session alive and show login only
        // if we absolutely cannot determine the role.
      }

      // --------------------------------------------------------
      // PROFILE NOT AVAILABLE
      // --------------------------------------------------------

      if (doc == null || !doc.exists || doc.data() == null) {
        debugPrint(
          'Profile not found for UID: '
          '${currentUser.uid}',
        );

        _openLogin();
        return;
      }

      final data = doc.data()!;

      // --------------------------------------------------------
      // ROLE
      // --------------------------------------------------------

      final String role = data['role']?.toString().trim().toLowerCase() ?? '';

      // --------------------------------------------------------
      // STATUS
      // --------------------------------------------------------

      final String status =
          data['status']?.toString().trim().toLowerCase() ?? '';

      debugPrint(
        'Role: $role',
      );

      debugPrint(
        'Status: $status',
      );

      // --------------------------------------------------------
      // ADMIN
      // --------------------------------------------------------

      if (role == 'admin') {
        _openAdmin();
        return;
      }

      // --------------------------------------------------------
      // STUDENT
      // --------------------------------------------------------

      if (role == 'student') {
        // Approved student
        if (status == 'approved') {
          _openStudent();
          return;
        }

        // Some old accounts may not have status.
        // If Firebase session exists but status is missing,
        // don't sign the user out automatically.
        if (status.isEmpty) {
          debugPrint(
            'Student status missing.',
          );

          _openStudent();
          return;
        }

        // Pending/rejected/blocked
        _openLogin();
        return;
      }

      // --------------------------------------------------------
      // UNKNOWN ROLE
      // --------------------------------------------------------

      debugPrint(
        'Unknown role: $role',
      );

      _openLogin();
    } catch (e, stackTrace) {
      debugPrint(
        '====================================',
      );

      debugPrint(
        'SPLASH ERROR',
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        stackTrace.toString(),
      );

      debugPrint(
        '====================================',
      );

      if (!mounted) return;

      _openLogin();
    }
  }

  // ============================================================
  // OPEN ADMIN
  // ============================================================

  void _openAdmin() {
    if (!mounted || _opening) {
      return;
    }

    _opening = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const AdminDashboard();
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(
          milliseconds: 500,
        ),
      ),
    );
  }

  // ============================================================
  // OPEN STUDENT
  // ============================================================

  void _openStudent() {
    if (!mounted || _opening) {
      return;
    }

    _opening = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const StudentDashboard();
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(
          milliseconds: 500,
        ),
      ),
    );
  }

  // ============================================================
  // OPEN LOGIN
  // ============================================================

  void _openLogin() {
    if (!mounted || _opening) {
      return;
    }

    _opening = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const LoginScreen();
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(
          milliseconds: 600,
        ),
      ),
    );
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: ChemistryBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: c,
            builder: (
              context,
              child,
            ) {
              final double scale = .75 + c.value * .25;

              return Opacity(
                opacity: c.value,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: c.value * 2 * pi,
                        child: Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.cyan.withOpacity(
                                .5,
                              ),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.cyan.withOpacity(
                                  .18,
                                ),
                                blurRadius: 35,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.science_rounded,
                            size: 52,
                            color: AppTheme.cyan,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      const Text(
                        'CHEMISTRY',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        'Learn Chemistry. '
                        'Understand the Science.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(
                            .55,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
