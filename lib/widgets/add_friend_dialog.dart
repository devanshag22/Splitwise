import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../models/group.dart';

class AddFriendDialog extends StatefulWidget {
  final Group group; // To check for existing names
  final Function(Friend) onFriendAdded;

  const AddFriendDialog({
    super.key,
    required this.group,
    required this.onFriendAdded,
  });

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
       // Check if friend name already exists (case-insensitive)
       if (widget.group.members.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('"$name" is already a member of this group.'), backgroundColor: Colors.orange),
          );
          return; // Don't add duplicate
       }

      final newFriend = Friend(name: name);
      widget.onFriendAdded(newFriend);
      Navigator.of(context).pop(); // Close dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Member'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Friend\'s Name'),
          autofocus: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a name.';
            }
            return null;
          },
           onFieldSubmitted: (_) => _submit(), // Allow submitting with Enter key
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: _submit,
        ),
      ],
    );
  }
}