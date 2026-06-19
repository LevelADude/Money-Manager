import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/transaction_comment.dart';

/// Zugriff auf `transaction_comments` (Kommentar-Thread je Buchung).
class CommentRepository {
  CommentRepository(this._client);

  final SupabaseClient _client;

  Stream<List<TransactionComment>> watchForTransaction(String transactionId) {
    return _client
        .from('transaction_comments')
        .stream(primaryKey: ['id'])
        .eq('transaction_id', transactionId)
        .order('created_at')
        .map((rows) =>
            dedupRowsById(rows).map(TransactionComment.fromJson).toList());
  }

  Future<void> add(String transactionId, String body) {
    return _client.from('transaction_comments').insert({
      'transaction_id': transactionId,
      'body': body,
    });
  }

  Future<void> delete(String id) {
    return _client.from('transaction_comments').delete().eq('id', id);
  }
}
