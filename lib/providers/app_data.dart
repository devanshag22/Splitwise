import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/friend.dart';

// Data structure for balance calculation results
class BalanceResult {
  final Map<String, double> directBalances; // {friendId: netAmount}
  final List<Transaction> simplifiedTransactions;

  BalanceResult({required this.directBalances, required this.simplifiedTransactions});
}

class Transaction {
  final String fromId;
  final String toId;
  final double amount;

  Transaction({required this.fromId, required this.toId, required this.amount});
}


class AppData extends ChangeNotifier {
  List<Group> _groups = [];
  List<Expense> _expenses = [];

  bool _isLoading = true;

  List<Group> get groups => _groups;
  List<Expense> get expenses => _expenses; // All expenses
  bool get isLoading => _isLoading;

  AppData() {
    loadData();
  }

  // --- Persistence ---

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _groupsFile async {
    final path = await _localPath;
    return File('$path/groups.json');
  }

  Future<File> get _expensesFile async {
    final path = await _localPath;
    return File('$path/expenses.json');
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners(); // Notify UI that loading has started

    try {
      // Load Groups
      final groupsFile = await _groupsFile;
      if (await groupsFile.exists()) {
        final contents = await groupsFile.readAsString();
        if (contents.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(contents);
          _groups = jsonList.map((json) => Group.fromJson(json)).toList();
        } else {
           _groups = [];
        }
      } else {
        _groups = [];
      }

      // Load Expenses
      final expensesFile = await _expensesFile;
      if (await expensesFile.exists()) {
         final contents = await expensesFile.readAsString();
         if (contents.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(contents);
           _expenses = jsonList.map((json) => Expense.fromJson(json)).toList();
         } else {
            _expenses = [];
         }
      } else {
        _expenses = [];
      }

    } catch (e) {
      if (kDebugMode) {
        print("Error loading data: $e");
      }
      // Handle error appropriately, maybe show a message to the user
      _groups = [];
      _expenses = [];
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that loading is complete (or failed)
    }
  }

  Future<void> saveData() async {
    try {
      final groupsFile = await _groupsFile;
      final expensesFile = await _expensesFile;

      final groupsJson = jsonEncode(_groups.map((g) => g.toJson()).toList());
      final expensesJson = jsonEncode(_expenses.map((e) => e.toJson()).toList());

      await groupsFile.writeAsString(groupsJson);
      await expensesFile.writeAsString(expensesJson);

      if (kDebugMode) {
        print("Data saved successfully.");
      }

    } catch (e) {
       if (kDebugMode) {
         print("Error saving data: $e");
       }
      // Handle error
    }
  }

  // --- Group Management ---

  void addGroup(Group group) {
    _groups.add(group);
    _saveAndNotify();
  }

  void updateGroup(Group updatedGroup) {
    final index = _groups.indexWhere((g) => g.id == updatedGroup.id);
    if (index != -1) {
      _groups[index] = updatedGroup;
      _saveAndNotify();
    }
  }

