import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

const referenceSerifFamily = 'ReferenceSong';
const referenceLatinFamily = 'ReferenceLatin';

TextStyle referenceSerif(
  YxPalette c,
  double size, {
  Color? color,
  double height = 1.35,
  double spacing = 0,
  bool latin = false,
  bool italic = false,
}) => TextStyle(
  fontFamily:
      AppTypography.family ??
      (latin ? referenceLatinFamily : referenceSerifFamily),
  fontFamilyFallback: const [referenceSerifFamily],
  fontSize: size * AppTypography.scale,
  fontWeight: FontWeight.w400,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  height: height,
  letterSpacing: spacing,
  color: color ?? c.ink1,
);

TextStyle referenceUiText(
  YxPalette c,
  double size, {
  Color? color,
  double height = 1.35,
  double spacing = 0,
}) => TextStyle(
  fontFamily: AppTypography.family,
  fontSize: size * AppTypography.scale,
  height: height,
  letterSpacing: spacing,
  color: color ?? c.ink2,
);
