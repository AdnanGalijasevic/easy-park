import 'package:json_annotation/json_annotation.dart';

part 'transaction.g.dart';

@JsonSerializable()
class Transaction {
  final int id;
  final double amount;
  final DateTime createdAt;
  /// API sends camelCase `type` (ASP.NET default); `Type` would always miss and default to Debit.
  @JsonKey(name: 'type', defaultValue: 'Debit')
  final String type;
  final int? reservationId;
  final String? description;
  @JsonKey(name: 'isPaid', defaultValue: false)
  final bool isPaid;

  Transaction({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.type = 'Debit',
    this.reservationId,
    this.description,
    this.isPaid = false,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionToJson(this);
}
