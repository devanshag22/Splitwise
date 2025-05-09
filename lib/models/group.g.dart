// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Group _$GroupFromJson(Map<String, dynamic> json) => Group(
  id: json['id'] as String?,
  name: json['name'] as String,
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => Friend.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$GroupToJson(Group instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'members': instance.members.map((e) => e.toJson()).toList(),
};
