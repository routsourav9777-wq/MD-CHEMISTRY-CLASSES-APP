import 'package:flutter/material.dart';

import 'auth_service.dart';
import '../../core/chemistry_background.dart';
import '../../core/glass_card.dart';
import '../../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController name = TextEditingController();

  final TextEditingController email = TextEditingController();

  final TextEditingController phone = TextEditingController();

  final TextEditingController pass = TextEditingController();

  final TextEditingController confirm = TextEditingController();

  final AuthService service = AuthService();

  // ============================================================
  // VARIABLES
  // ============================================================

  String semester = 'Semester 1';

  bool loading = false;

  bool obscurePassword = true;

  bool obscureConfirmPassword = true;

  // ============================================================
  // PASSWORD MISMATCH
  // ============================================================

  bool get passwordMismatch {
    if (confirm.text.isEmpty) {
      return false;
    }

    return pass.text != confirm.text;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    pass.dispose();
    confirm.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> submit() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // CHECK EMPTY FIELDS
    // ----------------------------------------------------------

    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        pass.text.isEmpty ||
        confirm.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all fields.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // PHONE VALIDATION
    // ----------------------------------------------------------

    final String phoneNumber = phone.text.trim();

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid 10-digit phone number.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // PASSWORD VALIDATION
    // ----------------------------------------------------------

    if (pass.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 6 characters.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // CONFIRM PASSWORD
    // ----------------------------------------------------------

    if (pass.text != confirm.text) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passwords do not match.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    setState(() {
      loading = true;
    });

    try {
      // --------------------------------------------------------
      // REGISTER STUDENT
      // --------------------------------------------------------

      await service.registerStudent(
        name: name.text.trim(),
        email: email.text.trim(),
        phone: phoneNumber,
        semester: semester,
        password: pass.text,
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // SUCCESS DIALOG
      // --------------------------------------------------------

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Registration Submitted',
            ),
            content: const Text(
              'Your account is pending Admin approval. '
              'You can log in after approval.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  // Close dialog
                  Navigator.of(
                    dialogContext,
                  ).pop();

                  // Go back to LoginScreen
                  Navigator.of(
                    context,
                  ).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString();

      // --------------------------------------------------------
      // FRIENDLY FIREBASE ERRORS
      // --------------------------------------------------------

      if (errorMessage.contains('email-already-in-use')) {
        errorMessage = 'This email is already registered.';
      } else if (errorMessage.contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (errorMessage.contains('weak-password')) {
        errorMessage = 'Password is too weak.';
      } else if (errorMessage.contains('network-request-failed')) {
        errorMessage = 'Please check your internet connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
          ),
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
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: ChemistryBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // LOGO
                  // ==================================================

                  const Icon(
                    Icons.science_rounded,
                    color: AppTheme.cyan,
                    size: 55,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Text(
                    'Student Registration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  // ==================================================
                  // NAME
                  // ==================================================

                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Sambhab Ojha',
                      prefixIcon: Icon(
                        Icons.person_outline,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
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
                      hintText: 'example@gmail.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // PHONE NUMBER
                  // ==================================================

                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '9876543210',
                      prefixText: '+91 ',
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                      ),
                      counterText: '',
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // SEMESTER
                  // ==================================================

                  DropdownButtonFormField<String>(
                    initialValue: semester,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      prefixIcon: Icon(
                        Icons.school_outlined,
                      ),
                    ),
                    items: List.generate(
                      6,
                      (index) {
                        final value = 'Semester ${index + 1}';

                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                          ),
                        );
                      },
                    ),
                    onChanged: loading
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              semester = value;
                            });
                          },
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // PASSWORD
                  // ==================================================

                  TextField(
                    controller: pass,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        tooltip:
                            obscurePassword ? 'Show password' : 'Hide password',
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // CONFIRM PASSWORD
                  // ==================================================

                  TextField(
                    controller: confirm,
                    obscureText: obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      if (!loading && !passwordMismatch) {
                        submit();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter password',

                      // Red error
                      errorText:
                          passwordMismatch ? 'Passwords do not match' : null,

                      prefixIcon: Icon(
                        passwordMismatch
                            ? Icons.error_outline
                            : Icons.lock_reset_outlined,
                        color: passwordMismatch ? Colors.red : null,
                      ),

                      suffixIcon: IconButton(
                        tooltip: obscureConfirmPassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: passwordMismatch ? Colors.red : null,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // CREATE ACCOUNT
                  // ==================================================

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: loading || passwordMismatch ? null : submit,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CREATE ACCOUNT',
                            ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // PASSWORD STATUS
                  // ==================================================

                  if (passwordMismatch)
                    const Text(
                      'Please enter the same password in both fields.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
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
