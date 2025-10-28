class UserProfile {
  final String userId;
  final String displayName;
  final String phone;
  final String identityKeyHex;
  final String fingerprint;

  UserProfile({
    required this.userId,
    required this.displayName,
    required this.phone,
    required this.identityKeyHex,
    required this.fingerprint,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        phone: j['phone'] as String,
        identityKeyHex: (j['identityKeyHex'] ?? 'UNKNOWN_KEY') as String,
        fingerprint: (j['fingerprint'] ?? 'UNKNOWN_FP') as String,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'phone': phone,
        'identityKeyHex': identityKeyHex,
        'fingerprint': fingerprint,
      };
}

class ContactEntry {
  final String contactId;
  final String name;
  final String phone;
  final String? linkedUserId;
  final String state;
  final String? attestation;
  final String? createdAt;

  ContactEntry({
    required this.contactId,
    required this.name,
    required this.phone,
    required this.linkedUserId,
    required this.state,
    this.attestation,
    this.createdAt,
  });

  bool get verified => state.toLowerCase() == 'verified';

  factory ContactEntry.fromJson(Map<String, dynamic> j) => ContactEntry(
        contactId: j['contactId'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        linkedUserId: j['linkedUserId'] as String?,
        state: (j['state'] ?? 'unverified') as String,
        attestation: j['attestation'] as String?,
        createdAt: j['createdAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'name': name,
        'phone': phone,
        'linkedUserId': linkedUserId,
        'state': state,
        'attestation': attestation,
        'createdAt': createdAt,
      };
}

class GroupMember {
  final String userId;
  final String role;
  final bool verified;

  GroupMember({
    required this.userId,
    required this.role,
    required this.verified,
  });

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: j['userId'] as String,
        role: (j['role'] ?? 'member') as String,
        verified: (j['verified'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'role': role,
        'verified': verified,
      };
}

class Endorsement {
  final String endorser;
  final String endorsed;
  final String timestamp;

  Endorsement({
    required this.endorser,
    required this.endorsed,
    required this.timestamp,
  });

  factory Endorsement.fromJson(Map<String, dynamic> j) => Endorsement(
        endorser: j['endorser'] as String,
        endorsed: j['endorsed'] as String,
        timestamp: (j['timestamp'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
    'endorser': endorser,
    'endorsed': endorsed,
    'timestamp': timestamp,
  };
}

class GroupModel {
  final String groupId;
  final String name;
  final String ownerId;
  final List<GroupMember> members;
  final int? endorsementsNeeded;
  final List<Endorsement> endorsements;
  final String? createdAt;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.endorsementsNeeded,
    required this.endorsements,
    this.createdAt,
  });

  int get memberCount => members.length;

  factory GroupModel.fromJson(Map<String, dynamic> j) => GroupModel(
        groupId: j['groupId'] as String,
        name: j['name'] as String,
        ownerId: j['ownerId'] as String,
        members: ((j['members'] ?? []) as List)
            .map((e) => GroupMember.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        endorsementsNeeded: j['endorsementsNeeded'] as int?,
        endorsements: ((j['endorsements'] ?? []) as List)
            .map((e) => Endorsement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: j['createdAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'ownerId': ownerId,
        'members': members.map((e) => e.toJson()).toList(),
        'endorsementsNeeded': endorsementsNeeded,
        'endorsements': endorsements.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
      };
}

class ChatMessage {
  final String id;
  final String groupId;
  final String senderUserId;
  final String senderName;
  final String text;
  final String timestamp;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderUserId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  bool get isSystem => senderUserId == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        groupId: j['groupId'] as String,
        senderUserId: j['senderUserId'] as String,
        senderName: (j['senderName'] ?? j['senderUserId']) as String,
        text: j['text'] as String,
        timestamp: (j['timestamp'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp,
      };
}
