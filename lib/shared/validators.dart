final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Formato mínimo aceito: tem "@", sem espaços e com um domínio com ponto
/// (ex.: nome@dominio.com). Não tenta validar entrega real do email.
bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());
