import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/chemistry_background.dart';
import '../../core/glass_card.dart';
import '../../core/theme.dart';
import '../admin/admin_dashboard.dart';
import '../student/student_dashboard.dart';
import 'auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController email = TextEditingController();

  final TextEditingController password = TextEditingController();

  final AuthService service = AuthService();

  // ============================================================
  // ANIMATIONS
  // ============================================================

  late final AnimationController intro;
  late final AnimationController atom;

  // ============================================================
  // LOGIN
  // ============================================================

  bool admin = false;
  bool obscure = true;
  bool loading = false;

  // ============================================================
  // FORGOT PASSWORD SECURITY
  // ============================================================

  bool resetLoading = false;

  int resetAttempts = 0;

  DateTime? lastResetRequest;

  DateTime? resetLimitUntil;

  Timer? resetTimer;

  int resetSecondsLeft = 0;

  static const int maxResetAttempts = 3;

  static const Duration resetCooldown = Duration(seconds: 60);

  static const Duration resetWindow = Duration(minutes: 10);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    atom = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    intro.dispose();
    atom.dispose();

    email.dispose();
    password.dispose();

    resetTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> login() async {
    if (loading) return;

    final String emailText = email.text.trim();

    final String passwordText = password.text;

    if (emailText.isEmpty || passwordText.isEmpty) {
      _showMessage(
        'Please enter email and password.',
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await service.login(
        emailText,
        passwordText,
      );

      final Map<String, dynamic>? profile = await service.profile();

      if (!mounted) return;

      if (profile == null) {
        throw Exception(
          'User profile not found.',
        );
      }

      final String role =
          profile['role']?.toString().trim().toLowerCase() ?? '';

      final String status =
          profile['status']?.toString().trim().toLowerCase() ?? '';

      // ========================================================
      // ADMIN
      // ========================================================

      if (admin) {
        if (role != 'admin') {
          throw Exception(
            'This account is not registered as an Admin account.',
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboard(),
          ),
        );

        return;
      }

      // ========================================================
      // STUDENT
      // ========================================================

      if (role != 'student') {
        throw Exception(
          'This account is not registered as a Student account.',
        );
      }

      if (status != 'approved') {
        if (status == 'pending') {
          throw Exception(
            'Your account is waiting for Admin approval.',
          );
        }

        if (status == 'rejected') {
          throw Exception(
            'Your registration was rejected by Admin.',
          );
        }

        if (status == 'blocked') {
          throw Exception(
            'Your account has been blocked by Admin.',
          );
        }

        throw Exception(
          'Your student account is not active.',
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentDashboard(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Incorrect email or password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Internet connection problem.';
          break;

        default:
          message = e.message ?? 'Login failed.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _forgotPassword() async {
    if (!mounted || resetLoading) return;

    // Check cooldown BEFORE opening the dialog.
    if (_isResetBlocked()) {
      _showResetLimitMessage();
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: email.text.trim(),
    );

    try {
      final bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Reset Password',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your registered email',
                prefixIcon: Icon(
                  Icons.email_outlined,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      if (result != true) {
        return;
      }

      final String resetEmail = controller.text.trim();

      if (resetEmail.isEmpty) {
        _showMessage(
          'Please enter your email address.',
        );
        return;
      }

      final bool validEmail = RegExp(
        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
      ).hasMatch(resetEmail);

      if (!validEmail) {
        _showMessage(
          'Please enter a valid email address.',
        );
        return;
      }

      // Check again after the dialog closes.
      if (_isResetBlocked()) {
        _showResetLimitMessage();
        return;
      }

      if (!mounted) return;

      setState(() {
        resetLoading = true;
      });

      try {
        // Firebase password reset.
        await service.resetPassword(
          resetEmail,
        );

        // Count only a request that reached
        // Firebase successfully.
        _recordResetRequest();

        if (!mounted) return;

        _showMessage(
          'If an account exists for this email, '
          'a password reset email has been sent.',
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        if (e.code == 'too-many-requests') {
          _activateLongResetLimit();

          _showMessage(
            'Too many reset requests. '
            'Please wait before trying again.',
          );
        } else if (e.code == 'network-request-failed') {
          _showMessage(
            'Internet connection problem. '
            'Please try again later.',
          );
        } else if (e.code == 'invalid-email') {
          _showMessage(
            'Please enter a valid email address.',
          );
        } else if (e.code == 'user-not-found') {
          // Do not reveal whether an account exists.
          _recordResetRequest();

          _showMessage(
            'If an account exists for this email, '
            'a password reset email has been sent.',
          );
        } else {
          _showMessage(
            'Unable to send the reset email. '
            'Please try again later.',
          );
        }
      } catch (e) {
        if (!mounted) return;

        _showMessage(
          'Unable to process the reset request. '
          'Please try again later.',
        );

        debugPrint(
          'Password reset error: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            resetLoading = false;
          });
        }
      }
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // CHECK RESET LIMIT
  // ============================================================

  bool _isResetBlocked() {
    final DateTime now = DateTime.now();

    // Long block.
    if (resetLimitUntil != null) {
      if (now.isBefore(resetLimitUntil!)) {
        return true;
      }

      // Block expired.
      resetLimitUntil = null;
      resetAttempts = 0;
    }

    // Reset the attempt window after 10 minutes.
    if (lastResetRequest != null) {
      final Duration difference = now.difference(lastResetRequest!);

      if (difference >= resetWindow) {
        resetAttempts = 0;
        lastResetRequest = null;
      }
    }

    if (resetAttempts >= maxResetAttempts) {
      return true;
    }

    // 60 second cooldown.
    if (lastResetRequest != null) {
      final DateTime nextAllowed = lastResetRequest!.add(
        resetCooldown,
      );

      if (now.isBefore(nextAllowed)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // RECORD RESET REQUEST
  // ============================================================

  void _recordResetRequest() {
    lastResetRequest = DateTime.now();

    resetAttempts++;

    _startResetTimer();
  }

  // ============================================================
  // LONG RESET LIMIT
  // ============================================================

  void _activateLongResetLimit() {
    resetLimitUntil = DateTime.now().add(
      resetWindow,
    );

    resetAttempts = maxResetAttempts;

    _startResetTimer();
  }

  // ============================================================
  // COUNTDOWN
  // ============================================================

  void _startResetTimer() {
    resetTimer?.cancel();

    _updateResetSeconds();

    resetTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          resetTimer?.cancel();
          return;
        }

        _updateResetSeconds();

        final DateTime now = DateTime.now();

        final bool longBlockActive = resetLimitUntil != null &&
            now.isBefore(
              resetLimitUntil!,
            );

        final bool cooldownActive = lastResetRequest != null &&
            now.isBefore(
              lastResetRequest!.add(
                resetCooldown,
              ),
            );

        if (!longBlockActive && !cooldownActive) {
          resetTimer?.cancel();

          if (mounted) {
            setState(() {});
          }
        }
      },
    );
  }

  // ============================================================
  // UPDATE TIMER
  // ============================================================

  void _updateResetSeconds() {
    final DateTime now = DateTime.now();

    int seconds = 0;

    if (lastResetRequest != null) {
      final DateTime nextAllowed = lastResetRequest!.add(
        resetCooldown,
      );

      final int cooldownSeconds = nextAllowed.difference(now).inSeconds;

      if (cooldownSeconds > seconds) {
        seconds = cooldownSeconds;
      }
    }

    if (resetLimitUntil != null &&
        now.isBefore(
          resetLimitUntil!,
        )) {
      final int limitSeconds = resetLimitUntil!.difference(now).inSeconds;

      if (limitSeconds > seconds) {
        seconds = limitSeconds;
      }
    }

    resetSecondsLeft = seconds > 0 ? seconds : 0;

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // RESET LIMIT MESSAGE
  // ============================================================

  void _showResetLimitMessage() {
    if (resetLimitUntil != null &&
        DateTime.now().isBefore(
          resetLimitUntil!,
        )) {
      _showMessage(
        'Too many reset requests. '
        'Please wait ${resetSecondsLeft}s.',
      );
      return;
    }

    if (resetSecondsLeft > 0) {
      _showMessage(
        'Please wait ${resetSecondsLeft}s '
        'before requesting another reset email.',
      );
      return;
    }

    _showMessage(
      'Please wait before requesting another reset email.',
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final Animation<double> fadeAnimation = CurvedAnimation(
      parent: intro,
      curve: Curves.easeOutCubic,
    );

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: intro,
        curve: Curves.easeOutCubic,
      ),
    );

    final bool resetBlocked = resetLoading ||
        resetSecondsLeft > 0 ||
        (resetLimitUntil != null &&
            DateTime.now().isBefore(resetLimitUntil!)) ||
        resetAttempts >= maxResetAttempts;

    return Scaffold(
      body: ChemistryBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              30,
            ),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // LOGO
                // ==================================================

                AnimatedBuilder(
                  animation: atom,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: atom.value * 6.28318530718,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.cyan,
                          AppTheme.blue,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyan.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 38,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.science_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // TITLE
                // ==================================================

                const Text(
                  'MD CHEMISTRY CLASSES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'Your learning lab, in your pocket.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.55,
                    ),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                // ==================================================
                // LOGIN CARD
                // ==================================================

                FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _roleSelector(),

                          const SizedBox(
                            height: 24,
                          ),

                          Text(
                            admin ? 'Admin Login' : 'Student Login',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            admin
                                ? 'Sign in to manage your MD CLASSES.'
                                : 'Sign in to continue your MD CLASSES learning.',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // ==================================================
                          // EMAIL
                          // ==================================================

                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          // ==================================================
                          // PASSWORD
                          // ==================================================

                          TextField(
                            controller: password,
                            obscureText: obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!loading) {
                                login();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip:
                                    obscure ? 'Show password' : 'Hide password',
                                onPressed: () {
                                  setState(
                                    () {
                                      obscure = !obscure;
                                    },
                                  );
                                },
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),

                          // ==================================================
                          // FORGOT PASSWORD
                          // ==================================================

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: resetBlocked ? null : _forgotPassword,
                              child: resetLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      resetSecondsLeft > 0
                                          ? 'Try again in ${resetSecondsLeft}s'
                                          : 'Forgot Password?',
                                    ),
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          // ==================================================
                          // LOGIN BUTTON
                          // ==================================================

                          SizedBox(
                            height: 55,
                            child: FilledButton(
                              onPressed: loading ? null : login,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.cyan,
                                foregroundColor: AppTheme.bg,
                                disabledBackgroundColor:
                                    AppTheme.cyan.withValues(
                                  alpha: 0.45,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    17,
                                  ),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(
                                  milliseconds: 250,
                                ),
                                child: loading
                                    ? const SizedBox(
                                        key: ValueKey(
                                          'loading',
                                        ),
                                        width: 23,
                                        height: 23,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.3,
                                          color: AppTheme.bg,
                                        ),
                                      )
                                    : const Text(
                                        'LOGIN',
                                        key: ValueKey(
                                          'login',
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // ==================================================
                          // REGISTRATION
                          // ==================================================

                          if (!admin) ...[
                            const SizedBox(
                              height: 13,
                            ),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                              child: const Text(
                                'New student? Create an account',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                // ==================================================
                // FOOTER
                // ==================================================

                Text(
                  '⚛ Learn • Explore • Master Chemistry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.35,
                    ),
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROLE SELECTOR
  // ============================================================

  Widget _roleSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.06,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _roleButton(
              label: 'Student',
              value: false,
              icon: Icons.school_rounded,
            ),
          ),
          Expanded(
            child: _roleButton(
              label: 'Admin',
              value: true,
              icon: Icons.admin_panel_settings_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROLE BUTTON
  // ============================================================

  Widget _roleButton({
    required String label,
    required bool value,
    required IconData icon,
  }) {
    final bool selected = admin == value;

    return GestureDetector(
      onTap: loading
          ? null
          : () {
              setState(() {
                admin = value;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.cyan.withValues(
                  alpha: 0.16,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: selected
                ? AppTheme.cyan.withValues(
                    alpha: 0.35,
                  )
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.cyan.withValues(
                      alpha: 0.08,
                    ),
                    blurRadius: 15,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(
                milliseconds: 250,
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? AppTheme.cyan : Colors.white54,
              ),
            ),
            const SizedBox(
              width: 7,
            ),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.cyan : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
