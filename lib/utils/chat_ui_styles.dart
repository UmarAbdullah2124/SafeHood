import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Typography and spacing aligned with [ChatbotScreen] (SafeBot).
class ChatUiStyles {
  static const double appBarTitleSize = 18;
  static const double appBarSubtitleSize = 11;
  static const double listTitleSize = 17;
  static const double listPreviewSize = 15;
  static const double listSubtitleSize = 11;
  static const double messageFontSize = 15;
  static const double messageTimeSize = 10;
  static const double inputFontSize = 15;

  static const EdgeInsets messageListPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 16);
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets inputBarPadding =
      EdgeInsets.fromLTRB(14, 10, 14, 16);
  static const EdgeInsets inputFieldPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  static const EdgeInsets listTilePadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  static TextStyle get appBarTitle => const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: appBarTitleSize,
      );

  static TextStyle get appBarSubtitle => const TextStyle(
        color: Colors.grey,
        fontSize: appBarSubtitleSize,
      );

  static TextStyle get listTitle => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: listTitleSize,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get listPreview => const TextStyle(
        color: AppColors.textSecondary,
        fontSize: listPreviewSize,
      );

  static TextStyle get listSubtitle => const TextStyle(
        color: AppColors.textSecondary,
        fontSize: listSubtitleSize,
      );

  static BorderRadius bubbleRadius(bool isMine) => BorderRadius.only(
        topLeft: const Radius.circular(22),
        topRight: const Radius.circular(22),
        bottomLeft: Radius.circular(isMine ? 22 : 6),
        bottomRight: Radius.circular(isMine ? 6 : 22),
      );
}
