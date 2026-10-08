import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_back_button.dart';
import 'legal_content.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/sign-up');
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      AppBackButton(onPressed: goBack),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ConsentLink',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          document.title,
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.2,
                            letterSpacing: -0.6,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        document.version,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          document.summary,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final section in document.sections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    section.title,
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  section.body,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
