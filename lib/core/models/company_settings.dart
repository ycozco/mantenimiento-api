import 'dart:convert';
import '../constants/app_constants.dart';

class CompanySettings {
  final String workspaceId;
  final String companyName;
  final String? legalName;
  final String? ruc;
  final String? phone;
  final String? email;
  final String? address;
  final String currency;
  final String timezone;
  final String? logoUrl;
  final bool allowNegativeStock;
  final double defaultWorkDayHours;
  final int defaultNotificationHour;
  final DateTime updatedAt;

  const CompanySettings({
    this.workspaceId = AppConstants.defaultWorkspaceId,
    this.companyName = 'Decolumax EIRL',
    this.legalName,
    this.ruc,
    this.phone,
    this.email,
    this.address,
    this.currency = 'PEN',
    this.timezone = 'America/Lima',
    this.logoUrl,
    this.allowNegativeStock = false,
    this.defaultWorkDayHours = 8.0,
    this.defaultNotificationHour = 9,
    required this.updatedAt,
  });

  /// Factory con valores predeterminados de Decolumax
  factory CompanySettings.defaults({DateTime? updatedAt}) {
    return CompanySettings(
      workspaceId: AppConstants.defaultWorkspaceId,
      companyName: 'Decolumax EIRL',
      currency: 'PEN',
      timezone: 'America/Lima',
      allowNegativeStock: false,
      defaultWorkDayHours: 8.0,
      defaultNotificationHour: 9,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  CompanySettings copyWith({
    String? workspaceId,
    String? companyName,
    String? legalName,
    String? ruc,
    String? phone,
    String? email,
    String? address,
    String? currency,
    String? timezone,
    String? logoUrl,
    bool? allowNegativeStock,
    double? defaultWorkDayHours,
    int? defaultNotificationHour,
    DateTime? updatedAt,
  }) {
    return CompanySettings(
      workspaceId: workspaceId ?? this.workspaceId,
      companyName: companyName ?? this.companyName,
      legalName: legalName ?? this.legalName,
      ruc: ruc ?? this.ruc,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      logoUrl: logoUrl ?? this.logoUrl,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      defaultWorkDayHours: defaultWorkDayHours ?? this.defaultWorkDayHours,
      defaultNotificationHour:
          defaultNotificationHour ?? this.defaultNotificationHour,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workspaceId': workspaceId,
      'companyName': companyName,
      'legalName': legalName,
      'ruc': ruc,
      'phone': phone,
      'email': email,
      'address': address,
      'currency': currency,
      'timezone': timezone,
      'logoUrl': logoUrl,
      'allowNegativeStock': allowNegativeStock,
      'defaultWorkDayHours': defaultWorkDayHours,
      'defaultNotificationHour': defaultNotificationHour,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    return CompanySettings(
      workspaceId:
          json['workspaceId'] as String? ?? AppConstants.defaultWorkspaceId,
      companyName: json['companyName'] as String? ?? 'Decolumax EIRL',
      legalName: json['legalName'] as String?,
      ruc: json['ruc'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      currency: json['currency'] as String? ?? 'PEN',
      timezone: json['timezone'] as String? ?? 'America/Lima',
      logoUrl: json['logoUrl'] as String?,
      allowNegativeStock: json['allowNegativeStock'] as bool? ?? false,
      defaultWorkDayHours:
          (json['defaultWorkDayHours'] as num?)?.toDouble() ?? 8.0,
      defaultNotificationHour:
          (json['defaultNotificationHour'] as num?)?.toInt() ?? 9,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory CompanySettings.fromJsonString(String source) =>
      CompanySettings.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
