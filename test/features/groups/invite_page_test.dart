import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_bill_front/features/auth/services/auth_repository.dart';
import 'package:split_bill_front/features/groups/models/group_invite_preview_model.dart';
import 'package:split_bill_front/features/groups/models/group_member_model.dart';
import 'package:split_bill_front/features/groups/pages/invite_page.dart';
import 'package:split_bill_front/features/groups/services/group_invite_repository.dart';
import 'package:split_bill_front/features/users/models/user_model.dart';

/// Convite falso: devolve dois nomes pré-cadastrados e guarda com qual
/// nome (ou nenhum) a pessoa entrou.
class _FakeInviteRepository extends GroupInviteRepository {
  _FakeInviteRepository() : super(Dio());

  final joins = <String?>[];

  @override
  Future<GroupInvitePreviewModel> preview(String inviteId) async {
    return const GroupInvitePreviewModel(
      id: 'inv',
      groupId: 'g1',
      groupName: 'Viagem',
      active: true,
      placeholders: [
        InvitePlaceholderOption(userId: 'p-carla', nickname: 'Carla'),
        InvitePlaceholderOption(userId: 'p-dani', nickname: 'Dani'),
      ],
    );
  }

  @override
  Future<GroupMemberModel> join(String inviteId,
      {String? placeholderUserId}) async {
    joins.add(placeholderUserId);
    return const GroupMemberModel(
      id: 'm1',
      groupId: 'g1',
      userId: 'u1',
      nickname: 'Eu',
      role: 'MEMBER',
      active: true,
    );
  }
}

const _user = UserModel(
  id: 'u1',
  fullName: 'Eu Mesmo',
  nickname: 'Eu',
  email: 'eu@teste.com',
  phone: '1',
  pixKey: 'pix',
  billingUserId: null,
  admin: false,
  active: true,
);

Future<_FakeInviteRepository> _pumpInvite(WidgetTester tester) async {
  final repository = _FakeInviteRepository();
  final router = GoRouter(
    initialLocation: '/invite/inv',
    routes: [
      GoRoute(
          path: '/invite/:inviteId',
          builder: (context, state) =>
              InvitePage(inviteId: state.pathParameters['inviteId']!)),
      GoRoute(
          path: '/groups',
          builder: (context, state) => const Text('tela de grupos')),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => _user),
      groupInviteRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('mostra os nomes pré-cadastrados em "Quem é você?"',
      (tester) async {
    await _pumpInvite(tester);

    expect(find.text('Quem é você?'), findsOneWidget);
    expect(find.text('Carla'), findsOneWidget);
    expect(find.text('Dani'), findsOneWidget);
    expect(find.text('Não estou na lista'), findsOneWidget);
    expect(find.text('Entrar no grupo'), findsNothing);
  });

  testWidgets('Voltar na confirmação não entra e volta pra lista',
      (tester) async {
    final repository = await _pumpInvite(tester);

    await tester.tap(find.text('Carla'));
    await tester.pumpAndSettle();
    expect(find.text('Você é Carla?'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(repository.joins, isEmpty);
    expect(find.text('Quem é você?'), findsOneWidget);
  });

  testWidgets('confirmar o nome entra vinculado a ele', (tester) async {
    final repository = await _pumpInvite(tester);

    await tester.tap(find.text('Dani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.joins, ['p-dani']);
    expect(find.text('tela de grupos'), findsOneWidget);
  });

  testWidgets('"Não estou na lista" confirma e entra como pessoa nova',
      (tester) async {
    final repository = await _pumpInvite(tester);

    await tester.tap(find.text('Não estou na lista'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar como pessoa nova?'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.joins, [null]);
  });
}
