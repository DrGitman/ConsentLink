import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum Institution {
  nust(
    label: 'NUST',
    fullName: 'Namibia University of Science & Technology',
    initials: 'NU',
    primary: Color(0xFF202D5B),
    accent: Color(0xFFF9B21B),
  ),
  unam(
    label: 'UNAM',
    fullName: 'University of Namibia',
    initials: 'UN',
    primary: Color(0xFFD21034),
    accent: Color(0xFF003580),
  ),
  ium(
    label: 'IUM',
    fullName: 'International University of Management',
    initials: 'IU',
    primary: Color(0xFF0A2540),
    accent: Color(0xFFD4AF37),
  ),
  welwitchia(
    label: 'WU',
    fullName: 'Welwitchia University',
    initials: 'WU',
    primary: Color(0xFF0A4C95),
    accent: Color(0xFFF2BE1A),
  ),
  triumphant(
    label: 'Triumphant College',
    fullName: 'Triumphant College',
    initials: 'TC',
    primary: Color(0xFF1A5F7A),
    accent: Color(0xFFE9A11D),
  ),
  itcLingua(
    label: 'ITC Lingua',
    fullName: 'ITC Lingua',
    initials: 'ITC',
    primary: Color(0xFF00529B),
    accent: Color(0xFFFFD700),
  ),
  independent(
    label: 'Independent',
    fullName: 'Continue without an institution',
    initials: 'CL',
    primary: AppColors.brand,
    accent: AppColors.brandDark,
  );

  const Institution({
    required this.label,
    required this.fullName,
    required this.initials,
    required this.primary,
    required this.accent,
  });

  final String label;
  final String fullName;
  final String initials;
  final Color primary;
  final Color accent;

  bool matches(String query) {
    final search = query.trim().toLowerCase();
    return search.isEmpty ||
        label.toLowerCase().contains(search) ||
        fullName.toLowerCase().contains(search);
  }
}

enum ResearchRole {
  student('Student researcher'),
  staff('Staff researcher'),
  supervisor('Supervisor');

  const ResearchRole(this.label);

  final String label;
}
