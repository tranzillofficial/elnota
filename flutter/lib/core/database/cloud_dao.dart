part of 'database_impl.dart';

extension CloudDao on AppDao {
  Future<Map<String, dynamic>?> cloudBaseline() async {
    await _db.customStatement(
      'CREATE TABLE IF NOT EXISTS cloud_baseline (workspace_id TEXT PRIMARY KEY, revision INTEGER NOT NULL, snapshot_json TEXT NOT NULL)',
    );
    final row = await _db
        .customSelect(
          'SELECT revision,snapshot_json FROM cloud_baseline WHERE workspace_id=?',
          variables: [Variable.withString(_wsId)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : {
            'revision': row.read<int>('revision'),
            'data': jsonDecode(row.read<String>('snapshot_json')),
          };
  }

  Future<void> applyCloudSnapshot({
    required Map<String, dynamic> expectedLocal,
    required Map<String, dynamic> merged,
  }) async {
    final plan = BackupImportPlan.parse(jsonEncode(merged));
    await _db.transaction(() async {
      final current = CloudSnapshot.normalize(await exportLocalSnapshot());
      if (!CloudSnapshot.same(
        {...current}..remove('business_profile'),
        {...expectedLocal}..remove('business_profile'),
      )) {
        throw StateError('LOCAL_CHANGED_RETRY');
      }
      for (final table in BackupImportPlan.columns.keys) {
        for (final row in plan.tables[table]!) {
          final pk = table == 'invoice_terms' ? 'invoice_id' : 'id';
          final names = row.keys.toList(),
              values = names.map((n) => row[n]).toList();
          final updates = names
              .where((n) => n != pk)
              .map((n) => '$n=excluded.$n')
              .join(',');
          await _db.customStatement(
            'INSERT INTO $table (${names.join(',')}) VALUES (${List.filled(names.length, '?').join(',')}) ON CONFLICT($pk) DO UPDATE SET $updates',
            values,
          );
        }
      }
    });
    LocalQueryChanges.notify();
  }

  Future<void> saveCloudBaseline(
    Map<String, dynamic> snapshot,
    int revision,
    List<String> acknowledged,
  ) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'INSERT INTO cloud_baseline(workspace_id,revision,snapshot_json) VALUES(?,?,?) ON CONFLICT(workspace_id) DO UPDATE SET revision=excluded.revision,snapshot_json=excluded.snapshot_json',
        [_wsId, revision, jsonEncode(snapshot)],
      );
      await markOutboxAcknowledged(acknowledged);
      await updateSyncState(
        lastCursor: revision.toString(),
        lastSuccessAt: DateTime.now().millisecondsSinceEpoch,
      );
    });
    LocalQueryChanges.notify();
  }
}
