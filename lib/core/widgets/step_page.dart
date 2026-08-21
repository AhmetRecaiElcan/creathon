import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'reveal.dart';

/// One question in a multi-step flow: a heading, a line of explanation, and
/// whatever the step actually asks.
///
/// Shared between the visitor and the exhibitor setups so the two flows are
/// visibly the same product, and so a change to the rhythm of the headings
/// only has to be made once.
class StepPage extends StatelessWidget {
  const StepPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xxl,
        AppSpace.xl,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(child: Text(title, style: AppTypography.displayMedium)),
          const SizedBox(height: AppSpace.md),
          Reveal(
            delay: const Duration(milliseconds: 90),
            child: Text(subtitle, style: AppTypography.bodyMedium),
          ),
          const SizedBox(height: AppSpace.xl),
          ...children,
        ],
      ),
    );
  }
}
