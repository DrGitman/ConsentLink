import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sample responses and insights appear only with INSIGHTS_PREVIEW=true or the
/// existing DASHBOARD_PREVIEW / PROJECTS_PREVIEW flags. The consent record
/// store and sync (P2) aren't connected yet, so nothing is read from or
/// written to a server and exports don't create files.
final insightsPreviewProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('INSIGHTS_PREVIEW') ||
      const bool.fromEnvironment('DASHBOARD_PREVIEW') ||
      const bool.fromEnvironment('PROJECTS_PREVIEW'),
);

enum ResponseStatus {
  agreed('Agreed'),
  declined('Declined'),
  withdrew('Withdrew');

  const ResponseStatus(this.label);
  final String label;
}

enum ResponseFilter {
  all('All'),
  agreed('Agreed'),
  declined('Declined'),
  withdrew('Withdrew');

  const ResponseFilter(this.label);
  final String label;

  bool matches(ConsentResponse r) => switch (this) {
    ResponseFilter.all => true,
    ResponseFilter.agreed => r.status == ResponseStatus.agreed,
    ResponseFilter.declined => r.status == ResponseStatus.declined,
    ResponseFilter.withdrew => r.status == ResponseStatus.withdrew,
  };
}

class AuditEvent {
  const AuditEvent(this.time, this.text);
  final DateTime time;
  final String text;
}

class ConsentResponse {
  const ConsentResponse({
    required this.number,
    required this.name,
    required this.status,
    required this.at,
    required this.synced,
    this.language = 'Otjiherero',
    this.site = 'Opuwo',
    this.readAloud = true,
    this.choices = const {
      'Take part': true,
      'Record voice': true,
      'Quote me': false,
      'Contact again': true,
    },
    this.method = 'signed',
    this.witness,
    this.audit = const [],
    this.withdrawnAt,
  });

  final int number;
  final String name;
  final ResponseStatus status;
  final DateTime at;
  final bool synced;
  final String language;
  final String site;
  final bool readAloud;
  final Map<String, bool> choices;
  final String method;
  final String? witness;
  final List<AuditEvent> audit;
  final DateTime? withdrawnAt;

  String get code => 'P-${number.toString().padLeft(3, '0')}';

  ConsentResponse withdraw(DateTime when) => ConsentResponse(
    number: number,
    name: name,
    status: ResponseStatus.withdrew,
    at: at,
    synced: false,
    language: language,
    site: site,
    readAloud: readAloud,
    choices: choices,
    method: method,
    witness: witness,
    audit: [
      ...audit,
      AuditEvent(when, 'Withdrawal recorded · excluded from analysis'),
    ],
    withdrawnAt: when,
  );
}

/// The date shown in the list: "Today 10:42", "Yesterday", "2 Oct".
String responseWhen(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today ${clock(at)}';
  if (diff == 1) return 'Yesterday';
  return '${at.day} ${shortMonths[at.month - 1]}';
}

String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String longDate(DateTime t) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${t.day} ${months[t.month - 1].substring(0, 3)} ${t.year}, ${clock(t)}';
}

