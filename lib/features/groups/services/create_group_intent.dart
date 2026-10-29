import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sinaliza que a tela Grupos deve abrir o "Novo grupo" assim que montar.
final pendingCreateGroupProvider = StateProvider<bool>((ref) => false);

/// Quem ainda não tem nenhum grupo tentou criar evento ou despesa: avisa
/// que precisa de um grupo antes e leva direto pra criação dele.
Future<void> showCreateGroupFirstDialog(
    BuildContext context, WidgetRef ref) async {
  final create = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Crie um grupo primeiro'),
      content: const Text(
          'Para continuar é necessário criar um grupo antes. Os eventos e as despesas ficam dentro de um grupo.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Criar grupo')),
      ],
    ),
  );
  if (create != true || !context.mounted) {
    return;
  }
  ref.read(pendingCreateGroupProvider.notifier).state = true;
  context.go('/groups');
}
