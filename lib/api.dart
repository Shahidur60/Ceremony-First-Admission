import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class Api {
  final String base;
  Api(this.base);

  // -------- USERS --------
  Future<List<UserProfile>> listUsers() async {
    final res = await http.get(Uri.parse('$base/api/users'));
    if (res.statusCode != 200) throw Exception('listUsers failed');
    final L = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return L.map((e) => UserProfile.fromJson(e)).toList();
  }

  /// Convenience for LoginScreen: try to find by (name, phone)
  Future<UserProfile?> findUser(String name, String phone) async {
    final all = await listUsers();
    try {
      return all.firstWhere(
        (u) => u.displayName == name && u.phone == phone,
      );
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> createUser(String name, String phone) async {
    final res = await http.post(
      Uri.parse('$base/api/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'displayName': name, 'phone': phone}),
    );
    if (res.statusCode != 200) throw Exception('createUser failed');
    final data = jsonDecode(res.body);
    return UserProfile.fromJson(data);
  }

  // -------- CONTACTS --------
  Future<List<ContactEntry>> listContacts(String ownerId) async {
    final res = await http.get(Uri.parse('$base/api/contacts/$ownerId'));
    if (res.statusCode != 200) throw Exception('listContacts failed');
    final L = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return L.map((e) => ContactEntry.fromJson(e)).toList();
  }

  Future<List<ContactEntry>> listVerifiedOnly(String ownerId) async {
    final res = await http.get(Uri.parse('$base/api/contacts/$ownerId/verified'));
    if (res.statusCode != 200) throw Exception('listVerifiedOnly failed');
    final L = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return L.map((e) => ContactEntry.fromJson(e)).toList();
  }

  Future<ContactEntry> addContact(String ownerId, String name, String phone) async {
    final res = await http.post(
      Uri.parse('$base/api/contacts/$ownerId/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    if (res.statusCode != 200) throw Exception('addContact failed');
    return ContactEntry.fromJson(jsonDecode(res.body));
  }

  Future<ContactEntry> linkVerifyContact({
    required String ownerId,
    required String contactId,
    required String linkedUserId,
    required String attestation,
  }) async {
    final res = await http.post(
      Uri.parse('$base/api/contacts/$ownerId/link-verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contactId': contactId,
        'linkedUserId': linkedUserId,
        'attestation': attestation,
      }),
    );
    if (res.statusCode != 200) throw Exception('linkVerifyContact failed');
    return ContactEntry.fromJson(jsonDecode(res.body));
  }

  // -------- GROUPS --------
  Future<List<GroupModel>> listGroups() async {
    final res = await http.get(Uri.parse('$base/api/groups'));
    if (res.statusCode != 200) throw Exception('listGroups failed');
    final L = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return L.map((e) => GroupModel.fromJson(e)).toList();
  }

  Future<GroupModel> getGroup(String id) async {
    final res = await http.get(Uri.parse('$base/api/groups/$id'));
    if (res.statusCode != 200) throw Exception('getGroup failed');
    return GroupModel.fromJson(jsonDecode(res.body));
  }

  /// Create group on backend
  Future<GroupModel> createGroup({
    required String name,
    required String creatorUserId,
    List<String>? admins,
    int endorsementsNeeded = 1,
  }) async {
    final res = await http.post(
      Uri.parse('$base/api/groups'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'creatorUserId': creatorUserId,
        'admins': admins ?? [creatorUserId],
        'endorsementsNeeded': endorsementsNeeded,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('createGroup failed: ${res.statusCode} ${res.body}');
    }
    return GroupModel.fromJson(jsonDecode(res.body));
  }

  Future<GroupModel> inviteToGroup(String groupId, String inviterUserId, String joinerUserId) async {
    final res = await http.post(
      Uri.parse('$base/api/groups/$groupId/invite'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'inviterUserId': inviterUserId,
        'joinerUserId': joinerUserId,
      }),
    );
    if (res.statusCode != 200) throw Exception('inviteToGroup failed: ${res.body}');
    return GroupModel.fromJson(jsonDecode(res.body));
  }

  Future<GroupModel> endorse(String groupId, String endorserUserId, String joiningUserId) async {
    final res = await http.post(
      Uri.parse('$base/api/groups/$groupId/endorse'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'endorserUserId': endorserUserId,
        'joiningUserId': joiningUserId,
      }),
    );
    if (res.statusCode != 200) throw Exception('endorse failed: ${res.statusCode} ${res.body}');
    return GroupModel.fromJson(jsonDecode(res.body));
  }

  // -------- MESSAGES --------
  Future<List<ChatMessage>> listMessages(String groupId, String userId) async {
    final res = await http.get(Uri.parse('$base/api/groups/$groupId/messages?userId=$userId'));
    if (res.statusCode != 200) throw Exception('listMessages failed');
    final L = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return L.map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<void> sendMessage(String groupId, String senderUserId, String text) async {
    final res = await http.post(
      Uri.parse('$base/api/groups/$groupId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'senderUserId': senderUserId, 'text': text}),
    );
    if (res.statusCode != 200) throw Exception('sendMessage failed: ${res.body}');
  }
}
