/// A required element of an informed consent form (Figma G).
///
/// [jsonKey] is the `element_key` used in `/schemas`.
enum ConsentElement {
  purpose('purpose'),
  procedures('procedures'),
  duration('duration'),
  risks('risks'),
  benefits('benefits'),
  compensation('compensation'),
  // Also covers how long the data is kept (team decision, 12 Oct).
  confidentiality('confidentiality'),
  voluntaryWithdrawal('voluntary_withdrawal'),
  contactsResearcher('contacts_researcher'),
  contactsEthics('contacts_ethics'),
  guardianPermission('guardian_permission'),
  childAssent('child_assent'),
  childDissentRespected('child_dissent_respected'),
  safeguardingContact('safeguarding_contact');

  const ConsentElement(this.jsonKey);

  final String jsonKey;
}

/// The kind of study, which decides the required elements.
enum StudyProfile {
  standard,
  minors;

  factory StudyProfile.fromInvolvesMinors(bool involvesMinors) =>
      involvesMinors ? minors : standard;
}

const _standardElements = [
  ConsentElement.purpose,
  ConsentElement.procedures,
  ConsentElement.duration,
  ConsentElement.risks,
  ConsentElement.benefits,
  ConsentElement.compensation,
  ConsentElement.confidentiality,
  ConsentElement.voluntaryWithdrawal,
  ConsentElement.contactsResearcher,
  ConsentElement.contactsEthics,
];

const _minorsExtraElements = [
  ConsentElement.guardianPermission,
  ConsentElement.childAssent,
  ConsentElement.childDissentRespected,
  ConsentElement.safeguardingContact,
];

/// Returns the elements a consent form must contain for [profile].
List<ConsentElement> requiredElementsFor(StudyProfile profile) =>
    switch (profile) {
      StudyProfile.standard => _standardElements,
      StudyProfile.minors => const [
        ..._standardElements,
        ..._minorsExtraElements,
      ],
    };
