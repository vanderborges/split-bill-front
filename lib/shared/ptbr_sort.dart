const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

String _normalizeForSort(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}

/// Compara dois nomes em português ignorando acentos e caixa, para que
/// `"Águeda"` fique perto de `"Alberto"` e não depois de `"Zeca"` (que é
/// o que uma comparação direta de `String` faria, já que os pontos de
/// código de letras acentuadas ficam depois do `z` em UTF-16).
int compareNamesPtBr(String a, String b) {
  return _normalizeForSort(a).compareTo(_normalizeForSort(b));
}

/// Retorna uma cópia de [items] ordenada alfabeticamente (pt-BR) pela
/// string extraída por [nameOf].
List<T> sortedByNamePtBr<T>(Iterable<T> items, String Function(T) nameOf) {
  final list = items.toList();
  list.sort((a, b) => compareNamesPtBr(nameOf(a), nameOf(b)));
  return list;
}
