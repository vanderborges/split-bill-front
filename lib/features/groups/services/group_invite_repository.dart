import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/group_invite_model.dart';
import '../models/group_invite_preview_model.dart';

final groupInviteRepositoryProvider = Provider<GroupInviteRepository>((ref) {
  return GroupInviteRepository(ref.watch(dioProvider));
});

/// Invite id captured from an `/invite/:inviteId` link while the visitor
/// wasn't logged in yet. Consumed by the login page right after a
/// successful sign-in to join the group automatically.
final pendingInviteIdProvider = StateProvider<String?>((ref) => null);

class GroupInviteRepository {
  const GroupInviteRepository(this.dio);

  final Dio dio;

  Future<GroupInviteModel> getOrCreate(String groupId) async {
    final response =
        await dio.post<Map<String, dynamic>>('/groups/$groupId/invite');
    return GroupInviteModel.fromJson(response.data!);
  }

  Future<GroupInviteModel> regenerate(String groupId) async {
    final response = await dio
        .post<Map<String, dynamic>>('/groups/$groupId/invite/regenerate');
    return GroupInviteModel.fromJson(response.data!);
  }

  Future<GroupInvitePreviewModel> preview(String inviteId) async {
    final response =
        await dio.get<Map<String, dynamic>>('/invites/$inviteId');
    return GroupInvitePreviewModel.fromJson(response.data!);
  }

  Future<void> join(String inviteId) async {
    await dio.post<void>('/invites/$inviteId/join');
  }
}
