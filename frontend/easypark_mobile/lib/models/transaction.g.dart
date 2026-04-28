// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

DateTime _parseAsUtcThenLocal(String value) {
  final hasTimezone =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
  final normalized = hasTimezone ? value : '${value}Z';
  return DateTime.parse(normalized).toLocal();
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: (json['id'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
  createdAt: _parseAsUtcThenLocal(json['createdAt'] as String),
  type: json['type'] as String? ?? 'Debit',
  reservationId: (json['reservationId'] as num?)?.toInt(),
  description: json['description'] as String?,
  isPaid: json['isPaid'] as bool? ?? false,
);

Map<String, dynamic> _$TransactionToJson(Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'createdAt': instance.createdAt.toIso8601String(),
      'type': instance.type,
      'reservationId': instance.reservationId,
      'description': instance.description,
      'isPaid': instance.isPaid,
    };
