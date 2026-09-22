import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/api_error.dart';

void main() {
  final requestOptions = RequestOptions(path: '/events');

  group('friendlyApiError', () {
    test('uses the backend DomainException message when present', () {
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          data: {'message': 'Only group admins can perform this action'},
        ),
        type: DioExceptionType.badResponse,
      );
      expect(
        friendlyApiError(error),
        'Only group admins can perform this action',
      );
    });

    test('gives a friendly message for connection errors', () {
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );
      expect(
        friendlyApiError(error),
        'Sem conexão. Verifique sua internet e tente novamente.',
      );
    });

    test('falls back to the default message when there is no body', () {
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
      );
      expect(friendlyApiError(error), 'Algo deu errado. Tente novamente.');
    });

    test('accepts a custom fallback', () {
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
      );
      expect(
        friendlyApiError(error, fallback: 'Não foi possível salvar.'),
        'Não foi possível salvar.',
      );
    });

    test('non-Dio errors use the fallback', () {
      expect(
        friendlyApiError(Exception('boom')),
        'Algo deu errado. Tente novamente.',
      );
    });
  });
}
