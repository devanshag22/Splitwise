import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'expense.g.dart'; // Generated file

enum SplitType { equal, unequal, percentage, shares }

@JsonSerializable()
class Expense {
  final String id;
  final String groupId;
  String title;
  double amount;
  String payerId; // Friend ID
  DateTime dateTime;
  SplitType splitType;
  // Stores details needed for the split (e.g., {friendId: amount/percentage/shares})
  Map<String, double> splitDetails;

  Expense({
    String? id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.payerId,
    DateTime? dateTime,
    required this.splitType,
    Map<String, double>? splitDetails,
  })  : id = id ?? const Uuid().v4(),
        dateTime = dateTime ?? DateTime.now(),
        splitDetails = splitDetails ?? {};

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);
}