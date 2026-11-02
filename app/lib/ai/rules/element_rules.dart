import '../domain/consent_element.dart';

/// One content check: the section must match [pattern], else [fixHint].
final class ContentCheck {
  /// [source] is matched case-insensitively, in Unicode mode.
  ContentCheck(String source, this.fixHint)
    : pattern = RegExp(source, caseSensitive: false, unicode: true);

  final RegExp pattern;

  /// What the researcher should add when the check fails.
  final String fixHint;
}

const _contactMeans =
    r'@|\+?\d[\d\s-]{5,}\d|\b(phone|call|email|e-mail|whatsapp|sms)\b';
const _anyDuration = r'\b(minute|hour|day|week|month|year)s?\b';
const _retentionDuration = r'\b(month|year)s?\b';
const _canStop = r"\b(stop|withdraw|quit|leave|say no|refuse)\b";
const _noPenalty =
    r"\b(no penalty|without (any )?penalty|nothing bad|no (loss|consequence)s?|"
    r"(will not|won['’]t|does not|doesn['’]t) (affect|change|harm)\w*)\b";
const _ethicsCommittee = r'\b(ethics|review board|irb)\b';
const _guardian = r'\b(parent|guardian|caregiver)s?\b';
const _permission = r'\b(permission|consent|agree)\w*';
const _childYes = r"\b(assent|agree|say yes|want to)\b";
const _childNo = r"\b(say no|says no|refuse|stop|(do not|don['’]t) want)\b";
const _noIsRespected =
    r'\b(respect\w*|always|okay|ok|fine|not be (angry|upset|in trouble))\b';
const _safeguarding =
    r'\b(safeguard\w*|child protection|social worker|helpline|childline)\b';

/// Content checks per element, for English text only (decision D3.3).
///
/// An element without checks is ok as soon as its section exists.
final elementChecks = <ConsentElement, List<ContentCheck>>{
  ConsentElement.duration: [
    ContentCheck(_anyDuration, 'Say how long taking part takes.'),
  ],
  // Retention lives in confidentiality (team decision, 12 Oct).
  ConsentElement.confidentiality: [
    ContentCheck(_retentionDuration, 'Say how long the answers are kept.'),
  ],
  ConsentElement.voluntaryWithdrawal: [
    ContentCheck(_canStop, 'Say the person can say no or stop at any time.'),
    ContentCheck(_noPenalty, 'Say that saying no or stopping has no penalty.'),
  ],
  ConsentElement.contactsResearcher: [
    ContentCheck(_contactMeans, "Give the researcher's phone or email."),
  ],
  ConsentElement.contactsEthics: [
    ContentCheck(_ethicsCommittee, 'Name the ethics committee.'),
    ContentCheck(_contactMeans, "Give the ethics committee's phone or email."),
  ],
  ConsentElement.guardianPermission: [
    ContentCheck(_guardian, 'Address the parent or guardian.'),
    ContentCheck(_permission, 'Ask the parent or guardian for permission.'),
  ],
  ConsentElement.childAssent: [
    ContentCheck(_childYes, 'Ask the child if they want to take part.'),
  ],
  ConsentElement.childDissentRespected: [
    ContentCheck(_childNo, 'Tell the child they can say no or stop.'),
    ContentCheck(_noIsRespected, "Say the child's no is always respected."),
  ],
  ConsentElement.safeguardingContact: [
    ContentCheck(_safeguarding, 'Name a child protection contact.'),
    ContentCheck(_contactMeans, "Give the child protection contact's phone."),
  ],
};