  void deleteGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    // Also remove associated expenses
    _expenses.removeWhere((e) => e.groupId == groupId);
    _saveAndNotify();
  }

  Group? getGroupById(String groupId) {
     try {
       return _groups.firstWhere((g) => g.id == groupId);
     } catch (e) {
       return null; // Not found
     }
   }

   Friend? getFriendById(String friendId) {
      for (var group in _groups) {
         try {
           return group.members.firstWhere((m) => m.id == friendId);
         } catch (e) {
           // Friend not in this group, continue searching
         }
      }
      return null; // Friend not found in any group
    }

  // --- Expense Management ---

  List<Expense> getExpensesForGroup(String groupId) {
    return _expenses.where((e) => e.groupId == groupId).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Sort newest first
  }

  void addExpense(Expense expense) {
    _expenses.add(expense);
    _saveAndNotify();
  }

  void updateExpense(Expense updatedExpense) {
    final index = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (index != -1) {
      _expenses[index] = updatedExpense;
      _saveAndNotify();
    }
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    _saveAndNotify();
  }

   Expense? getExpenseById(String expenseId) {
     try {
       return _expenses.firstWhere((e) => e.id == expenseId);
     } catch (e) {
       return null; // Not found
     }
   }

  // --- Balance Calculation ---

  BalanceResult calculateBalances(String groupId) {
    final group = getGroupById(groupId);
    if (group == null) {
      return BalanceResult(directBalances: {}, simplifiedTransactions: []);
    }

    final groupExpenses = getExpensesForGroup(groupId);
    final Map<String, double> balances = {
      for (var member in group.members) member.id: 0.0
    };

    // --- Calculate Direct Balances ---
    for (var expense in groupExpenses) {
      final payerId = expense.payerId;
      final amount = expense.amount;
      final membersInSplit = <String>{}; // Members involved in *this* expense split

      // Add amount paid by the payer (they are owed this)
      balances[payerId] = (balances[payerId] ?? 0.0) + amount;

      // Subtract shares owed by each participant
      switch (expense.splitType) {
        case SplitType.equal:
          final involvedMembers = group.members; // Assume all members involved for equal split
          if (involvedMembers.isNotEmpty) {
            final share = amount / involvedMembers.length;
            for (var member in involvedMembers) {
               balances[member.id] = (balances[member.id] ?? 0.0) - share;
               membersInSplit.add(member.id);
            }
          }
          break;

        case SplitType.unequal:
        case SplitType.percentage: // Percentages stored as amounts in splitDetails
        case SplitType.shares: // Shares stored as amounts in splitDetails
          double totalSpecified = expense.splitDetails.values.fold(0.0, (prev, val) => prev + val);
          // Basic check for consistency (can be more robust)
           if ((totalSpecified - amount).abs() > 0.01) {
              if (kDebugMode) {
                print("Warning: Split details for expense '${expense.title}' do not sum up to total amount. Total specified: $totalSpecified, Amount: $amount");
                // Decide how to handle this: proportionally adjust, throw error, etc.
                // For now, proceed cautiously. Could normalize here if needed.
              }
           }
           expense.splitDetails.forEach((memberId, shareAmount) {
             balances[memberId] = (balances[memberId] ?? 0.0) - shareAmount;
             membersInSplit.add(memberId);
          });
          break;
      }
       // Ensure payer is considered if they weren't explicitly in splitDetails
       if (!membersInSplit.contains(payerId) && expense.splitDetails.isNotEmpty) {
          // This might indicate an issue if the payer paid but isn't assigned a share
          if (kDebugMode) {
             print("Warning: Payer ${getFriendById(payerId)?.name ?? payerId} not included in split details for expense '${expense.title}'.");
          }
        }

    }

     // Remove entries very close to zero to handle floating point inaccuracies
     final directBalances = Map<String, double>.from(balances)
        ..removeWhere((key, value) => value.abs() < 0.01);


    // --- Calculate Simplified Transactions (Greedy Algorithm) ---
    final transactions = <Transaction>[];
    final debtors = <MapEntry<String, double>>[];
    final creditors = <MapEntry<String, double>>[];

     // Use the raw balances before removing near-zero values for simplification
    balances.forEach((id, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(id, balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(id, balance));
      }
    });

    // Sort for potentially more optimal pairing (largest debtor pays largest creditor)
    debtors.sort((a, b) => a.value.compareTo(b.value)); // Most negative first
    creditors.sort((a, b) => b.value.compareTo(a.value)); // Most positive first

    int debtorIdx = 0;
    int creditorIdx = 0;

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
       final debtor = debtors[debtorIdx];
       final creditor = creditors[creditorIdx];
       final debt = debtor.value.abs();
       final credit = creditor.value;

       final transferAmount = debt < credit ? debt : credit;

       // Check if transferAmount is negligible
       if (transferAmount < 0.01) {
          // Move to next potential pair if amount is too small
           if (debt < credit) {
             debtorIdx++;
           } else {
             creditorIdx++;
           }
          continue;
       }

       transactions.add(Transaction(
         fromId: debtor.key,
         toId: creditor.key,
         amount: transferAmount,
       ));

       // Update balances (use mutable map entries or replace in list)
       debtors[debtorIdx] = MapEntry(debtor.key, debtor.value + transferAmount);
       creditors[creditorIdx] = MapEntry(creditor.key, creditor.value - transferAmount);

       // Move pointers if balance is settled (close to zero)
       if (debtors[debtorIdx].value.abs() < 0.01) {
         debtorIdx++;
       }
       if (creditors[creditorIdx].value.abs() < 0.01) {
         creditorIdx++;
       }
    }

    return BalanceResult(directBalances: directBalances, simplifiedTransactions: transactions);
  }


  // --- Helper ---

  void _saveAndNotify() {
    saveData(); // Asynchronously save data
    notifyListeners(); // Immediately notify UI
  }
}