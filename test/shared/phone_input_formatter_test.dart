import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/phone_input_formatter.dart';

void main() {
  test('formata celular e fixo enquanto digita', () {
    expect(PhoneInputFormatter.format('1'), '(1');
    expect(PhoneInputFormatter.format('11'), '(11');
    expect(PhoneInputFormatter.format('119'), '(11) 9');
    expect(PhoneInputFormatter.format('1134567890'), '(11) 3456-7890');
    expect(PhoneInputFormatter.format('11987654321'), '(11) 98765-4321');
    expect(PhoneInputFormatter.format('119876543210000'), '(11) 98765-4321');
    expect(PhoneInputFormatter.format('abc'), '');
  });

  test('apagar o traço apaga o dígito antes dele', () {
    const formatter = PhoneInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '(11) 3456-7'),
      const TextEditingValue(text: '(11) 34567'),
    );
    expect(result.text, '(11) 3456');
  });
}
