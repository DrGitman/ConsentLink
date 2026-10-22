// data/local/powersync_schema.dart
// PowerSync's list of tables, built from the drift tables in tables.dart so
// there is only one list to keep in step with supabase/migrations.
//
// SQLite has no boolean or timestamp types: booleans are integers (1 / 0) and
// timestamps and JSON are text. PowerSync adds the `id` column itself.
import 'package:drift/drift.dart'
    show DriftSqlType, GeneratedDatabase, TableInfo;
import 'package:powersync_sqlcipher/powersync.dart';

/// Tables that stay on the phone. They are never uploaded or downloaded.
const localOnlyTables = {'upload_failures'};

Schema powerSyncSchemaFor(GeneratedDatabase db) => Schema([
  for (final table in db.allTables)
    if (localOnlyTables.contains(table.actualTableName))
      Table.localOnly(table.actualTableName, _columns(table))
    else
      Table(table.actualTableName, _columns(table)),
]);

List<Column> _columns(TableInfo table) => [
  for (final column in table.$columns)
    if (column.name != 'id') Column(column.name, _typeOf(column.type)),
];

ColumnType _typeOf(Object driftType) => switch (driftType) {
  DriftSqlType.bool ||
  DriftSqlType.int ||
  DriftSqlType.bigInt => ColumnType.integer,
  DriftSqlType.double => ColumnType.real,
  DriftSqlType.string => ColumnType.text,
  _ => throw ArgumentError('No PowerSync column type for $driftType'),
};
