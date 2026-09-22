import 'package:flutter/material.dart';

/// Avatar com iniciais do Design System do DividiAí. A cor é derivada de
/// [seed] (tipicamente o id do usuário) para ficar consistente entre telas
/// — o mesmo participante sempre aparece com a mesma cor.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.seed,
    this.radius = 18,
  });

  final String name;

  /// Chave usada para escolher a cor. Se omitida, usa [name].
  final String? seed;
  final double radius;

  static const _palette = [
    Color(0xFF3B5BFA),
    Color(0xFF0F9E8E),
    Color(0xFFD97706),
    Color(0xFF9333EA),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    final key = seed ?? name;
    final color = _palette[key.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Extrai até duas iniciais de um nome/apelido, ex.: `"Maria Silva"` -> `MS`,
/// `"João"` -> `J`. Retorna `?` para uma string vazia.
String initialsFor(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
