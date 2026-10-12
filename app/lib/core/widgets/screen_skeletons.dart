import 'package:flutter/material.dart';

import 'skeleton.dart';

/// Figma row 11 skeletons (3:14790 … 3:15623). Only the content area; the
/// real header, chips, back buttons and tab bar stay on screen. Sizes,
/// radii and gaps are the Figma ones (390 × 844 artboards, 20 dp margins).

Widget _gap(double h) => SizedBox(height: h);

/// 11.1 Dashboard (whole page under the status bar).
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  // Figma bar heights (bottoms line up 200 dp down the card).
  static const _bars = [
    (20.0, 182.0, 18.0),
    (38.0, 156.0, 44.0),
    (55.0, 143.0, 57.0),
    (73.0, 147.0, 53.0),
    (90.0, 169.0, 31.0),
    (108.0, 168.0, 32.0),
    (125.0, 147.0, 53.0),
    (143.0, 143.0, 57.0),
    (160.0, 157.0, 43.0),
    (178.0, 181.0, 19.0),
    (195.0, 156.0, 44.0),
    (213.0, 142.0, 58.0),
    (230.0, 148.0, 52.0),
    (248.0, 169.0, 31.0),
    (265.0, 167.0, 33.0),
    (283.0, 147.0, 53.0),
    (300.0, 143.0, 57.0),
    (318.0, 157.0, 43.0),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Bone(44, 44, radius: 14),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Bone(90, 10), SizedBox(height: 8), Bone(130, 14)],
          ),
          const Spacer(),
          const Bone(44, 44, circle: true),
          const SizedBox(width: 8),
          const Bone(44, 44, circle: true),
        ],
      ),
      _gap(16),
      const Bone(double.infinity, 44, soft: true),
      _gap(14),
      BoneCard(
        height: 236,
        bones: [
          const B(20, 20, 120, 10),
          const B(20, 42, 90, 34, r: 10),
          const B(20, 86, 170, 10, soft: true),
          for (final (x, y, h) in _bars)
            B(x, y, 10, h, r: 5, soft: true, anchor: BoneAnchor.scale),
        ],
      ),
      _gap(18),
      const Bone(120, 14),
      _gap(18),
      Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(
              child: BoneCard(
                height: 124,
                figmaWidth: 110,
                bones: [
                  B(14, 14, 40, 40, circle: true),
                  B(14, 70, 70, 10),
                  B(14, 90, 50, 8, soft: true),
                ],
              ),
            ),
          ],
        ],
      ),
      _gap(18),
      const Bone(130, 14),
      _gap(16),
      const BoneCard(
        height: 96,
        bones: [
          B(18, 18, 220, 12),
          B(18, 42, 140, 8, soft: true),
          B(18, 66, 250, 8, soft: true),
        ],
      ),
    ],
  );
}

/// 11.2 Projects: four project cards under the real title and chips.
class ProjectsSkeleton extends StatelessWidget {
  const ProjectsSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) _gap(12),
        const BoneCard(
          height: 138,
          bones: [
            B(18, 16, 90, 24, soft: true),
            B(18, 54, 240, 14),
            B(18, 78, 150, 10, soft: true),
            B(18, 108, 250, 8),
            B(282, 104, 50, 12, soft: true, anchor: BoneAnchor.right),
          ],
        ),
      ],
    ],
  );
}

