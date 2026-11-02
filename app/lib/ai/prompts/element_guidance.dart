import '../domain/consent_element.dart';

/// How to find an element in a proposal, and what its section must say.
final class ElementGuidance {
  const ElementGuidance({
    required this.proposalKeywords,
    required this.instruction,
  });

  /// Lower-case English word starts that mark proposal pages about it.
  final List<String> proposalKeywords;

  /// What the consent section must tell the reader.
  final String instruction;
}

/// Guidance for every element. Proposals are searched in English only.
const elementGuidance = <ConsentElement, ElementGuidance>{
  ConsentElement.purpose: ElementGuidance(
    proposalKeywords: ['aim', 'objective', 'purpose', 'rationale', 'question'],
    instruction: 'Say why the study is done.',
  ),
  ConsentElement.procedures: ElementGuidance(
    proposalKeywords: [
      'method',
      'procedure',
      'data collection',
      'interview',
      'questionnaire',
      'survey',
      'focus group',
    ],
    instruction: 'Say what the reader will do, step by step.',
  ),
  ConsentElement.duration: ElementGuidance(
    proposalKeywords: ['duration', 'minute', 'hour', 'week', 'timeline'],
    instruction:
        'Say how long taking part takes, with a number and a unit of time.',
  ),
  ConsentElement.risks: ElementGuidance(
    proposalKeywords: ['risk', 'harm', 'discomfort', 'adverse', 'distress'],
    instruction:
        'Name each risk or discomfort and what the team does about it. '
        'If there is none, say so.',
  ),
  ConsentElement.benefits: ElementGuidance(
    proposalKeywords: ['benefit', 'advantage'],
    instruction:
        'Say what good may come, for the reader or for others. '
        'If there is none for the reader, say so.',
  ),
  ConsentElement.compensation: ElementGuidance(
    proposalKeywords: [
      'compensat',
      'reimburs',
      'incentive',
      'payment',
      'refreshment',
      'transport',
    ],
    instruction:
        'Say what the reader gets for taking part, such as money, transport '
        'or food. If nothing, say so.',
  ),
  ConsentElement.confidentiality: ElementGuidance(
    proposalKeywords: [
      'confidential',
      'anonym',
      'privacy',
      'storage',
      'stored',
      'retain',
      'retention',
      'destroy',
    ],
    instruction:
        'Say who can see the data, how it is protected, and how long it is '
        'kept before it is destroyed.',
  ),
  ConsentElement.voluntaryWithdrawal: ElementGuidance(
    proposalKeywords: ['voluntar', 'withdraw', 'refuse', 'penalty'],
    instruction:
        'Say that taking part is a free choice, and that the reader can say '
        'no or stop at any time without any penalty.',
  ),
  ConsentElement.contactsResearcher: ElementGuidance(
    proposalKeywords: [
      'investigator',
      'researcher',
      'supervisor',
      'contact',
      'email',
      'phone',
    ],
    instruction:
        "Give the researcher's name and how to reach them, and invite the "
        'reader to ask questions at any time.',
  ),
  ConsentElement.contactsEthics: ElementGuidance(
    proposalKeywords: ['ethic', 'review board', 'irb', 'committee'],
    instruction:
        "Give the ethics committee's name and how to reach it, for questions "
        "about the reader's rights.",
  ),
  ConsentElement.guardianPermission: ElementGuidance(
    proposalKeywords: ['parent', 'guardian', 'caregiver', 'permission'],
    instruction:
        'Say that a parent or guardian must give permission before the child '
        'takes part.',
  ),
  ConsentElement.childAssent: ElementGuidance(
    proposalKeywords: ['assent', 'child', 'minor', 'learner'],
    instruction:
        'Ask the child, in words a child understands, if they agree to take '
        'part.',
  ),
  ConsentElement.childDissentRespected: ElementGuidance(
    proposalKeywords: ['assent', 'dissent', 'refuse', 'child'],
    instruction:
        'Say that if the child says no or wants to stop, this is always '
        'respected and nothing bad happens.',
  ),
  ConsentElement.safeguardingContact: ElementGuidance(
    proposalKeywords: [
      'safeguard',
      'child protection',
      'social worker',
      'referral',
      'welfare',
    ],
    instruction:
        'Give a child protection contact the family can reach if the child '
        'is at risk.',
  ),
};
