import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(dioProvider));
});

final groupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return [];
  }
  return ref.watch(groupsRepositoryProvider).list();
});

final groupRoleProvider =
    FutureProvider.family<String?, String>((ref, groupId) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return null;
  }
  final members =
      await ref.watch(groupsRepositoryProvider).listMembers(groupId);
  for (final member in members) {
    if (member.userId == user.id) {
      return member.role;
    }
  }
  return null;
});

final selectedGroupIdProvider = StateProvider<String?>((ref) => null);

final selectedGroupProvider = FutureProvider<GroupModel?>((ref) async {
  final groups = await ref.watch(groupsProvider.future);
  if (groups.isEmpty) {
    return null;
  }
  final selectedId = ref.watch(selectedGroupIdProvider);
  if (selectedId != null) {
    final selected = groups.where((group) => group.id == selectedId);
    if (selected.isNotEmpty) {
      return selected.first;
    }
  }
  return groups.first;
});

class GroupsRepository {
  const GroupsRepository(this.dio);

  final Dio dio;

  Future<List<GroupModel>> list({String? viewerUserId}) async {
    final response = await dio.get<List<dynamic>>(
      '/groups',
      queryParameters: {
        if (viewerUserId != null) 'viewerUserId': viewerUserId,
      },
    );
    return response.data!
        .map((item) => GroupModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GroupModel> create({
    required String name,
    String? description,
    required String adminUserId,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/groups',
      data: {
        'name': name,
        'description': description,
        'adminUserId': adminUserId,
      },
    );
    return GroupModel.fromJson(response.data!);
  }

  Future<List<GroupMemberModel>> listMembers(String groupId,
      {String? viewerUserId}) async {
    final response = await dio.get<List<dynamic>>(
      '/groups/$groupId/members',
      queryParameters: {
        if (viewerUserId != null) 'viewerUserId': viewerUserId,
      },
    );
    return response.data!
        .map((item) => GroupMemberModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GroupMemberModel> addMember({
    required String groupId,
    required String adminUserId,
    required String userId,
    required String role,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/groups/$groupId/members',
      data: {
        'adminUserId': adminUserId,
        'userId': userId,
        'role': role,
      },
    );
    return GroupMemberModel.fromJson(response.data!);
  }

  Future<void> delete(String groupId, String adminUserId) async {
    await dio.delete<void>(
      '/groups/$groupId',
      queryParameters: {'adminUserId': adminUserId},
    );
  }
}
