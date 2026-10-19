import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Sahifa tepasidagi alohida rangli sarlavha bandi (ichidagi matn va ikonkalar oq bo'lishi kerak).
class HeaderBand extends StatelessWidget {
  final Widget child;
  const HeaderBand({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 14),
      decoration: BoxDecoration(
        color: dark ? AppColors.headerDark : AppColors.forest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: child,
    );
  }
}
