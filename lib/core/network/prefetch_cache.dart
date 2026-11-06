import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Respostas que já vieram dentro de uma chamada maior (ex.: o Extrato
/// inteiro em `GET /statement`). O provider de cada evento usa a resposta
/// guardada uma vez, em vez de fazer a própria chamada ao servidor.
///
/// Uso único e com validade curta: depois de lida (ou velha), a próxima
/// leitura do provider já busca do servidor, então nada fica desatualizado.
class PrefetchCache {
  PrefetchCache({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxAge = Duration(seconds: 30);

  final DateTime Function() _clock;
  final _entries = <String, (DateTime, Object?)>{};

  void put(String key, Object? value) => _entries[key] = (_clock(), value);

  /// `found` false = não tem (ou estava velho): buscar do servidor.
  ({bool found, T? value}) take<T>(String key) {
    final entry = _entries.remove(key);
    if (entry == null || _clock().difference(entry.$1) > maxAge) {
      return (found: false, value: null);
    }
    return (found: true, value: entry.$2 as T?);
  }
}

final prefetchCacheProvider = Provider<PrefetchCache>((ref) => PrefetchCache());

// Chaves do Extrato (`statementPrefetchProvider`).
String statementReportKey(String eventId) => 'report:$eventId';
String statementSettlementsKey(String eventId) => 'settlements:$eventId';
String statementRoleKey(String groupId) => 'role:$groupId';
