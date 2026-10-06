// KRATOS Login & Create Account Screen — Wave 3: Create Account + Email Sign In + Google OAuth.
// High-aesthetic Liquid Glass design with official Supabase authentication.

import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../app/kratos_theme.dart';
import '../domain/auth_models.dart';
import '../domain/auth_service.dart';
import 'email_verification_screen.dart';
import 'reset_password_screen.dart';

enum _AuthMode {
  signIn,
  createAccount,
  verifyOtp,
  forgotPassword,
}

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final String? initialError;
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.authService,
    this.initialError,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.signIn;

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String? _verificationEmail;
  String? _verificationName;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isBusySubmitting = false;
  bool _isLaunchingGoogle = false;
  String? _errorMessage;
  String? _successBanner;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialError != oldWidget.initialError) {
      setState(() => _errorMessage = widget.initialError);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode newMode) {
    if (_isBusySubmitting || _isLaunchingGoogle) return;
    setState(() {
      _mode = newMode;
      _errorMessage = null;
      _successBanner = null;
    });
  }

  String? _validateCreateAccountInputs({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (fullName.trim().isEmpty) {
      return 'Please enter your full name.';
    }

    if (email.trim().isEmpty) {
      return 'Please enter your email.';
    }

    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }

    final symbolRegex = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-=+~`\[\]\\/]');
    if (!password.contains(symbolRegex)) {
      return 'Password must contain at least one symbol.';
    }

    if (confirmPassword != password) {
      return 'Passwords do not match.';
    }

    return null;
  }

  Future<void> _handleEmailSignIn() async {
    if (_isBusySubmitting || _isLaunchingGoogle) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isBusySubmitting = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      await widget.authService.signInWithPassword(
        email: email,
        password: password,
      );

      final state = widget.authService.currentState;
      if (state is AuthError && mounted) {
        setState(() => _errorMessage = state.message);
      } else if (state is AuthAuthenticated && mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Incorrect email or password.');
      }
    } finally {
      if (mounted) setState(() => _isBusySubmitting = false);
    }
  }

  Future<void> _handleCreateAccount() async {
    if (_isBusySubmitting || _isLaunchingGoogle) return;

    final fullName = _fullNameCtrl.text;
    final email = _emailCtrl.text;
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    // Strict local validation before contacting Supabase
    final validationError = _validateCreateAccountInputs(
      fullName: fullName,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isBusySubmitting = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      final result = await widget.authService.signUpWithPassword(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
      );

      if (!mounted) return;

      if (result.requiresEmailVerification) {
        // Transition directly to verification screen in-place
        setState(() {
          _verificationEmail = result.email;
          _verificationName = fullName.trim();
          _mode = _AuthMode.verifyOtp;
          _errorMessage = null;
        });
      } else {
        // Instant authenticated session (if auto-confirm is enabled)
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        final state = widget.authService.currentState;
        if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        } else {
          setState(() => _errorMessage = 'Unable to create account. Please try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _isBusySubmitting = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isBusySubmitting || _isLaunchingGoogle) return;

    setState(() {
      _isLaunchingGoogle = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to complete Google sign-in. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLaunchingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _AuthMode.verifyOtp && _verificationEmail != null) {
      return EmailVerificationScreen(
        email: _verificationEmail!,
        fullName: _verificationName,
        authService: widget.authService,
        onVerificationSuccess: widget.onLoginSuccess,
        onBack: () {
          setState(() {
            _mode = _AuthMode.createAccount;
            _errorMessage = null;
          });
        },
      );
    }

    if (_mode == _AuthMode.forgotPassword) {
      return ResetPasswordScreen(
        authService: widget.authService,
        initialEmail: _emailCtrl.text.trim(),
        onBackToSignIn: () {
          setState(() {
            _mode = _AuthMode.signIn;
            _errorMessage = null;
          });
        },
        onResetSuccess: (resetEmail) {
          setState(() {
            _mode = _AuthMode.signIn;
            _emailCtrl.text = resetEmail;
            _passwordCtrl.clear();
            _errorMessage = null;
            _successBanner = 'Password updated successfully! Please sign in with your new password.';
          });
        },
      );
    }

    final state = widget.authService.currentState;
    final isBusy = _isBusySubmitting || _isLaunchingGoogle || state is AuthAuthenticating;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // Main Center Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: KratosTheme.volcanic.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: KratosTheme.borderGlass,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Brand Header
                          const Text(
                            'KRATOS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                              color: KratosTheme.acidLime,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'OPERATING SYSTEM FOR HUMAN ASCENT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.2,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Mode Segmented Switch: Sign In vs Create Account
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: KratosTheme.glassFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: KratosTheme.borderGlass,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _switchMode(_AuthMode.signIn),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _mode == _AuthMode.signIn
                                            ? KratosTheme.acidLime
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Sign In',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _mode == _AuthMode.signIn
                                              ? KratosTheme.volcanic
                                              : Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _switchMode(_AuthMode.createAccount),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _mode == _AuthMode.createAccount
                                            ? KratosTheme.acidLime
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Create Account',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _mode == _AuthMode.createAccount
                                              ? KratosTheme.volcanic
                                              : Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Success message banner (e.g. after password reset)
                          if (_successBanner != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: KratosTheme.acidLime.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: KratosTheme.acidLime.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: KratosTheme.acidLime,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _successBanner!,
                                      style: const TextStyle(
                                        color: KratosTheme.acidLime,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Error message banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Full Name (Only in Create Account mode)
                          if (_mode == _AuthMode.createAccount) ...[
                            TextField(
                              controller: _fullNameCtrl,
                              enabled: !isBusy,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: KratosTheme.glassFill,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: KratosTheme.borderGlass,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: KratosTheme.acidLime,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Input Field
                          TextField(
                            controller: _emailCtrl,
                            enabled: !isBusy,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.alternate_email,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                              filled: true,
                              fillColor: KratosTheme.glassFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: KratosTheme.borderGlass,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: KratosTheme.acidLime,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Input Field
                          TextField(
                            controller: _passwordCtrl,
                            enabled: !isBusy,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              filled: true,
                              fillColor: KratosTheme.glassFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: KratosTheme.borderGlass,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: KratosTheme.acidLime,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: (_) {
                              if (_mode == _AuthMode.signIn) {
                                _handleEmailSignIn();
                              }
                            },
                          ),
                          if (_mode == _AuthMode.signIn) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _mode = _AuthMode.forgotPassword;
                                          _errorMessage = null;
                                        });
                                      },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: KratosTheme.acidLime.withValues(alpha: 0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Confirm Password (Only in Create Account mode)
                          if (_mode == _AuthMode.createAccount) ...[
                            TextField(
                              controller: _confirmPasswordCtrl,
                              enabled: !isBusy,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_reset_outlined,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: KratosTheme.glassFill,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: KratosTheme.borderGlass,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: KratosTheme.acidLime,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _handleCreateAccount(),
                            ),
                            const SizedBox(height: 8),
                          ],

                          const SizedBox(height: 8),

                          // Primary Action Button: "Sign In" or "Create"
                          FilledButton(
                            onPressed: isBusy
                                ? null
                                : (_mode == _AuthMode.signIn
                                    ? _handleEmailSignIn
                                    : _handleCreateAccount),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: KratosTheme.acidLime,
                              disabledBackgroundColor: KratosTheme.acidLime.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isBusySubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        KratosTheme.volcanic,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _mode == _AuthMode.signIn ? 'Sign In' : 'Create',
                                    style: const TextStyle(
                                      color: KratosTheme.volcanic,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 24),

                          // Divider / "OR"
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Continue with Google Button
                          OutlinedButton(
                            onPressed: isBusy ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              side: BorderSide(
                                color: isBusy
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : KratosTheme.acidLime.withValues(alpha: 0.8),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: KratosTheme.glassFill,
                            ),
                            child: _isLaunchingGoogle
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        KratosTheme.acidLime,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _GoogleIcon(),
                                      const SizedBox(width: 12),
                                      const Flexible(
                                        child: Text(
                                          'Continue with Google',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 24),

                          // Security Notice
                          Text(
                            'Secured by Supabase Auth with PKCE and hardware-grade session encryption.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, -0.6, 1.2, true, bluePaint);
    canvas.drawArc(rect, 0.6, 1.0, true, greenPaint);
    canvas.drawArc(rect, 1.6, 1.2, true, yellowPaint);
    canvas.drawArc(rect, 2.8, 1.4, true, redPaint);

    final innerPaint = Paint()..color = const Color(0xFF141414)..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, innerPaint);

    final barRect = Rect.fromLTWH(
      center.dx,
      center.dy - (radius * 0.22),
      radius,
      radius * 0.44,
    );
    canvas.drawRect(barRect, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
