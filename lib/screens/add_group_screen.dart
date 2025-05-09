import 'package:flutter/material.dart';
import 'package:splitwise/models/friend.dart';
import 'package:splitwise/models/group.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';

class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _friendNameController = TextEditingController();
  final List<Friend> _members = [];

  @override
  void dispose() {
    _groupNameController.dispose();
    _friendNameController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _friendNameController.text.trim();
    if (name.isNotEmpty && !_members.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
      setState(() {
        _members.add(Friend(name: name));
        _friendNameController.clear();
      });
    } else if (name.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Friend name cannot be empty.'), backgroundColor: Colors.orange),
       );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Friend "$name" already added.'), backgroundColor: Colors.orange),
       );
    }
  }

  void _removeMember(String friendId) {
     setState(() {
       _members.removeWhere((m) => m.id == friendId);
     });
   }

  void _saveGroup() {
    if (_formKey.currentState!.validate()) {
       if (_members.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A group needs at least 2 members.'), backgroundColor: Colors.orange),
          );
          return;
       }

      final newGroup = Group(
        name: _groupNameController.text.trim(),
        members: _members,
      );
      Provider.of<AppData>(context, listen: false).addGroup(newGroup);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _friendNameController,
                      decoration: const InputDecoration(labelText: 'Add Friend Name'),
                       onSubmitted: (_) => _addMember(), // Add on Enter key
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addMember,
                  ),
                ],
              ),
              const SizedBox(height: 10),
               Expanded(
                 child: _members.isEmpty
                  ? const Center(child: Text('Add at least two members.'))
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (ctx, index) {
                        final member = _members[index];
                        return ListTile(
                          dense: true,
                          title: Text(member.name),
                          trailing: IconButton(
                             visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeMember(member.id),
                          ),
                        );
                      },
                   ),
               ),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveGroup,
                  child: const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}