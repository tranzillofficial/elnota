import '../../../core/services/supabase_service.dart';
import '../services/auth_service.dart';

/// Requests are pending only. Payment approval remains in the server admin RPC.
class ActivationRepository {
  Future<Map<String, dynamic>?> latest() async {
    final client = SupabaseService.to.client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return null;
    return await client
        .from('elnota_requests')
        .select('id,status,created_at')
        .eq('user_id', uid)
        .eq('plan', 'basic')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<void> submit({
    required String phone,
    required String reference,
  }) async {
    final client = SupabaseService.to.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) throw StateError('تسجيل الدخول مطلوب');
    if (phone.trim().length < 7 ||
        phone.trim().length > 30 ||
        reference.trim().length < 3 ||
        reference.trim().length > 500) {
      throw ArgumentError('راجع رقم الهاتف ومرجع الدفع');
    }
    if ((await latest())?['status'] == 'pending') return;
    await client.rpc(
      'elnota_register',
      params: {
        'business':
            AuthService.to.currentSession.value?.workspaceName ?? 'النوتة',
      },
    );
    await client.from('elnota_requests').insert({
      'user_id': user.id,
      'plan': 'basic',
      'phone': phone.trim(),
      'reference': reference.trim(),
      'status': 'pending',
      'submitted_email': user.email,
      'submitted_business_name':
          AuthService.to.currentSession.value?.workspaceName,
    });
  }
}
