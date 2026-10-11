import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class KratosCardTokens extends ThemeExtension<KratosCardTokens> {
  // Shape & Padding
  final double radius;
  final EdgeInsetsGeometry defaultPadding;

  // Accents & Glow
  final Color accentColor;
  final Color glowColor;

  // Surface fill & blur
  final Color glassFill;
  final double blurSigma;

  // Surfaces (Gradients)
  final Gradient backgroundNormal;
  final Gradient backgroundActive;
  final Gradient backgroundElevated;

  // Borders
  final Color borderNormal;
  final Color borderHover;
  final Color borderActive;
  final Color borderElevated;
  final Color borderElevatedHover;
  final Color borderDisabled;

  final double borderWidthNormal;
  final double borderWidthActive;

  // Shadows
  final List<BoxShadow> shadowNormal;
  final List<BoxShadow> shadowHover;
  final List<BoxShadow> shadowActive;
  final List<BoxShadow> shadowActiveHover;
  final List<BoxShadow> shadowElevated;
  final List<BoxShadow> shadowElevatedHover;
  final List<BoxShadow> shadowDisabled;

  // Overlays (Glass specular/sheen effects)
  final Color sheenColor;
  final double sheenOpacity;

  final Color specularColorNormal;
  final double specularOpacityNormal;
  final Color specularColorActive;
  final double specularOpacityActive;

  const KratosCardTokens({
    required this.radius,
    required this.defaultPadding,
    required this.accentColor,
    this.glowColor = const Color(0xFFEDFF45),
    this.glassFill = const Color(0x6B1B1E1B),
    this.blurSigma = 28.0,
    required this.backgroundNormal,
    required this.backgroundActive,
    required this.backgroundElevated,
    required this.borderNormal,
    required this.borderHover,
    required this.borderActive,
    required this.borderElevated,
    required this.borderElevatedHover,
    required this.borderDisabled,
    required this.borderWidthNormal,
    required this.borderWidthActive,
    required this.shadowNormal,
    required this.shadowHover,
    required this.shadowActive,
    required this.shadowActiveHover,
    required this.shadowElevated,
    required this.shadowElevatedHover,
    required this.shadowDisabled,
    required this.sheenColor,
    required this.sheenOpacity,
    required this.specularColorNormal,
    required this.specularOpacityNormal,
    required this.specularColorActive,
    required this.specularOpacityActive,
  });

  factory KratosCardTokens.dark() {
    return KratosCardTokens(
      radius: 23.0,
      defaultPadding: const EdgeInsets.all(16.0),
      accentColor: const Color(0xFFEEFF08),
      glowColor: const Color(0xFFEEFF08),
      glassFill: const Color(0x6B1B1E1B),
      blurSigma: 18.0,
      backgroundNormal: const LinearGradient(
        begin: Alignment(-0.82, -0.57),
        end: Alignment(0.82, 0.57),
        colors: [
          Color(0xE6191F19), // rgba(25, 31, 25, 0.90)
          Color(0xCC070A08), // rgba(7, 10, 8, 0.80)
        ],
      ),
      backgroundActive: const LinearGradient(
        begin: Alignment(-0.82, -0.57),
        end: Alignment(0.82, 0.57),
        colors: [
          Color(0xF7282F1A), // rgba(40, 47, 26, 0.97)
          Color(0xEB0E1107), // rgba(14, 17, 7, 0.92)
        ],
      ),
      backgroundElevated: const LinearGradient(
        begin: Alignment(-0.82, -0.57),
        end: Alignment(0.82, 0.57),
        colors: [
          Color(0xF2262D23), // rgba(38, 45, 35, 0.95)
          Color(0xE0090C09), // rgba(9, 12, 9, 0.88)
        ],
      ),
      borderNormal: Colors.white.withValues(alpha: 0.22),
      borderHover: const Color(0xFFEEFF08).withValues(alpha: 0.50),
      borderActive: const Color(0xFFEEFF08).withValues(alpha: 0.70),
      borderElevated: const Color(0xFFEEFF08).withValues(alpha: 0.26),
      borderElevatedHover: const Color(0xFFEEFF08).withValues(alpha: 0.55),
      borderDisabled: const Color(0x1FA8AAA1),
      borderWidthNormal: 1.0,
      borderWidthActive: 1.2,
      shadowNormal: const [
        BoxShadow(
          color: Color(0x2E000000), // rgba(0, 0, 0, 0.18)
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
      shadowHover: [
        const BoxShadow(
          color: Color(0x47000000), // rgba(0, 0, 0, 0.28)
          blurRadius: 32,
          offset: Offset(0, 15),
        ),
        BoxShadow(
          color: const Color(0xFFEEFF08).withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      shadowActive: [
        BoxShadow(
          color: const Color(0xFFEEFF08).withValues(alpha: 0.06),
          blurRadius: 22,
        ),
        const BoxShadow(
          color: Color(0x40000000),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
      shadowActiveHover: [
        BoxShadow(
          color: const Color(0xFFEEFF08).withValues(alpha: 0.18),
          blurRadius: 26,
        ),
        const BoxShadow(
          color: Color(0x52000000),
          blurRadius: 32,
          offset: Offset(0, 15),
        ),
      ],
      shadowElevated: const [
        BoxShadow(
          color: Color(0x52000000), // rgba(0, 0, 0, 0.32)
          blurRadius: 35,
          offset: Offset(0, 17),
        ),
      ],
      shadowElevatedHover: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 40,
          offset: Offset(0, 20),
        ),
      ],
      shadowDisabled: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      sheenColor: Colors.white,
      sheenOpacity: 0.05,
      specularColorNormal: const Color(0xFFEEFF08),
      specularOpacityNormal: 0.85,
      specularColorActive: const Color(0xFFEEFF08),
      specularOpacityActive: 0.95,
    );
  }

  factory KratosCardTokens.light() {
    return KratosCardTokens(
      radius: 23.0,
      defaultPadding: const EdgeInsets.all(16.0),
      accentColor: const Color(0xFFA8B800),
      glowColor: const Color(0xFFA8B800),
      glassFill: Colors.white.withValues(alpha: 0.36),
      blurSigma: 18.0,
      backgroundNormal: const LinearGradient(
        begin: Alignment(-0.82, -0.57),
        end: Alignment(0.82, 0.57),
        colors: [
          Color(0xC7F1F4ED), // rgba(241, 244, 237, 0.78)
          Color(0xD1E5EBE2), // rgba(229, 235, 226, 0.82)
        ],
      ),
      backgroundActive: const LinearGradient(
        begin: Alignment(-0.82, -0.57),
        end: Alignment(0.82, 0.57),
        colors: [
          Color(0xFAF1F4D7), // rgba(241, 244, 215, 0.98)
          Color(0xF5E5EBE2), // rgba(229, 235, 226, 0.96)
        ],
      ),
      backgroundElevated: const LinearGradient(
        begin: Alignment(-0.82, -0.57),
        end: Alignment(0.82, 0.57),
        colors: [
          Color(0xFFF1F4ED), // #f1f4ed
          Color(0xFAE2E9E0), // rgba(226, 233, 224, 0.98)
        ],
      ),
      borderNormal: Colors.white.withValues(alpha: 0.80),
      borderHover: const Color(0xFFA8B800).withValues(alpha: 0.50),
      borderActive: const Color(0xFFA8B800).withValues(alpha: 0.46),
      borderElevated: const Color(0x1710130F), // rgba(16, 19, 15, 0.09)
      borderElevatedHover: const Color(0xFFA8B800).withValues(alpha: 0.60),
      borderDisabled: const Color(0x1210130F), // rgba(16, 19, 15, 0.07)
      borderWidthNormal: 1.0,
      borderWidthActive: 1.2,
      shadowNormal: const [
        BoxShadow(
          color: Color(0x0F262C24), // rgba(38, 44, 36, 0.06)
          blurRadius: 28,
          offset: Offset(0, 13),
        ),
      ],
      shadowHover: const [
        BoxShadow(
          color: Color(0x1F262C24),
          blurRadius: 32,
          offset: Offset(0, 16),
        ),
      ],
      shadowActive: [
        BoxShadow(
          color: const Color(0xFFA8B800).withValues(alpha: 0.05),
          blurRadius: 3,
          spreadRadius: 3,
        ),
        const BoxShadow(
          color: Color(0x0F262C24),
          blurRadius: 28,
          offset: Offset(0, 13),
        ),
      ],
      shadowActiveHover: [
        BoxShadow(
          color: const Color(0xFFA8B800).withValues(alpha: 0.12),
          blurRadius: 6,
          spreadRadius: 3,
        ),
        const BoxShadow(
          color: Color(0x17262C24),
          blurRadius: 32,
          offset: Offset(0, 16),
        ),
      ],
      shadowElevated: const [
        BoxShadow(
          color: Color(0x14262C24), // rgba(38, 44, 36, 0.08)
          blurRadius: 32,
          offset: Offset(0, 18),
        ),
      ],
      shadowElevatedHover: const [
        BoxShadow(
          color: Color(0x24262C24),
          blurRadius: 36,
          offset: Offset(0, 20),
        ),
      ],
      shadowDisabled: const [
        BoxShadow(
          color: Color(0x08262C24),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      sheenColor: Colors.white,
      sheenOpacity: 0.55,
      specularColorNormal: const Color(0xFFA8B800),
      specularOpacityNormal: 0.75,
      specularColorActive: const Color(0xFFA8B800),
      specularOpacityActive: 0.85,
    );
  }

  @override
  ThemeExtension<KratosCardTokens> copyWith({
    double? radius,
    EdgeInsetsGeometry? defaultPadding,
    Color? accentColor,
    Color? glowColor,
    Color? glassFill,
    double? blurSigma,
    Gradient? backgroundNormal,
    Gradient? backgroundActive,
    Gradient? backgroundElevated,
    Color? borderNormal,
    Color? borderHover,
    Color? borderActive,
    Color? borderElevated,
    Color? borderElevatedHover,
    Color? borderDisabled,
    double? borderWidthNormal,
    double? borderWidthActive,
    List<BoxShadow>? shadowNormal,
    List<BoxShadow>? shadowHover,
    List<BoxShadow>? shadowActive,
    List<BoxShadow>? shadowActiveHover,
    List<BoxShadow>? shadowElevated,
    List<BoxShadow>? shadowElevatedHover,
    List<BoxShadow>? shadowDisabled,
    Color? sheenColor,
    double? sheenOpacity,
    Color? specularColorNormal,
    double? specularOpacityNormal,
    Color? specularColorActive,
    double? specularOpacityActive,
  }) {
    return KratosCardTokens(
      radius: radius ?? this.radius,
      defaultPadding: defaultPadding ?? this.defaultPadding,
      accentColor: accentColor ?? this.accentColor,
      glowColor: glowColor ?? this.glowColor,
      glassFill: glassFill ?? this.glassFill,
      blurSigma: blurSigma ?? this.blurSigma,
      backgroundNormal: backgroundNormal ?? this.backgroundNormal,
      backgroundActive: backgroundActive ?? this.backgroundActive,
      backgroundElevated: backgroundElevated ?? this.backgroundElevated,
      borderNormal: borderNormal ?? this.borderNormal,
      borderHover: borderHover ?? this.borderHover,
      borderActive: borderActive ?? this.borderActive,
      borderElevated: borderElevated ?? this.borderElevated,
      borderElevatedHover: borderElevatedHover ?? this.borderElevatedHover,
      borderDisabled: borderDisabled ?? this.borderDisabled,
      borderWidthNormal: borderWidthNormal ?? this.borderWidthNormal,
      borderWidthActive: borderWidthActive ?? this.borderWidthActive,
      shadowNormal: shadowNormal ?? this.shadowNormal,
      shadowHover: shadowHover ?? this.shadowHover,
      shadowActive: shadowActive ?? this.shadowActive,
      shadowActiveHover: shadowActiveHover ?? this.shadowActiveHover,
      shadowElevated: shadowElevated ?? this.shadowElevated,
      shadowElevatedHover: shadowElevatedHover ?? this.shadowElevatedHover,
      shadowDisabled: shadowDisabled ?? this.shadowDisabled,
      sheenColor: sheenColor ?? this.sheenColor,
      sheenOpacity: sheenOpacity ?? this.sheenOpacity,
      specularColorNormal: specularColorNormal ?? this.specularColorNormal,
      specularOpacityNormal: specularOpacityNormal ?? this.specularOpacityNormal,
      specularColorActive: specularColorActive ?? this.specularColorActive,
      specularOpacityActive: specularOpacityActive ?? this.specularOpacityActive,
    );
  }

  @override
  ThemeExtension<KratosCardTokens> lerp(
      covariant ThemeExtension<KratosCardTokens>? other, double t) {
    if (other is! KratosCardTokens) {
      return this;
    }
    return KratosCardTokens(
      radius: ui.lerpDouble(radius, other.radius, t) ?? radius,
      defaultPadding: EdgeInsetsGeometry.lerp(defaultPadding, other.defaultPadding, t) ?? defaultPadding,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      glowColor: Color.lerp(glowColor, other.glowColor, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      blurSigma: ui.lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      backgroundNormal: Gradient.lerp(backgroundNormal, other.backgroundNormal, t)!,
      backgroundActive: Gradient.lerp(backgroundActive, other.backgroundActive, t)!,
      backgroundElevated: Gradient.lerp(backgroundElevated, other.backgroundElevated, t)!,
      borderNormal: Color.lerp(borderNormal, other.borderNormal, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      borderActive: Color.lerp(borderActive, other.borderActive, t)!,
      borderElevated: Color.lerp(borderElevated, other.borderElevated, t)!,
      borderElevatedHover: Color.lerp(borderElevatedHover, other.borderElevatedHover, t)!,
      borderDisabled: Color.lerp(borderDisabled, other.borderDisabled, t)!,
      borderWidthNormal: ui.lerpDouble(borderWidthNormal, other.borderWidthNormal, t) ?? borderWidthNormal,
      borderWidthActive: ui.lerpDouble(borderWidthActive, other.borderWidthActive, t) ?? borderWidthActive,
      shadowNormal: BoxShadow.lerpList(shadowNormal, other.shadowNormal, t)!,
      shadowHover: BoxShadow.lerpList(shadowHover, other.shadowHover, t)!,
      shadowActive: BoxShadow.lerpList(shadowActive, other.shadowActive, t)!,
      shadowActiveHover: BoxShadow.lerpList(shadowActiveHover, other.shadowActiveHover, t)!,
      shadowElevated: BoxShadow.lerpList(shadowElevated, other.shadowElevated, t)!,
      shadowElevatedHover: BoxShadow.lerpList(shadowElevatedHover, other.shadowElevatedHover, t)!,
      shadowDisabled: BoxShadow.lerpList(shadowDisabled, other.shadowDisabled, t)!,
      sheenColor: Color.lerp(sheenColor, other.sheenColor, t)!,
      sheenOpacity: ui.lerpDouble(sheenOpacity, other.sheenOpacity, t) ?? sheenOpacity,
      specularColorNormal: Color.lerp(specularColorNormal, other.specularColorNormal, t)!,
      specularOpacityNormal: ui.lerpDouble(specularOpacityNormal, other.specularOpacityNormal, t) ?? specularOpacityNormal,
      specularColorActive: Color.lerp(specularColorActive, other.specularColorActive, t)!,
      specularOpacityActive: ui.lerpDouble(specularOpacityActive, other.specularOpacityActive, t) ?? specularOpacityActive,
    );
  }
}
