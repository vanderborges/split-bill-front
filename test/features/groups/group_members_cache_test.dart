import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/features/groups/models/group_member_model.dart';
import 'package:split_bill_front/features/groups/models/group_model.dart';
import 'package:split_bill_front/features/groups/services/groups_repository.dart';

class _CountingGroups extends GroupsRepository {
  _CountingGroups() : super(Dio());

  var members = 0;
  var temporaries = 0;

  @override
  Future<List<GroupMemberModel>> listMembers(String groupId,
      {String? viewerUserId,
      String? eventId,
      bool includeRemoved = false}) async {
    members++;
    return const [];
  }

  @override
  Future<List<GroupMemberModel>> listTemporaryMembers(String groupId) async {
    temporaries++;
    return const [];
  }
}

void main() {
  test(
      'integrantes do grupo ficam em memória ao rolar e recarregam quando o '
      'grupo é atualizado', () async {
    final groups = _CountingGroups();
    final container = ProviderContainer(overrides: [
      groupsRepositoryProvider.overrideWithValue(groups),
      groupsProvider.overrideWith((ref) async => <GroupModel>[]),
    ]);
    addTearDown(container.dispose);

    // Como a lista ao rolar: o bloco sai e volta para a tela várias vezes.
    for (var i = 0; i < 3; i++) {
      await container.read(groupMembersProvider('g1').future);
      await container.read(groupTemporaryMembersProvider('g1').future);
    }
    expect(groups.members, 1);
    expect(groups.temporaries, 1);

    // Convidar/remover/alterar alguém faz ref.invalidate(selectedGroupProvider).
    container.invalidate(selectedGroupProvider);
    await container.read(groupMembersProvider('g1').future);
    await container.read(groupTemporaryMembersProvider('g1').future);
    expect(groups.members, 2);
    expect(groups.temporaries, 2);
  });
}