/// Figma 07.1: 69 responses (64 agreed, 3 declined, 2 withdrew). The six
/// newest are the Figma rows; "today" is the day the preview runs.
List<ConsentResponse> sampleResponses(DateTime now) {
  DateTime today(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
  DateTime daysAgo(int d, int h, int m) =>
      DateTime(now.year, now.month, now.day - d, h, m);

  List<AuditEvent> trail(DateTime at, {bool synced = true}) => [
    AuditEvent(
      at.subtract(const Duration(minutes: 11)),
      'Form v2 opened (approved by N. Shikongo)',
    ),
    AuditEvent(at, 'Signed on device · encrypted'),
    if (synced)
      AuditEvent(
        at.add(const Duration(hours: 1, minutes: 16)),
        'Synced to NUST project storage',
      ),
  ];

  final first = [
    ConsentResponse(
      number: 65,
      name: 'Kaera T.',
      status: ResponseStatus.agreed,
      at: today(10, 42),
      synced: false,
      witness: 'J. Kavari (interpreter)',
      audit: trail(today(10, 42)),
    ),
    ConsentResponse(
      number: 64,
      name: 'Anonymous',
      status: ResponseStatus.agreed,
      at: today(9, 15),
      synced: false,
      audit: trail(today(9, 15), synced: false),
    ),
    ConsentResponse(
      number: 63,
      name: 'Uaundja K.',
      status: ResponseStatus.declined,
      at: today(8, 50),
      synced: false,
      choices: const {'Take part': false},
      method: 'signed',
      audit: [
        AuditEvent(today(8, 41), 'Form v2 opened (approved by N. Shikongo)'),
        AuditEvent(today(8, 50), 'Declined on device · encrypted'),
      ],
    ),
    ConsentResponse(
      number: 62,
      name: 'Mbapeua H.',
      status: ResponseStatus.agreed,
      at: daysAgo(1, 14, 5),
      synced: true,
      audit: trail(daysAgo(1, 14, 5)),
    ),
    ConsentResponse(
      number: 61,
      name: 'Anonymous',
      status: ResponseStatus.withdrew,
      at: daysAgo(1, 11, 20),
      synced: true,
      withdrawnAt: daysAgo(1, 16, 2),
      audit: [
        ...trail(daysAgo(1, 11, 20)),
        AuditEvent(
          daysAgo(1, 16, 2),
          'Withdrawal recorded · excluded from analysis',
        ),
      ],
    ),
    ConsentResponse(
      number: 60,
      name: 'Tjipe M.',
      status: ResponseStatus.agreed,
      at: daysAgo(2, 15, 30),
      synced: true,
      audit: trail(daysAgo(2, 15, 30)),
    ),
  ];

  const names = [
    'Anonymous',
    'Kavezeri U.',
    'Tjiposa R.',
    'Muharukua N.',
    'Anonymous',
    'Hengari T.',
    'Kazondu V.',
    'Tjikuua M.',
  ];
  // 63 older responses: 60 agreed, 2 declined, 1 withdrew.
  final rest = <ConsentResponse>[];
  for (var i = 0; i < 63; i++) {
    final number = 59 - i;
    final status = switch (i) {
      12 || 40 => ResponseStatus.declined,
      27 => ResponseStatus.withdrew,
      _ => ResponseStatus.agreed,
    };
    final at = daysAgo(3 + i ~/ 2, 9 + i % 7, (i * 13) % 60);
    rest.add(
      ConsentResponse(
        // Numbers below 1 continue as the pilot (P-0xx shown as is).
        number: number > 0 ? number : 100 - number,
        name: names[i % names.length],
        status: status,
        at: at,
        synced: true,
        language: i % 9 == 0 ? 'English' : 'Otjiherero',
        choices: status == ResponseStatus.declined
            ? const {'Take part': false}
            : const {
                'Take part': true,
                'Record voice': true,
                'Quote me': true,
                'Contact again': false,
              },
        audit: trail(at),
        withdrawnAt: status == ResponseStatus.withdrew
            ? at.add(const Duration(days: 2))
            : null,
      ),
    );
  }
  return [...first, ...rest];
}

class ResponsesController extends StateNotifier<List<ConsentResponse>> {
  ResponsesController(super.state);

  void withdraw(String code, DateTime when) =>
      state = [for (final r in state) r.code == code ? r.withdraw(when) : r];
}

final responsesProvider =
    StateNotifierProvider<ResponsesController, List<ConsentResponse>>(
      (ref) => ResponsesController(
        ref.watch(insightsPreviewProvider)
            ? sampleResponses(DateTime.now())
            : const [],
      ),
    );

final responseFilterProvider = StateProvider<ResponseFilter>(
  (ref) => ResponseFilter.all,
);

final responseSearchProvider = StateProvider<String>((ref) => '');

enum ResponseSort { newest, oldest }

final responseSortProvider = StateProvider<ResponseSort>(
  (ref) => ResponseSort.newest,
);

final unsyncedOnlyProvider = StateProvider<bool>((ref) => false);

/// Figma 07.3 periods.
enum InsightsPeriod {
  week('7 days'),
  month('30 days'),
  all('All time');

  const InsightsPeriod(this.label);
  final String label;
}

final insightsPeriodProvider = StateProvider<InsightsPeriod>(
  (ref) => InsightsPeriod.month,
);

class Kpi {
  const Kpi(this.value, this.label, this.change, {this.warning = false});
  final String value;
  final String label;
  final String change;
  final bool warning;
}

class InsightsData {
  const InsightsData({
    required this.consented,
    required this.goal,
    required this.bars,
    required this.from,
    required this.to,
    required this.kpis,
    required this.languages,
  });
  final int consented;
  final int goal;

  /// Relative daily counts, 0–1.
  final List<double> bars;
  final String from;
  final String to;
  final List<Kpi> kpis;
  final List<(String, double)> languages;

  bool get onTrack => consented / goal >= .6;
}

/// Figma bar heights for 30 days (20 → 72 → 28 of 72).
const _monthBars = [
  20, 21, 23, 26, 29, 34, 39, 44, 50, 55, 60, 64, 67, 70, 72, 72, //
  71, 70, 67, 64, 60, 55, 50, 45, 41, 37, 33, 31, 29, 28, 28,
];

InsightsData insightsFor(InsightsPeriod period) => switch (period) {
  InsightsPeriod.week => const InsightsData(
    consented: 64,
    goal: 80,
    bars: [.55, .72, .4, .9, 1, .62, .48],
    from: 'Sep 28',
    to: 'Oct 4',
    kpis: [
      Kpi('97%', 'agreed', '+1%'),
      Kpi('5.8 min', 'avg. time', '-0.4'),
      Kpi('28%', 'asked a question', '+3%', warning: true),
      Kpi('4.5', 'feedback (of 5)', '+0.1'),
    ],
    languages: [('Otjiherero', .93), ('English', .96), ('Afrikaans', .83)],
  ),
  InsightsPeriod.month => InsightsData(
    consented: 64,
    goal: 80,
    bars: [for (final b in _monthBars) b / 72],
    from: 'Sep 4',
    to: 'Oct 4',
    kpis: const [
      Kpi('96%', 'agreed', '+2%'),
      Kpi('6.2 min', 'avg. time', '-1.1'),
      Kpi('31%', 'asked a question', '+8%', warning: true),
      Kpi('4.4', 'feedback (of 5)', '+0.3'),
    ],
    languages: const [
      ('Otjiherero', .92),
      ('English', .95),
      ('Afrikaans', .81),
    ],
  ),
  InsightsPeriod.all => const InsightsData(
    consented: 64,
    goal: 80,
    bars: [.3, .45, .6, .8, 1, .85, .7, .55, .5, .42, .38, .36],
    from: 'Jul',
    to: 'Oct',
    kpis: [
      Kpi('93%', 'agreed', '+5%'),
      Kpi('6.9 min', 'avg. time', '-2.0'),
      Kpi('34%', 'asked a question', '+11%', warning: true),
      Kpi('4.2', 'feedback (of 5)', '+0.6'),
    ],
    languages: [('Otjiherero', .90), ('English', .94), ('Afrikaans', .79)],
  ),
};

enum ExportFormat {
  pdf('PDF', 'Signed forms', 'responses/file', 'PDFs (.zip)'),
  word('Word', 'Editable .docx', 'responses/file', 'Word files (.zip)'),
  csv('CSV', 'For SPSS / R', 'responses/grid', 'rows (.csv)');

  const ExportFormat(this.label, this.subtitle, this.icon, this.unit);
  final String label;
  final String subtitle;
  final String icon;
  final String unit;
}

class ExportLog {
  const ExportLog(this.at, this.format, this.count);
  final DateTime at;
  final ExportFormat format;
  final int count;
}

/// "Exports are logged in the audit trail."
final exportLogProvider = StateProvider<List<ExportLog>>((ref) => const []);
