import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/environment.dart';

/// Política de privacidade publicada no site (web/privacy.html).
final privacyPolicyUrl = Uri.parse('${Environment.webBaseUrl}/privacy.html');

/// Link para a política de privacidade. A App Store e o Google Play exigem
/// que ela esteja acessível dentro do app (Cadastro e Perfil).
class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key, this.prefix});

  /// Texto antes do link (ex.: "Ao se cadastrar, você concorda com a").
  final String? prefix;

  Future<void> _open(BuildContext context) async {
    final opened =
        await launchUrl(privacyPolicyUrl, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Abra $privacyPolicyUrl para ver a política.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = TextButton(
      onPressed: () => _open(context),
      child: const Text('Política de privacidade'),
    );
    if (prefix == null) {
      return Center(child: link);
    }
    return Column(
      children: [
        Text(prefix!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        link,
      ],
    );
  }
}
