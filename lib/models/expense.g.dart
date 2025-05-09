// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
  id: json['id'] as String?,
  groupId: json['groupId'] as String,
  title: json['title'] as String,
  amount: (json['amount'] as num).toDouble(),
  payerId: json['payerId'] as String,
  dateTime:
      json['dateTime'] == null
          ? null
          : DateTime.parse(json['dateTime'] as String),
  splitType: $enumDecode(_$SplitTypeEnumMap, json['splitType']),
  splitDetails: (json['splitDetails'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
);

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
  'id': instance.id,
  'groupId': instance.groupId,
  'title': instance.title,
  'amount': instance.amount,
  'payerId': instance.payerId,
  'dateTime': instance.dateTime.toIso8601String(),
  'splitType': _$SplitTypeEnumMap[instance.splitType]!,
  'splitDetails': instance.splitDetails,
};

const _$SplitTypeEnumMap = {
  SplitType.equal: 'equal',
  SplitType.unequal: 'unequal',
  SplitType.percentage: 'percentage',
  SplitType.shares: 'shares',
};
