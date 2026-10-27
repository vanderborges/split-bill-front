import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Abertura do app: toca o vídeo do DividiAí (sem som — no navegador vídeo
/// com som não toca sozinho) e chama [onFinished] uma vez quando ele
/// termina, quando a pessoa toca na tela para pular, ou se o vídeo não
/// carregar. Substitui o antigo "DividiAí + carregando".
class SplashVideo extends StatefulWidget {
  const SplashVideo({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashVideo> createState() => _SplashVideoState();
}

class _SplashVideoState extends State<SplashVideo> {
  late final VideoPlayerController _controller =
      VideoPlayerController.asset('assets/videos/dividiai.mp4');

  /// Quanto o vídeo é "achatado" na horizontal no celular em pé (0.75 = 25%
  /// mais estreito em relação à altura): mostra mais da imagem com pouca
  /// distorção.
  static const _stretch = 0.75;

  bool _ready = false;
  bool _finished = false;
  Timer? _safety;

  @override
  void initState() {
    super.initState();
    // Se o vídeo travar por qualquer motivo, não prende a pessoa aqui.
    _safety = Timer(const Duration(seconds: 15), _finish);
    _controller.addListener(_onTick);
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      if (!mounted) {
        return;
      }
      setState(() => _ready = true);
      await _controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _onTick() {
    final value = _controller.value;
    if (value.hasError) {
      _finish();
      return;
    }
    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _safety?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _safety?.cancel();
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: _ready
            ? LayoutBuilder(builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final screenHeight = constraints.maxHeight;
                // Ocupa a tela toda (pedido do usuário). O vídeo é
                // horizontal: em tela mais estreita que ele (celular em pé)
                // é esticado na vertical [_stretch], o que corta menos das
                // laterais; o que sobra é cortado igualmente dos dois lados.
                final videoRatio = _controller.value.aspectRatio;
                final screenRatio = screenWidth / screenHeight;
                final shownRatio = screenRatio < videoRatio
                    ? videoRatio * _stretch
                    : videoRatio;
                final width = screenRatio < shownRatio
                    ? screenHeight * shownRatio
                    : screenWidth;
                final height = screenRatio < shownRatio
                    ? screenHeight
                    : screenWidth / shownRatio;
                return ClipRect(
                  child: OverflowBox(
                    minWidth: width,
                    maxWidth: width,
                    minHeight: height,
                    maxHeight: height,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                );
              })
            : const SizedBox.shrink(),
      ),
    );
  }
}
