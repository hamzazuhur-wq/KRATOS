// KRATOS Email Verification Screen — Wave 4: 6-Digit OTP Verification.
// High-aesthetic Liquid Glass design with official Supabase verifyOTP & resend APIs.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/kratos_theme.dart';
import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? fullName;
  final AuthService authService;
  final VoidCallback? onVerificationSuccess;
  final VoidCallback? onBack;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.authService,
    this.fullName,
    this.onVerificationSuccess,
    this.onBack,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successBanner;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
    // Request focus so the operative can type immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
    // Auto-verify if all 6 digits are entered
    if (_codeCtrl.text.length == 6 && !_isVerifying) {
      _handleVerify();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
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

  Future<void> _handleVerify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      await widget.authService.verifySignUpOtp(
        email: widget.email,
        token: code,
      );

      if (!mounted) return;

      final state = widget.authService.currentState;
      if (state is AuthAuthenticated) {
        widget.onVerificationSuccess?.call();
        // Pop the verification modal back if pushed via Navigator
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else if (state is AuthError) {
        setState(() {
          _errorMessage = state.message;
          _codeCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid or expired code.';
          _codeCtrl.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || _isResending || _isVerifying) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successBanner = null;
    });

    try {
      await widget.authService.resendSignUpOtp(email: widget.email);
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _successBanner = 'A new verification code has been sent.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to resend code. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _codeCtrl.text;
    final canVerify = code.length == 6 && !_isVerifying;

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
                          const SizedBox(height: 32),

                          // Header Text
                          const Text(
                            'Enter the code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'We sent a verification code\nto your email.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: KratosTheme.acidLime,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 28),

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
                            const SizedBox(height: 20),
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
                            const SizedBox(height: 20),
                          ],

                          // 6-Digit OTP Input
                          GestureDetector(
                            onTap: () => _focusNode.requestFocus(),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Hidden backing TextField handling paste and native keyboard
                                Opacity(
                                  opacity: 0.0,
                                  child: TextField(
                                    controller: _codeCtrl,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    autofillHints: const [AutofillHints.oneTimeCode],
                                    autocorrect: false,
                                    enableSuggestions: false,
                                  ),
                                ),

                                // Visual 6 Segmented Boxes
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    final char = index < code.length ? code[index] : '';
                                    final isFocused = _focusNode.hasFocus &&
                                        (index == code.length || (index == 5 && code.length == 6));

                                    return Container(
                                      width: 48,
                                      height: 56,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: KratosTheme.glassFill,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isFocused
                                              ? KratosTheme.acidLime
                                              : char.isNotEmpty
                                                  ? Colors.white.withValues(alpha: 0.5)
                                                  : KratosTheme.borderGlass,
                                          width: isFocused ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        char,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: KratosTheme.acidLime,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Verify Button
                          FilledButton(
                            onPressed: canVerify ? _handleVerify : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: KratosTheme.acidLime,
                              disabledBackgroundColor:
                                  KratosTheme.acidLime.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isVerifying
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
                                    'Verify',
                                    style: TextStyle(
                                      color: KratosTheme.volcanic,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Resend Code Button with Cooldown Timer
                          TextButton(
                            onPressed: (_cooldownSeconds == 0 && !_isResending && !_isVerifying)
                                ? _handleResend
                                : null,
                            child: _isResending
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        KratosTheme.acidLime,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _cooldownSeconds > 0
                                        ? 'Resend code in ${_cooldownSeconds}s'
                                        : 'Resend code',
                                    style: TextStyle(
                                      color: _cooldownSeconds > 0
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : KratosTheme.acidLime,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),

                          // Change Email Link
                          Center(
                            child: TextButton(
                              onPressed: () {
                                if (widget.onBack != null) {
                                  widget.onBack!();
                                } else if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Text(
                                'Change email',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
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
