import 'dart:convert';
import '../../services/backup_import_plan.dart';

/// Deterministic three-way merge. Posted money events are never last-writer-wins.
abstract class CloudSnapshot {
  static Map<String, dynamic> empty() => {
    'schema_version': 3,
    'business_profile': <String, dynamic>{},
    for (final t in BackupImportPlan.columns.keys) t: <Map<String, dynamic>>[],
  };
  static Map<String, dynamic> normalize(Map<String, dynamic> value) => {
    'schema_version': 3,
    'business_profile': {
      for (final k in ['name', 'phone', 'address', 'logo'])
        if ((value['business_profile'] as Map?)?.containsKey(k) == true)
          k: (value['business_profile'] as Map)[k],
    },
    for (final table in BackupImportPlan.columns.keys)
      table:
          (value[table] as List? ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList()
            ..sort(
              (a, b) =>
                  (a[table == 'invoice_terms' ? 'invoice_id' : 'id'] as String)
                      .compareTo(
                        b[table == 'invoice_terms' ? 'invoice_id' : 'id']
                            as String,
                      ),
            ),
  };
  static String canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${canonical(value[k])}').join(',')}}';
    }
    if (value is List) return '[${value.map(canonical).join(',')}]';
    return jsonEncode(value);
  }

  static bool same(dynamic a, dynamic b) => canonical(a) == canonical(b);
  static Map<String, dynamic> merge({
    required Map<String, dynamic> baseline,
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final result = empty();
    for (final table in BackupImportPlan.columns.keys) {
      final pk = table == 'invoice_terms' ? 'invoice_id' : 'id';
      Map<String, Map<String, dynamic>> keyed(Map<String, dynamic> s) => {
        for (final r in s[table] as List? ?? [])
          r[pk] as String: Map<String, dynamic>.from(r as Map),
      };
      final base = keyed(baseline), mine = keyed(local), theirs = keyed(remote);
      final merged = <Map<String, dynamic>>[];
      for (final id in {...base.keys, ...mine.keys, ...theirs.keys}) {
        final b = base[id], l = mine[id], r = theirs[id];
        // Records are archived with tombstones. A physical disappearance is not
        // a valid edit, including when another device still has the record.
        if (b != null && (l == null || r == null)) {
          throw CloudConflict(table, id);
        }
        final Map<String, dynamic>? chosen;
        if (same(l, r)) {
          chosen = l;
        } else if (same(l, b)) {
          chosen = r;
        } else if (same(r, b)) {
          chosen = l;
        } else if (b == null && l == null) {
          chosen = r;
        } else if (b == null && r == null) {
          chosen = l;
        } else {
          throw CloudConflict(table, id);
        }
        if (chosen != null) merged.add(chosen);
      }
      result[table] = merged;
    }
    final profile = <String, dynamic>{};
    final bp = Map<String, dynamic>.from(
          baseline['business_profile'] as Map? ?? {},
        ),
        lp = Map<String, dynamic>.from(local['business_profile'] as Map? ?? {}),
        rp = Map<String, dynamic>.from(
          remote['business_profile'] as Map? ?? {},
        );
    for (final k in {...bp.keys, ...lp.keys, ...rp.keys}) {
      final b = bp[k], l = lp[k], r = rp[k];
      if (same(l, r)) {
        profile[k] = l;
      } else if (same(l, b)) {
        profile[k] = r;
      } else if (same(r, b)) {
        profile[k] = l;
      } else {
        throw CloudConflict('business_profile', k);
      }
    }
    result['business_profile'] = profile;
    final normalized = normalize(result);
    BackupImportPlan.parse(jsonEncode(normalized));
    return normalized;
  }
}

class CloudConflict implements Exception {
  const CloudConflict(this.table, this.id);
  final String table, id;
  @override
  String toString() =>
      'يوجد تعارض بين جهازين في سجل $table. التغييرات المحلية محفوظة؛ راجع السجل قبل المزامنة.';
}