/// 11.3 Project detail: title, badge, stats, form card, start capture,
/// other ways — under the real back and more buttons.
class ProjectDetailSkeleton extends StatelessWidget {
  const ProjectDetailSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _gap(4),
      const Bone(300, 22, radius: 8),
      _gap(8),
      const Bone(210, 22, radius: 8),
      _gap(18),
      const Bone(260, 26, soft: true),
      _gap(14),
      const BoneCard(
        height: 104,
        bones: [
          B(20, 20, 50, 28, r: 8),
          B(20, 60, 70, 10, soft: true),
          B(132, 20, 50, 28, r: 8, anchor: BoneAnchor.scale),
          B(132, 60, 70, 10, soft: true, anchor: BoneAnchor.scale),
          B(244, 20, 50, 28, r: 8, anchor: BoneAnchor.scale),
          B(244, 60, 70, 10, soft: true, anchor: BoneAnchor.scale),
        ],
      ),
      _gap(18),
      const Bone(120, 14),
      _gap(16),
      const BoneCard(
        height: 120,
        bones: [
          B(16, 16, 62, 88, r: 10, soft: true),
          B(92, 20, 180, 12),
          B(92, 42, 140, 10, soft: true),
          B(92, 66, 120, 22, soft: true),
        ],
      ),
      _gap(18),
      const Bone(130, 14),
      _gap(16),
      const Bone(double.infinity, 60),
      _gap(12),
      const BoneCard(
        height: 112,
        bones: [
          B(16, 12, 40, 40, circle: true),
          B(68, 20, 150, 12),
          B(68, 38, 190, 8, soft: true),
          B(16, 64, 40, 40, circle: true),
          B(68, 72, 150, 12),
          B(68, 90, 190, 8, soft: true),
        ],
      ),
    ],
  );
}

/// 11.4 Review AI draft: language chips, checklist, section cards.
class ReviewDraftSkeleton extends StatelessWidget {
  const ReviewDraftSkeleton({super.key});

  static const _short = BoneCard(
    height: 66,
    bones: [
      B(16, 16, 150, 12),
      B(252, 14, 82, 24, soft: true, anchor: BoneAnchor.right),
      B(16, 40, 200, 8, soft: true),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Bone(110, 38),
          SizedBox(width: 8),
          Bone(120, 38, soft: true),
        ],
      ),
      _gap(16),
      const BoneCard(
        height: 74,
        radius: 20,
        color: Color(0xFFFBF6EA),
        bones: [
          B(16, 16, 26, 26, color: Color(0xFFF2E4C4)),
          B(52, 16, 220, 12, color: Color(0xFFF2E4C4)),
          B(52, 40, 170, 10, color: Color(0xFFF7ECD3)),
        ],
      ),
      _gap(14),
      _short,
      _gap(10),
      const BoneCard(
        height: 150,
        bones: [
          B(16, 16, 150, 12),
          B(252, 14, 82, 24, soft: true, anchor: BoneAnchor.right),
          B(16, 52, 318, 9, r: 4, soft: true),
          B(16, 70, 300, 9, r: 4, soft: true),
          B(16, 88, 220, 9, r: 4, soft: true),
          B(16, 112, 92, 30),
          B(116, 112, 92, 30),
          B(214, 112, 120, 30),
        ],
      ),
      _gap(10),
      _short,
      _gap(10),
      _short,
    ],
  );
}

/// 11.5 Insights: goal chart, four KPI tiles, understanding by language.
class InsightsSkeleton extends StatelessWidget {
  const InsightsSkeleton({super.key});

  static const _bars = [
    (12.0, 12.0),
    (23.0, 17.0),
    (34.0, 31.0),
    (44.0, 47.0),
    (55.0, 59.0),
    (66.0, 62.0),
    (77.0, 54.0),
    (88.0, 39.0),
    (98.0, 24.0),
    (109.0, 13.0),
    (120.0, 13.0),
    (131.0, 23.0),
    (142.0, 39.0),
    (152.0, 54.0),
    (163.0, 62.0),
    (174.0, 59.0),
    (185.0, 48.0),
    (196.0, 31.0),
    (206.0, 18.0),
    (217.0, 12.0),
    (228.0, 17.0),
    (239.0, 30.0),
    (250.0, 46.0),
    (260.0, 59.0),
    (271.0, 62.0),
    (282.0, 55.0),
    (293.0, 40.0),
    (304.0, 24.0),
    (314.0, 14.0),
    (325.0, 13.0),
  ];

