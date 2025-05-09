import 'package:flutter/material.dart';
import 'package:splitwise/screens/add_group_screen.dart';
import 'package:splitwise/screens/group_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Splitter Groups'),
         actions: [
          // Optional: Add a refresh button if needed, though Provider handles updates
          // IconButton(
          //   icon: Icon(Icons.refresh),
          //   onPressed: () => appData.loadData(), // Force reload
          // ),
        ],
      ),
      body: appData.isLoading
          ? const Center(child: CircularProgressIndicator())
          : appData.groups.isEmpty
              ? const Center(
                  child: Text(
                    'No groups yet.\nTap + to add a group.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: appData.groups.length,
                  itemBuilder: (ctx, index) {
                    final group = appData.groups[index];
                    return ListTile(
                      title: Text(group.name),
                      subtitle: Text('${group.members.length} members'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => GroupDetailScreen(groupId: group.id),
                          ),
                        );
                      },
                       onLongPress: () => _showDeleteGroupDialog(context, appData, group.id),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddGroupScreen()),
          );
        },
      ),
    );
  }

   void _showDeleteGroupDialog(BuildContext context, AppData appData, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: const Text('Are you sure you want to delete this group and all its expenses? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
             style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              appData.deleteGroup(groupId);
              Navigator.of(ctx).pop();
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Group deleted')),
               );
            },
          ),
        ],
      ),
    );
  }
}