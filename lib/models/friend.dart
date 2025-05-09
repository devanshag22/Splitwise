import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'friend.g.dart'; // Generated file

@JsonSerializable()
class Friend {
  final String id;
  String name;

  Friend({String? id, required this.name}) : id = id ?? const Uuid().v4();

  factory Friend.fromJson(Map<String, dynamic> json) => _$FriendFromJson(json);
  Map<String, dynamic> toJson() => _$FriendToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}