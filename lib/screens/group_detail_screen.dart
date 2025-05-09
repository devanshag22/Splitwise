import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitwise/models/expense.dart';
import 'package:splitwise/screens/add_expense_screen.dart';
import 'package:splitwise/screens/balance_screen.dart'; // To be created
import 'package:splitwise/screens/edit_expense_screen.dart'; // To be created
import 'package:splitwise/widgets/add_friend_dialog.dart'; // To be created
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import '../models/group.dart';
import '../models/friend.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    // Use Consumer or context.watch for reactive updates
    return Consumer<AppData>(
      builder: (context, appData, child) {
        final group = appData.getGroupById(groupId);
        final groupExpenses = appData.getExpensesForGroup(groupId);

        if (group == null) {
          // Handle case where group might have been deleted
          // Or check before navigating to this screen
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Group not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Add Member',
                onPressed: () => _showAddFriendDialog(context, appData, group),
              ),
              IconButton(
                 icon: const Icon(Icons.calculate),
                 tooltip: 'View Balances',
                 onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => BalanceScreen(groupId: groupId),
                    ));
                 },
              ),
            ],
          ),
          body: Column(
             children: [
               _buildMembersList(context, appData, group), // Show members
               const Divider(),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                 child: Text('Expenses', style: Theme.of(context).textTheme.titleLarge),
               ),
               Expanded(
                 child: groupExpenses.isEmpty
                     ? const Center(child: Text('No expenses added yet.'))
                     : ListView.builder(
                         itemCount: groupExpenses.length,
                         itemBuilder: (ctx, index) {
                           final expense = groupExpenses[index];
                           final payer = appData.getFriendById(expense.payerId);
                           return ListTile(
                             title: Text(expense.title),
                             subtitle: Text(
                               'Paid by ${payer?.name ?? 'Unknown'} on ${DateFormat.yMd().add_jm().format(expense.dateTime)}',
                             ),
                             trailing: Text(
                               NumberFormat.simpleCurrency(locale: 'en_IN').format(expense.amount), // Adjust locale as needed
                               style: const TextStyle(fontWeight: FontWeight.bold),
                             ),
                             onTap: () {
                               // Navigate to Edit Expense Screen
                               Navigator.of(context).push(MaterialPageRoute(
                                 builder: (ctx) => EditExpenseScreen(expenseId: expense.id),
                               ));
                             },
                             onLongPress: () => _showDeleteExpenseDialog(context, appData, expense.id),
                           );
                         },
                       ),
               ),
             ],
           ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add Expense',
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (ctx) => AddExpenseScreen(group: group),
              ));
            },
          ),
        );
      },
    );
  }

   // Helper to build members list section
   Widget _buildMembersList(BuildContext context, AppData appData, Group group) {
     return Padding(
       padding: const EdgeInsets.all(8.0),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 8.0),
               child: Text('Members:', style: Theme.of(context).textTheme.titleMedium),
             ),
             const SizedBox(height: 4),
             Wrap( // Use Wrap for better layout if many members
               spacing: 8.0, // Horizontal space between chips
               runSpacing: 4.0, // Vertical space between lines
               children: group.members.map((member) {
                 return Chip(
                   label: Text(member.name),
                    onDeleted: group.members.length > 2 // Prevent removing below 2 members
                      ? () => _showRemoveMemberDialog(context, appData, group, member.id)
                      : null,
                    deleteIcon: group.members.length > 2 ? const Icon(Icons.remove_circle, size: 18) : null,
                 );
               }).toList(),
             ),
          ],
       ),
     );
   }

   void _showAddFriendDialog(BuildContext context, AppData appData, Group group) {
      showDialog(
        context: context,
        builder: (ctx) => AddFriendDialog(
          group: group,
          onFriendAdded: (newFriend) {
             // Create a mutable copy to update members
             List<Friend> updatedMembers = List.from(group.members);
             if (!updatedMembers.any((m) => m.name.toLowerCase() == newFriend.name.toLowerCase())) {
                updatedMembers.add(newFriend);
                // Create a new Group instance with the updated list
                final updatedGroup = Group(
                   id: group.id,
                   name: group.name,
                   members: updatedMembers,
                );
                appData.updateGroup(updatedGroup);
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('${newFriend.name} added to the group.')),
                 );
             } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${newFriend.name} is already in the group.'), backgroundColor: Colors.orange),
                 );
             }
          },
        ),
      );
   }

   void _showRemoveMemberDialog(BuildContext context, AppData appData, Group group, String friendIdToRemove) {
      final friendToRemove = appData.getFriendById(friendIdToRemove);
      if (friendToRemove == null) return;

      // Basic check: See if the member is involved in any expenses (payer or owed)
      // A more robust check might be needed depending on desired behavior
       bool isUsedInExpenses = appData.getExpensesForGroup(groupId).any((exp) =>
            exp.payerId == friendIdToRemove ||
            (exp.splitDetails.containsKey(friendIdToRemove) && exp.splitDetails[friendIdToRemove]! > 0.01)
        );


      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remove ${friendToRemove.name}?'),
          content: Text(isUsedInExpenses
              ? 'Removing ${friendToRemove.name} might affect existing expense settlements. Are you sure? (Existing splits involving them will remain but they cannot be selected for new ones).'
              : 'Are you sure you want to remove ${friendToRemove.name} from the group?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
              onPressed: () {
                 // Create a mutable copy and remove the friend
                 List<Friend> updatedMembers = List.from(group.members);
                 updatedMembers.removeWhere((m) => m.id == friendIdToRemove);

                 // Create a new Group instance with the updated list
                 final updatedGroup = Group(
                    id: group.id,
                    name: group.name,
                    members: updatedMembers,
                 );
                 appData.updateGroup(updatedGroup);

                 Navigator.of(ctx).pop();
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('${friendToRemove.name} removed from the group.')),
                 );
              },
            ),
          ],
        ),
      );
   }


   void _showDeleteExpenseDialog(BuildContext context, AppData appData, String expenseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
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
              appData.deleteExpense(expenseId);
              Navigator.of(ctx).pop();
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Expense deleted')),
               );
            },
          ),
        ],
      ),
    );
  }
}