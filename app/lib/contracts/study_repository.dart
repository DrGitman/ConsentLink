// contracts/study_repository.dart
import 'models.dart';

abstract class StudyRepository {
  Future<Study> createStudy(StudyDraft draft);
  Future<List<Study>> listStudies();

  /// The working copy, including drafts and edits.
  Future<List<ConsentSection>> getSections(String studyId);

  /// Saving over an approved section sets it to SectionStatus.edited and
  /// clears the approval. The published form does not change until
  /// publishForm() is called again.
  Future<void> saveSection(ConsentSection section);

  /// Marks a section approved by the current researcher.
  /// Implementation must also write an AuditAction.sectionApproved entry.
  Future<void> approveSection(String sectionId);

  /// Locks the approved sections as the next form version.
  /// Fails unless EVERY section is approved. Stores a frozen snapshot,
  /// sets Study.formHash = computeFormHash(...), increases Study.formVersion
  /// and writes an AuditAction.formPublished entry.
  Future<Study> publishForm(String studyId);

  /// The frozen snapshot of the current published version. This is what a
  /// participant is shown, so later edits never change what they agreed to.
  Future<List<ConsentSection>> getPublishedSections(String studyId);
}
