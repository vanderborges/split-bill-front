import 'package:dio/dio.dart';

/// Extrai uma mensagem de erro apresentável de uma falha de API.
///
/// O backend retorna erros de regra de negócio como `{"message": "..."}`
/// (ver `DomainException` no backend) — esta função usa essa mensagem
/// quando existe, em vez de deixar vazar o dump técnico do `DioException`
/// (`DioException [bad response]: ...`) direto pra tela, o que nunca deve
/// acontecer (ver docs/ux-roadmap-dividiai.md > Fase 12, "nunca mostrar
/// Erro 400 cru").
String friendlyApiError(
  Object error, {
  String fallback = 'Algo deu errado. Tente novamente.',
}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'A conexão demorou demais. Tente novamente.';
      default:
        return fallback;
    }
  }
  return fallback;
}
