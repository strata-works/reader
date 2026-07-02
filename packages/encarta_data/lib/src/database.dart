import 'package:drift/drift.dart';

part 'database.g.dart';

/// drift database over the EXISTING, read-only Encarta corpus.
///
/// The corpus is never created or migrated by us, so the migration strategy
/// is a no-op. A read-only-safe open path (interceptor that swallows the
/// `PRAGMA user_version =` write) lives in [EncartaDb.open]; see encarta_db.dart.
@DriftDatabase(include: {'tables.drift', 'queries.drift'})
class EncartaDatabase extends _$EncartaDatabase {
  EncartaDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Never CREATE anything: the schema already exists on disk.
        onCreate: (m) async {},
        onUpgrade: (m, from, to) async {},
      );
}
