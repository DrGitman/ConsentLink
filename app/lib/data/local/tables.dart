// data/local/tables.dart
// The tables kept on the phone, mirroring supabase/migrations (same names,
// snake_case columns). powersync_schema.dart builds PowerSync's schema from these.
// PowerSync creates these tables; drift only reads and writes them.
//
// Required columns match NOT NULL in supabase/migrations. Columns the server
// fills in (institution_id, researcher_id, actor_id, published_by, received_at,
// created_at) are optional here: a row made offline has no value until it syncs.
import 'package:drift/drift.dart';

mixin _Id on Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Institutions extends Table with _Id {
  TextColumn get name => text()();
  TextColumn get colourHex => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get templateUrl => text().nullable()();
  TextColumn get createdAt => text().nullable()();
}

class Profiles extends Table with _Id {
  TextColumn get institutionId => text()();
  TextColumn get name => text().nullable()();
  TextColumn get email => text()();
  TextColumn get role => text()();
  TextColumn get createdAt => text().nullable()();
}

class Studies extends Table with _Id {
  TextColumn get institutionId => text().nullable()();
  TextColumn get researcherId => text().nullable()();
  TextColumn get title => text()();
  BoolColumn get involvesMinors => boolean()();
  TextColumn get status => text()();
  IntColumn get formVersion => integer().withDefault(const Constant(0))();
  TextColumn get formHash => text().nullable()();
  TextColumn get createdAt => text().nullable()();
}

class ConsentSections extends Table with _Id {
  TextColumn get studyId => text()();
  TextColumn get institutionId => text().nullable()();
  IntColumn get order => integer()();
  TextColumn get language => text()();
  // `text` would hide drift's text() builder, so the Dart name differs.
  TextColumn get body => text().named('text')();
  IntColumn get sourcePage => integer().nullable()();
  TextColumn get sourceQuote => text().nullable()();
  TextColumn get changes => text().withDefault(const Constant('[]'))();
  TextColumn get confidence => text().nullable()();
  TextColumn get requiredElement => text().nullable()();
  TextColumn get status => text()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get approvedAt => text().nullable()();
  TextColumn get createdAt => text().nullable()();
}

class FormVersions extends Table with _Id {
  TextColumn get studyId => text()();
  TextColumn get institutionId => text().nullable()();
  IntColumn get version => integer()();
  TextColumn get formHash => text()();
  TextColumn get sections => text()();
  TextColumn get publishedBy => text().nullable()();
  TextColumn get publishedAt => text().nullable()();
}

class Participants extends Table with _Id {
  TextColumn get studyId => text()();
  TextColumn get institutionId => text().nullable()();
  TextColumn get language => text()();
  BoolColumn get isMinor => boolean()();
  TextColumn get createdAt => text().nullable()();
}

class Consents extends Table with _Id {
  TextColumn get studyId => text()();
  TextColumn get institutionId => text().nullable()();
  TextColumn get participantId => text()();
  TextColumn get language => text()();
  TextColumn get decision => text()();
  TextColumn get method => text()();
  TextColumn get witnessName => text().nullable()();
  TextColumn get interpreterName => text().nullable()();
  BoolColumn get guardianConsent => boolean().nullable()();
  BoolColumn get childAssent => boolean().nullable()();
  IntColumn get formVersion => integer()();
  TextColumn get formHash => text()();
  TextColumn get signedAt => text()();
  TextColumn get receivedAt => text().nullable()();
  TextColumn get withdrawnAt => text().nullable()();
  TextColumn get withdrawalReason => text().nullable()();
}

class ConsentFiles extends Table with _Id {
  TextColumn get consentId => text()();
  TextColumn get studyId => text()();
  TextColumn get institutionId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get storagePath => text()();
  TextColumn get sha256 => text()();
  TextColumn get createdAt => text().nullable()();
}

@DataClassName('AuditEntry')
class AuditLog extends Table with _Id {
  TextColumn get institutionId => text().nullable()();
  TextColumn get studyId => text()();
  TextColumn get actorId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get entityId => text()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get receivedAt => text().nullable()();
}

/// Phone-only (never synced). A change the server refused for good, kept with
/// its full data and the server's reason so nothing recorded in the field is
/// lost. See data/sync/supabase_connector.dart.
class UploadFailures extends Table with _Id {
  TextColumn get sourceTable => text()();
  TextColumn get rowId => text()();
  TextColumn get op => text()(); // PUT, PATCH or DELETE
  TextColumn get data => text().nullable()(); // JSON, as it was sent
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text()();
  TextColumn get failedAt => text()();
}
