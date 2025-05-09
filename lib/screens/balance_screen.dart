import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';

class BalanceScreen extends StatelessWidget {
  final String groupId;

  const BalanceScreen({super.key, required this.groupId});

   String _formatCurrency(double amount) {
      // Use INR or your preferred locale/currency
      return NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 2).format(amount);
    }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final group = appData.getGroupById(groupId);
    final balanceResult = appData.calculateBalances(groupId);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Group not found.')),
      );
    }

     // Helper to get friend name from ID
     String getFriendName(String friendId) {
       return appData.getFriendById(friendId)?.name ?? 'Unknown Member';
     }

     // Separate balances into owes and owed by
     final owesMoney = Map.fromEntries(balanceResult.directBalances.entries.where((e) => e.value < -0.01));
     final owedMoney = Map.fromEntries(balanceResult.directBalances.entries.where((e) => e.value > 0.01));

    return DefaultTabController(
      length: 2, // Two tabs: Summary and Simplified
      child: Scaffold(
        appBar: AppBar(
          title: Text('${group.name} Balances'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Balance Summary'),
              Tab(text: 'Settlements'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Tab 1: Direct Balances Summary ---
            _buildDirectBalanceView(context, appData, owesMoney, owedMoney, getFriendName),

            // --- Tab 2: Simplified Settlements ---
            _buildSimplifiedSettlementView(context, appData, balanceResult.simplifiedTransactions, getFriendName),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectBalanceView(
      BuildContext context,
      AppData appData,
      Map<String, double> owesMoney,
      Map<String, double> owedMoney,
      String Function(String) getFriendName) {

     if (owesMoney.isEmpty && owedMoney.isEmpty) {
       return const Center(child: Text('Everyone is settled up!'));
     }

     return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (owesMoney.isNotEmpty) ...[
            Text('Who Owes Money:', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
             ...owesMoney.entries.map((entry) {
               return ListTile(
                 leading: const Icon(Icons.arrow_downward, color: Colors.red),
                 title: Text(getFriendName(entry.key)),
                 trailing: Text(
                   _formatCurrency(entry.value.abs()), // Show positive value
                   style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                 ),
               );
             }).toList(),
            const Divider(height: 32),
          ],

          if (owedMoney.isNotEmpty) ...[
            Text('Who Is Owed Money:', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...owedMoney.entries.map((entry) {
              return ListTile(
                 leading: const Icon(Icons.arrow_upward, color: Colors.green),
                 title: Text(getFriendName(entry.key)),
                 trailing: Text(
                   _formatCurrency(entry.value),
                   style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                 ),
              );
            }).toList(),
             const Divider(height: 32),
          ],
        ],
      );
  }


   Widget _buildSimplifiedSettlementView(
       BuildContext context,
       AppData appData,
       List<Transaction> transactions,
       String Function(String) getFriendName) {

      if (transactions.isEmpty) {
        return const Center(child: Text('Everyone is settled up! No transactions needed.'));
      }

      return ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final fromName = getFriendName(transaction.fromId);
          final toName = getFriendName(transaction.toId);
          final amountFormatted = _formatCurrency(transaction.amount);

          return ListTile(
             leading: CircleAvatar(child: Text(fromName.isNotEmpty ? fromName[0] : '?')),
             title: Text('$fromName owes $toName'),
             trailing: Text(
                amountFormatted,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
             ),
             subtitle: Text('$fromName should pay $amountFormatted to $toName'),
          );
        },
         separatorBuilder: (context, index) => const Divider(),
      );
   }
}