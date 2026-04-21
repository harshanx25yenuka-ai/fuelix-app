// lib/models/family_models.dart

import 'dart:ui';

import 'package:fuelix_app/theme/app_theme.dart';

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
  bool get canTopUp => myPermissions['can_topup'] ?? false;
  bool get canRefuel => myPermissions['can_refuel'] ?? false;

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
  bool get canTopUp => permissions['can_topup'] ?? false;
  bool get canRefuel => permissions['can_refuel'] ?? false;

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
    required this.permissions,
    required this.sharedAt,
  });

  bool get canRefuel => permissions['can_refuel'] ?? false;
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

  SharedWallet({
    required this.balance,
    required this.transactions,
    required this.canTopup,
    required this.canRefuel,
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
