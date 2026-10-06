// KRATOS Reset Password Screen — Wave 5+: Forgot & Reset Password Flow.
// Liquid Glass UI for requesting reset OTP, verifying 6-8 digit code on isolated page,
// and setting new password before returning to the main sign-in screen.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../app/kratos_theme.dart';
import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

enum _ResetStep {
  requestEmail,
  enterOtp,
  setNewPassword,
}

class ResetPasswordScreen extends StatefulWidget {
  final AuthService authService;
  final String? initialEmail;
  final VoidCallback onBackToSignIn;
  final void Function(String email)? onResetSuccess;

  const ResetPasswordScreen({
    super.key,
    required this.authService,
    this.initialEmail,
    required this.onBackToSignIn,
    this.onResetSuccess,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  _ResetStep _step = _ResetStep.requestEmail;

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _codeFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isBusy = false;
  String? _errorMessage;
  String? _successBanner;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _codeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  String? _validateNewPassword(String password, String confirmPassword) {
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

  // STEP 1: Send Reset Code
  Future<void> _handleSendResetCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      await widget.authService.resetPasswordForEmail(email);
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _step = _ResetStep.enterOtp;
        _codeCtrl.clear();
        _successBanner = 'Recovery code sent! Check your inbox.';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocusNode.requestFocus();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to send reset code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // STEP 2 Resend: Resend Code
  Future<void> _handleResendResetCode() async {
    if (_cooldownSeconds > 0 || _isBusy) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      await widget.authService.resetPasswordForEmail(email);
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _successBanner = 'A fresh recovery code has been sent.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to resend code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // STEP 2: Verify Code (صفحة الكود لحالها)
  Future<void> _handleVerifyCode() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (code.length < 6 || code.length > 8) {
      setState(() => _errorMessage = 'Please enter the 6 to 8 digit recovery code.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      await widget.authService.verifyRecoveryOtp(
        email: email,
        token: code,
      );

      if (!mounted) return;

      setState(() {
        _step = _ResetStep.setNewPassword;
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
        _successBanner = 'Code verified! Set your new password below.';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _newPasswordFocusNode.requestFocus();
      });
    } catch (e) {
      if (mounted) {
        if (e is supa.AuthException) {
          setState(() => _errorMessage = e.message);
        } else {
          final state = widget.authService.currentState;
          if (state is AuthError) {
            setState(() => _errorMessage = state.message);
          } else {
            setState(() => _errorMessage = 'Token has expired or is invalid.');
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // STEP 3: Set New Password & Sign Out -> Redirect to Login
  Future<void> _handleSaveNewPassword() async {
    final email = _emailCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    final validationError = _validateNewPassword(newPassword, confirmPassword);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      // Updates password in database and signs out of recovery session cleanly
      await widget.authService.updatePassword(newPassword);

      if (!mounted) return;

      // Returns to main sign-in screen
      widget.onResetSuccess?.call(email);
    } catch (e) {
      if (mounted) {
        if (e is supa.AuthException) {
          setState(() => _errorMessage = e.message);
        } else {
          final state = widget.authService.currentState;
          if (state is AuthError) {
            setState(() => _errorMessage = state.message);
          } else {
            setState(() => _errorMessage = 'Failed to update password. Please try again.');
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _handleBackNavigation() {
    if (_isBusy) return;
    setState(() {
      _errorMessage = null;
      _successBanner = null;
      if (_step == _ResetStep.setNewPassword) {
        _step = _ResetStep.enterOtp;
      } else if (_step == _ResetStep.enterOtp) {
        _step = _ResetStep.requestEmail;
      } else {
        widget.onBackToSignIn();
      }
    });
  }

  String get _backButtonLabel {
    return switch (_step) {
      _ResetStep.requestEmail => 'Back to Sign In',
      _ResetStep.enterOtp => 'Change Email',
      _ResetStep.setNewPassword => 'Back to Code',
    };
  }

  String get _screenTitle {
    return switch (_step) {
      _ResetStep.requestEmail => 'Reset Password',
      _ResetStep.enterOtp => 'Enter Recovery Code',
      _ResetStep.setNewPassword => 'Set New Password',
    };
  }

  String get _screenSubtitle {
    final email = _emailCtrl.text.trim();
    return switch (_step) {
      _ResetStep.requestEmail =>
        'Enter your email address and we will send you a password recovery code.',
      _ResetStep.enterOtp =>
        'Check your inbox for $email and enter the 6 to 8-digit code below.',
      _ResetStep.setNewPassword =>
        'Your code was verified successfully. Create a strong new password for your account.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // Main Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: KratosTheme.surfaceGlass,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: KratosTheme.borderGlass,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Back Button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: _isBusy ? null : _handleBackNavigation,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 14,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _backButtonLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Icon Header
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: KratosTheme.acidLime.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: KratosTheme.acidLime.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _step == _ResetStep.enterOtp
                                    ? Icons.pin_outlined
                                    : _step == _ResetStep.setNewPassword
                                        ? Icons.lock_open_outlined
                                        : Icons.lock_reset,
                                color: KratosTheme.acidLime,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _screenTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            _screenSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.65),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Success Banner
                          if (_successBanner != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: KratosTheme.acidLime.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: KratosTheme.acidLime.withValues(alpha: 0.4),
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
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Error Banner
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
                            const SizedBox(height: 16),
                          ],

                          // ══════════════════════════════════════════════
                          // STEP 1: Email Request
                          // ══════════════════════════════════════════════
                          if (_step == _ResetStep.requestEmail) ...[
                            TextField(
                              controller: _emailCtrl,
                              enabled: !_isBusy,
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
                              onSubmitted: (_) => _handleSendResetCode(),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _isBusy ? null : _handleSendResetCode,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: KratosTheme.acidLime,
                                disabledBackgroundColor:
                                    KratosTheme.acidLime.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isBusy
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
                                  : const Text(
                                      'Send Reset Code',
                                      style: TextStyle(
                                        color: KratosTheme.volcanic,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ],

                          // ══════════════════════════════════════════════
                          // STEP 2: Enter Code Only (صفحة لحالها للكود)
                          // ══════════════════════════════════════════════
                          if (_step == _ResetStep.enterOtp) ...[
                            TextField(
                              controller: _codeCtrl,
                              focusNode: _codeFocusNode,
                              enabled: !_isBusy,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: KratosTheme.acidLime,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 6,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontSize: 24,
                                  letterSpacing: 6,
                                ),
                                labelText: 'Recovery Code (6-8 Digits)',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  letterSpacing: 0,
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
                              onSubmitted: (_) => _handleVerifyCode(),
                            ),
                            const SizedBox(height: 24),

                            FilledButton(
                              onPressed: _isBusy ? null : _handleVerifyCode,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: KratosTheme.acidLime,
                                disabledBackgroundColor:
                                    KratosTheme.acidLime.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isBusy
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
                                  : const Text(
                                      'Verify Code',
                                      style: TextStyle(
                                        color: KratosTheme.volcanic,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // Resend Code Option
                            Center(
                              child: TextButton(
                                onPressed: (_cooldownSeconds > 0 || _isBusy)
                                    ? null
                                    : _handleResendResetCode,
                                child: Text(
                                  _cooldownSeconds > 0
                                      ? 'Resend code in ${_cooldownSeconds}s'
                                      : 'Didn\'t receive code? Resend',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _cooldownSeconds > 0
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : KratosTheme.acidLime,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // ══════════════════════════════════════════════
                          // STEP 3: Set New Password (صفحة جديدة لكلمة السر)
                          // ══════════════════════════════════════════════
                          if (_step == _ResetStep.setNewPassword) ...[
                            // New Password Field
                            TextField(
                              controller: _newPasswordCtrl,
                              focusNode: _newPasswordFocusNode,
                              enabled: !_isBusy,
                              obscureText: _obscureNewPassword,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'New Password',
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
                                    _obscureNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword = !_obscureNewPassword;
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
                            ),
                            const SizedBox(height: 16),

                            // Confirm New Password Field
                            TextField(
                              controller: _confirmPasswordCtrl,
                              enabled: !_isBusy,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
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
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
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
                              onSubmitted: (_) => _handleSaveNewPassword(),
                            ),
                            const SizedBox(height: 24),

                            // Submit Reset Button
                            FilledButton(
                              onPressed: _isBusy
                                  ? null
                                  : _handleSaveNewPassword,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: KratosTheme.acidLime,
                                disabledBackgroundColor:
                                    KratosTheme.acidLime.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isBusy
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
                                  : const Text(
                                      'Save New Password',
                                      style: TextStyle(
                                        color: KratosTheme.volcanic,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ],
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
