import 'dart:ui';

import 'package:fuelix_app/theme/app_theme.dart';

class Family {
  final int? id;
  final String familyName;
  final int createdBy;
  final DateTime createdAt;
  final bool isActive;

  Family({
    this.id,
    required this.familyName,
    required this.createdBy,
    required this.createdAt,
    required this.isActive,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'],
      familyName: json['familyName'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'familyName': familyName,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };
}

class FamilyMember {
  final int userId;
  final String name;
  final String email;
  final String role;
  final DateTime joinedAt;
  final Map<String, bool> permissions;

  FamilyMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.permissions,
  });

  bool get isOwner => role == 'OWNER';
  bool get isMember => role == 'MEMBER';
  bool get canTopUp => permissions['can_topup'] ?? false;
  bool get canRefuel => permissions['can_refuel'] ?? false;
  bool get canViewWallet => permissions['can_view_wallet'] ?? false;
  bool get canViewQuota => permissions['can_view_quota'] ?? false;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: json['userId'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joinedAt']),
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
    );
  }
}

class SharedVehicle {
  final int vehicleId;
  final String registrationNo;
  final String make;
  final String model;
  final String type;
  final String fuelType;
  final int ownerId;
  final String ownerName;
  final String? sharedWithName;
  final int? sharedWithUserId;
  final Map<String, bool> permissions;
  final DateTime sharedAt;

  SharedVehicle({
    required this.vehicleId,
    required this.registrationNo,
    required this.make,
    required this.model,
    required this.type,
    required this.fuelType,
    required this.ownerId,
    required this.ownerName,
    this.sharedWithName,
    this.sharedWithUserId,
    required this.permissions,
    required this.sharedAt,
  });

  bool get canRefuel => permissions['can_refuel'] ?? false;
  bool get canViewQuota => permissions['can_view_quota'] ?? false;
  String get displayName => '$make $model ($registrationNo)';

  factory SharedVehicle.fromJson(Map<String, dynamic> json) {
    return SharedVehicle(
      vehicleId: json['vehicleId'],
      registrationNo: json['registrationNo'],
      make: json['make'],
      model: json['model'],
      type: json['type'],
      fuelType: json['fuelType'] ?? 'Petrol',
      ownerId: json['ownerId'],
      ownerName: json['ownerName'] ?? 'Unknown',
      sharedWithName: json['sharedWithName'],
      sharedWithUserId: json['sharedWithUserId'],
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
      sharedAt: DateTime.parse(json['sharedAt']),
    );
  }
}

class SharedWallet {
  final double balance;
  final List<SharedWalletTransaction> transactions;
  final bool canTopup;
  final bool canRefuel;
  final bool canView;

  SharedWallet({
    required this.balance,
    required this.transactions,
    required this.canTopup,
    required this.canRefuel,
    required this.canView,
  });

  String get formattedBalance => 'LKR ${balance.toStringAsFixed(2)}';

  factory SharedWallet.fromJson(Map<String, dynamic> json) {
    List<SharedWalletTransaction> transactions = [];
    if (json['transactions'] != null) {
      transactions = (json['transactions'] as List)
          .map((tx) => SharedWalletTransaction.fromJson(tx))
          .toList();
    }

    return SharedWallet(
      balance: (json['balance'] as num).toDouble(),
      transactions: transactions,
      canTopup: json['canTopup'] ?? false,
      canRefuel: json['canRefuel'] ?? false,
      canView: json['canView'] ?? true,
    );
  }
}

class SharedWalletTransaction {
  final int id;
  final double amount;
  final String type;
  final String? reference;
  final DateTime createdAt;
  final String userName;

  SharedWalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.reference,
    required this.createdAt,
    required this.userName,
  });

  String get formattedAmount => type == 'TOPUP'
      ? '+ LKR ${amount.toStringAsFixed(2)}'
      : '- LKR ${amount.toStringAsFixed(2)}';

  Color get amountColor =>
      type == 'TOPUP' ? AppColors.emerald : AppColors.error;

  factory SharedWalletTransaction.fromJson(Map<String, dynamic> json) {
    return SharedWalletTransaction(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      reference: json['reference'],
      createdAt: DateTime.parse(json['createdAt']),
      userName: json['userName'] ?? 'Unknown',
    );
  }
}

class FamilyInfo {
  final bool hasFamily;
  final int? familyId;
  final String? familyName;
  final String? myRole;
  final List<FamilyMember> members;
  final Map<String, bool> myPermissions;

  FamilyInfo({
    required this.hasFamily,
    this.familyId,
    this.familyName,
    this.myRole,
    required this.members,
    required this.myPermissions,
  });

  bool get isOwner => myRole == 'OWNER';
  bool get canInvite => isOwner;
  bool get canRemoveMembers => isOwner;

  factory FamilyInfo.fromJson(Map<String, dynamic> json) {
    List<FamilyMember> members = [];
    if (json['members'] != null) {
      members = (json['members'] as List)
          .map((m) => FamilyMember.fromJson(m))
          .toList();
    }

    return FamilyInfo(
      hasFamily: json['hasFamily'] ?? false,
      familyId: json['familyId'],
      familyName: json['familyName'],
      myRole: json['myRole'],
      members: members,
      myPermissions: Map<String, bool>.from(json['myPermissions'] ?? {}),
    );
  }
}

class PendingInvitation {
  final int familyId;
  final String familyName;
  final String invitedBy;
  final DateTime invitedAt;

  PendingInvitation({
    required this.familyId,
    required this.familyName,
    required this.invitedBy,
    required this.invitedAt,
  });

  factory PendingInvitation.fromJson(Map<String, dynamic> json) {
    return PendingInvitation(
      familyId: json['familyId'],
      familyName: json['familyName'],
      invitedBy: json['invitedBy'],
      invitedAt: DateTime.parse(json['invitedAt']),
    );
  }
}
