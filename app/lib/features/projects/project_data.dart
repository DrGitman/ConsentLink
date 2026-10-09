import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sample projects are shown only with PROJECTS_PREVIEW=true (or the
/// existing DASHBOARD_PREVIEW=true). Normal mode has no data source yet.
final projectsPreviewProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('PROJECTS_PREVIEW') ||
      const bool.fromEnvironment('DASHBOARD_PREVIEW'),
);

enum ProjectStatus { collecting, awaitingEthics, draft, closed }

extension ProjectStatusText on ProjectStatus {
  String get label => switch (this) {
    ProjectStatus.collecting => 'Collecting',
    ProjectStatus.awaitingEthics => 'Awaiting ethics',
    ProjectStatus.draft => 'Draft',
    ProjectStatus.closed => 'Closed',
  };
}

enum ProjectFilter { all, collecting, drafts, closed }

extension ProjectFilterMatch on ProjectFilter {
  bool matches(Project project) => switch (this) {
    ProjectFilter.all => true,
    ProjectFilter.collecting => project.status == ProjectStatus.collecting,
    // Drafts include projects still waiting for ethics approval.
    ProjectFilter.drafts =>
      project.status == ProjectStatus.draft ||
          project.status == ProjectStatus.awaitingEthics,
    ProjectFilter.closed => project.status == ProjectStatus.closed,
  };

  String get label => switch (this) {
    ProjectFilter.all => 'All',
    ProjectFilter.collecting => 'Collecting',
    ProjectFilter.drafts => 'Drafts',
    ProjectFilter.closed => 'Closed',
  };
}

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.languages,
    required this.status,
    required this.target,
    this.consented = 0,
    this.declined = 0,
    this.withdrew = 0,
    this.ethicsRef,
    this.ethicsValidTo,
    this.formTitle,
    this.formSource,
    this.formApproved,
  });

  final String id;
  final String title;
  final String languages;
  final ProjectStatus status;
  final int target;
  final int consented;
  final int declined;
  final int withdrew;
  final String? ethicsRef;
  final String? ethicsValidTo;
  final String? formTitle;
  final String? formSource;
  final String? formApproved;

  double get progress => target == 0 ? 0 : (consented / target).clamp(0, 1);
  bool get canCollect => status == ProjectStatus.collecting;
}

/// Figma 03.3 / 03.4 sample records. Not real participants or approvals.
const sampleProjects = [
  Project(
    id: 'water-opuwo',
    title: 'Water access & health in Opuwo',
    languages: 'Otjiherero',
    status: ProjectStatus.collecting,
    target: 80,
    consented: 64,
    declined: 3,
    withdrew: 2,
    ethicsRef: 'FCI-REC-2026-041',
    ethicsValidTo: 'Mar 2027',
    formTitle: 'Participant consent v2',
    formSource: 'NUST template · Otjiherero + English',
    formApproved: 'Approved by you · 2 Oct',
  ),
  Project(
    id: 'youth-banking',
    title: 'Youth & mobile banking',
    languages: 'Afrikaans · English',
    status: ProjectStatus.collecting,
    target: 40,
    consented: 12,
    declined: 1,
    ethicsRef: 'FCI-REC-2026-052',
    ethicsValidTo: 'Jun 2027',
    formTitle: 'Participant consent v1',
    formSource: 'NUST template · Afrikaans + English',
    formApproved: 'Approved by you · 18 Sep',
  ),
  Project(
    id: 'juhoan-histories',
    title: 'Juǀ’hoan oral histories',
    languages: 'Juǀ’hoansi via interpreter',
    status: ProjectStatus.awaitingEthics,
    target: 25,
    formTitle: 'Participant consent v1',
    formSource: 'NUST template · Juǀ’hoansi + English',
  ),
  Project(
    id: 'rundu-traders',
    title: 'Rundu market traders',
    languages: 'Rukwangali',
    status: ProjectStatus.draft,
    target: 0,
  ),
  Project(
    id: 'katutura-clinics',
    title: 'Clinic waiting times in Katutura',
    languages: 'Oshiwambo · English',
    status: ProjectStatus.closed,
    target: 30,
    consented: 30,
    declined: 4,
    ethicsRef: 'FCI-REC-2025-118',
    ethicsValidTo: 'Dec 2026',
    formTitle: 'Participant consent v3',
    formSource: 'NUST template · Oshiwambo + English',
    formApproved: 'Approved by you · 4 May',
  ),
];

final projectsProvider = Provider<List<Project>>(
  (ref) => ref.watch(projectsPreviewProvider) ? sampleProjects : const [],
);

final projectFilterProvider = StateProvider<ProjectFilter>(
  (ref) => ProjectFilter.all,
);
