enum LegalDocument { terms, privacy }

typedef LegalSection = ({String title, String body});

extension LegalDocumentContent on LegalDocument {
  String get title => switch (this) {
    LegalDocument.terms => 'Terms of use',
    LegalDocument.privacy => 'Privacy Notice',
  };

  String get summary => switch (this) {
    LegalDocument.terms =>
      'Use ConsentLink responsibly. Keep people informed, '
          'protect their information and respect their choices.',
    LegalDocument.privacy =>
      'Understand what this prototype keeps, why it keeps it '
          'and what choices you have.',
  };

  String get route => switch (this) {
    LegalDocument.terms => '/terms',
    LegalDocument.privacy => '/privacy',
  };

  String get version => 'Prototype version 1 · 8 October 2026';

  List<LegalSection> get sections => switch (this) {
    LegalDocument.terms => const [
      (
        title: '1. About ConsentLink',
        body:
            'ConsentLink is a student research project developed for '
            'HCA820S at the Namibia University of Science and Technology. '
            'It is being built to help researchers prepare clear information '
            'and record informed consent.\n\n'
            'This version is a prototype. Some screens are previews and '
            'some services are not connected. Use test information only.',
      ),
      (
        title: '2. Your responsibilities',
        body:
            'Use the app only for work you are authorised to carry out. '
            'Do not enter real participant information into this prototype, '
            'share someone else’s private information, impersonate another '
            'person or try to bypass access controls.\n\n'
            'Keep your device secure and use a test password that you do '
            'not use for another account.',
      ),
      (
        title: '3. Consent remains a human choice',
        body:
            'Using the app or accepting these Terms does not mean someone '
            'has agreed to join a study. Each study needs its own clear '
            'information and consent process.\n\n'
            'Researchers must explain participation, answer questions and '
            'respect refusal or withdrawal. Follow the study’s approved '
            'requirements for children, guardians and other people who '
            'need additional support.',
      ),
      (
        title: '4. Review every research document',
        body:
            'Researchers remain responsible for their study materials and '
            'any required ethics or institutional approval. When AI drafting '
            'or translation becomes available, its output must be checked '
            'by a qualified person before use.\n\n'
            'ConsentLink does not replace professional judgement, ethics '
            'approval or a conversation with the participant.',
      ),
      (
        title: '5. Availability and changes',
        body:
            'The prototype may contain errors, change between versions '
            'or lose test information. Do not rely on it as the only record '
            'of important work.\n\n'
            'You may stop using it at any time. Read the Privacy Notice '
            'for information about locally saved settings. These Terms '
            'will be updated as the service changes.',
      ),
      (
        title: '6. Questions or problems',
        body:
            'For help with ConsentLink, email support@consentlink.com. '
            'Describe the problem without including passwords or '
            'identifiable participant information.',
      ),
    ],
    LegalDocument.privacy => const [
      (
        title: '1. Who this notice covers',
        body:
            'This notice explains the current ConsentLink prototype '
            'developed by the HCA820S project team at NUST. It covers your '
            'use of this app, not a separate institution’s research study.\n\n'
            'A study must provide its own participant information, '
            'privacy details and contact person.',
      ),
      (
        title: '2. Information kept on your device',
        body:
            'The app saves your selected language, text size, contrast '
            'and accessibility preferences so they remain available '
            'when you reopen it.\n\n'
            'The login and sign-up previews hold what you type while '
            'their screens are open. Account creation is not connected, '
            'and these forms do not currently send your details to an '
            'authentication service or save an account.',
      ),
      (
        title: '3. Why information is used',
        body:
            'Saved preferences personalise the display. Information '
            'typed into the account previews is used to demonstrate '
            'form behaviour and check for missing or incorrectly '
            'formatted entries.\n\n'
            'Use fictional names, test email addresses and test passwords. '
            'Do not enter participant records into this prototype.',
      ),
      (
        title: '4. Sharing and future services',
        body:
            'The current account previews do not upload their form '
            'contents. Your keyboard, password manager and device backup '
            'services may handle information according to their own '
            'settings and privacy notices.\n\n'
            'Before account services, institution sharing or research '
            'storage are enabled, this notice needs to explain the '
            'providers involved, information shared, storage location '
            'and retention arrangements.',
      ),
      (
        title: '5. Storage and your choices',
        body:
            'Preferences stay on the device until changed or removed. '
            'You can change them using the app’s available controls. '
            'Android’s Clear storage option removes the app’s local '
            'data, including those settings. Device backups may keep '
            'separate copies under your backup settings.\n\n'
            'You can edit or clear information in the account fields '
            'before submitting. There is currently no online account '
            'to delete.',
      ),
      (
        title: '6. Permissions and protection',
        body:
            'Selecting a voice preference does not itself start recording. '
            'The fingerprint button is currently a preview and does not '
            'collect a fingerprint.\n\n'
            'Keep your phone locked and avoid sharing screenshots that '
            'contain personal information. This prototype is not ready '
            'to safeguard real participant records.',
      ),
      (
        title: '7. Questions and updates',
        body:
            'For privacy questions or concerns about your information, '
            'email support@consentlink.com. Do not include passwords '
            'or participant information in your message.\n\n'
            'This notice will be updated when information handling changes. '
            'The version date above identifies the notice you are reading.',
      ),
    ],
  };
}
