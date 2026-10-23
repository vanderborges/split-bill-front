import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../firebase_options.dart';
import 'notifications_repository.dart';

/// Push só no celular (Android/iOS); o web continua só com o sininho.
bool get pushSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Rota que um toque na notificação pediu enquanto ninguém estava logado
/// (app aberto do zero): a tela de login vai pra ela depois de entrar.
final pendingPushRouteProvider = StateProvider<String?>((ref) => null);

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Liga o Firebase antes do runApp. Falha aqui nunca impede o app de abrir.
Future<void> initializePush() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (!pushSupported || options == null) {
    return;
  }
  try {
    await Firebase.initializeApp(options: options);
  } catch (error) {
    debugPrint('Push: Firebase não iniciou ($error)');
  }
}

// Usa o token FCM clássico (getToken/onTokenRefresh/deleteToken), marcado
// como deprecated no firebase_messaging 17 em favor do register()/FID
// ("direct-send"). O backend manda com firebase-admin por token, que
// continua funcionando; migrar junto quando o Admin SDK mandar por FID.
// ignore_for_file: deprecated_member_use

class PushService {
  PushService(this.ref);

  final Ref ref;
  bool _listening = false;

  bool get _ready => pushSupported && Firebase.apps.isNotEmpty;

  Dio get _dio => ref.read(dioProvider);

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  /// Chamado com o usuário logado: pede permissão (só pergunta na 1ª vez)
  /// e manda o token deste aparelho pro backend.
  Future<void> registerDevice() async {
    if (!_ready) {
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      // iOS: mostra o banner mesmo com o app aberto.
      await messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) {
        await _sendToken(token);
      }
      _listenOnce();
    } catch (error) {
      debugPrint('Push: não registrou o aparelho ($error)');
    }
  }

  /// No "Sair": o aparelho para de receber push dessa conta. Precisa rodar
  /// ANTES de apagar o token de login (a chamada vai autenticada).
  Future<void> unregisterDevice() async {
    if (!_ready) {
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      // Sem rede o "Sair" não pode travar: desiste em alguns segundos.
      await () async {
        final token = await messaging.getToken();
        if (token != null) {
          await _dio.post<void>('/devices/unregister', data: {'token': token});
        }
        await messaging.deleteToken();
      }()
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Push: não removeu o aparelho ($error)');
    }
  }

  /// Toque numa notificação com o app fechado: guarda a rota pra tela de
  /// login abrir depois de entrar (ela é sempre a primeira tela).
  Future<void> handleInitialMessage() async {
    if (!_ready) {
      return;
    }
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        ref.read(pendingPushRouteProvider.notifier).state = _routeOf(message);
        // Sem await: roda antes do runApp e não pode segurar a abertura.
        _markAsRead(message);
      }
    } catch (error) {
      debugPrint('Push: falha ao ler a notificação inicial ($error)');
    }
  }

  void _listenOnce() {
    if (_listening) {
      return;
    }
    _listening = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _sendToken(token).catchError((_) {});
    });
    // Chegou com o app aberto: atualiza a lista e o contador do sininho.
    FirebaseMessaging.onMessage.listen((_) {
      ref.invalidate(notificationsProvider);
    });
    // Toque na notificação com o app em segundo plano (já logado).
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _markAsRead(message);
      ref.read(appRouterProvider).go(_routeOf(message));
    });
  }

  Future<void> _sendToken(String token) => _dio
      .post<void>('/devices', data: {'token': token, 'platform': _platform});

  Future<void> _markAsRead(RemoteMessage message) async {
    final id = message.data['notificationId'];
    if (id is String && id.isNotEmpty) {
      try {
        await ref.read(notificationsRepositoryProvider).markAsRead(id);
      } catch (_) {
        // Sem login ainda (app aberto do zero) ou já lida: a tela de
        // Notificações mostra do mesmo jeito.
      }
    }
    ref.invalidate(notificationsProvider);
  }

  String _routeOf(RemoteMessage message) {
    final route = message.data['route'];
    return route is String && route.startsWith('/') ? route : '/notifications';
  }
}