  static const _kpi = BoneCard(
    height: 102,
    figmaWidth: 171,
    bones: [
      B(14, 16, 80, 24, r: 8),
      B(14, 52, 100, 8, soft: true),
      B(14, 70, 50, 20, soft: true),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      BoneCard(
        height: 210,
        bones: [
          const B(16, 16, 130, 10),
          const B(248, 14, 86, 24, soft: true, anchor: BoneAnchor.right),
          const B(16, 40, 80, 40, r: 10),
          for (final (x, h) in _bars)
            B(x, 188 - h, 6, h, r: 3, soft: true, anchor: BoneAnchor.scale),
        ],
      ),
      for (var row = 0; row < 2; row++) ...[
        _gap(row == 0 ? 12 : 10),
        const Row(
          children: [
            Expanded(child: _kpi),
            SizedBox(width: 8),
            Expanded(child: _kpi),
          ],
        ),
      ],
      _gap(20),
      const BoneCard(
        height: 96,
        bones: [
          B(16, 14, 180, 12),
          B(16, 40, 60, 8, soft: true),
          B(100, 40, 190, 6),
          B(16, 56, 60, 8, soft: true),
          B(100, 56, 190, 6),
          B(16, 72, 60, 8, soft: true),
          B(100, 72, 190, 6),
        ],
      ),
    ],
  );
}

/// 11.6 Template library: section label, members card, template cards.
class TemplatesSkeleton extends StatelessWidget {
  const TemplatesSkeleton({super.key, required this.tint, required this.ink});

  /// Institution tint for the members card (Figma #C9D0EA / #B5BEDE).
  final Color tint;
  final Color ink;

  static const _card = BoneCard(
    height: 92,
    bones: [
      B(14, 12, 52, 68, r: 8, soft: true),
      B(80, 18, 170, 12),
      B(80, 40, 100, 8, soft: true),
      B(80, 58, 90, 22, soft: true),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Bone(110, 24, soft: true),
      _gap(16),
      BoneCard(
        height: 96,
        color: tint,
        bones: [
          B(20, 18, 50, 32, r: 8, color: ink),
          B(20, 60, 200, 10, color: ink),
        ],
      ),
      _gap(16),
      _card,
      _gap(10),
      _card,
      _gap(10),
      _card,
    ],
  );
}

/// 11.7 Consent record: status, answers, signature, audit trail, withdraw.
class ConsentRecordSkeleton extends StatelessWidget {
  const ConsentRecordSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Figma's 150 × 22 name line is the real top-bar title here.
      const Bone(250, 24, soft: true),
      _gap(16),
      BoneCard(
        height: 196,
        bones: [
          for (final y in [18.0, 58.0, 98.0, 138.0]) ...[
            B(16, y, 110, 10),
            B(290, y, 44, 10, soft: true, anchor: BoneAnchor.right),
          ],
        ],
      ),
      _gap(12),
      const BoneCard(
        height: 96,
        bones: [
          B(16, 24, 140, 40, r: 10, soft: true),
          B(200, 24, 60, 10, anchor: BoneAnchor.scale),
          B(200, 42, 120, 10, soft: true, anchor: BoneAnchor.scale),
        ],
      ),
      _gap(12),
      BoneCard(
        height: 140,
        bones: [
          const B(16, 14, 90, 12),
          for (final y in [44.0, 72.0, 100.0]) ...[
            B(18, y + 2, 8, 8, circle: true),
            B(34, y, 40, 10),
            B(84, y, 230, 10, soft: true),
          ],
        ],
      ),
      _gap(28),
      const Bone(double.infinity, 60, color: Color(0xFFF6DADB)),
    ],
  );
}

/// 11.8 Me / settings: profile card and two groups of rows.
class MeSkeleton extends StatelessWidget {
  const MeSkeleton({super.key});

  static List<B> _rows(int n) => [
    for (var i = 0; i < n; i++) ...[
      B(16, 12 + 62.0 * i, 44, 44, r: 14, soft: true),
      B(72, 20 + 62.0 * i, 130, 12),
      B(72, 40 + 62.0 * i, 180, 8, soft: true),
    ],
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const BoneCard(
        height: 96,
        bones: [
          B(16, 18, 60, 60, circle: true),
          B(90, 26, 170, 14),
          B(90, 50, 130, 10, soft: true),
        ],
      ),
      _gap(16),
      BoneCard(height: 260, bones: _rows(4)),
      _gap(16),
      BoneCard(height: 198, bones: _rows(3)),
      _gap(10),
      const Bone(90, 14),
    ],
  );
}
