import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'friend.dart';

part 'group.g.dart'; // Generated file

@JsonSerializable(explicitToJson: true) // Important for nested objects
class Group {
  final String id;
  String name;
  List<Friend> members;

  Group({String? id, required this.name, List<Friend>? members})
      : id = id ?? const Uuid().v4(),
        members = members ?? [];

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
  Map<String, dynamic> toJson() => _$GroupToJson(this);
}