import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitwise/models/expense.dart';
import 'package:splitwise/models/friend.dart';
import 'package:splitwise/models/group.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import 'dart:math'; // For max function
import 'package:intl/intl.dart'; // For DateFormat

// NOTE: This screen shares a LOT of logic with AddExpenseScreen.
// Consider refactoring common parts into a shared widget or utility functions
// for better maintainability in a larger project.

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;

  const EditExpenseScreen({super.key, required this.expenseId});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  Expense? _originalExpense;
  Group? _group;
  String? _selectedPayerId;
  SplitType _selectedSplitType = SplitType.equal;
  DateTime _selectedDate = DateTime.now();

  Map<String, TextEditingController> _splitControllers = {};
  Map<String, double> _splitValues = {}; // Stores numeric values for calculation/saving

  bool _isLoading = true; // Loading state for fetching expense/group

  @override
  void initState() {
    super.initState();
    _loadExpenseData();
  }

  Future<void> _loadExpenseData() async {
    final appData = Provider.of<AppData>(context, listen: false);
    _originalExpense = appData.getExpenseById(widget.expenseId);

    if (_originalExpense != null) {
      _group = appData.getGroupById(_originalExpense!.groupId);
      if (_group != null) {
        _titleController.text = _originalExpense!.title;
        _amountController.text = _originalExpense!.amount.toStringAsFixed(2);
        _selectedPayerId = _originalExpense!.payerId;
        _selectedSplitType = _originalExpense!.splitType;
        _selectedDate = _originalExpense!.dateTime;

        _initializeSplitControllers(); // Initialize controllers based on group members
        _populateSplitFieldsFromExpense(); // Fill controllers with expense data
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeSplitControllers() {
    _splitControllers.forEach((_, controller) => controller.dispose());
    _splitControllers = {};
    _splitValues = {};
    if (_group == null) return;

    for (var member in _group!.members) {
      _splitControllers[member.id] = TextEditingController();
      _splitValues[member.id] = 0.0;
    }
  }

  // Fill controllers based on the loaded expense's split details
  void _populateSplitFieldsFromExpense() {
     if (_originalExpense == null || _group == null) return;

     final expense = _originalExpense!;
     final totalAmount = expense.amount;

     switch (expense.splitType) {
       case SplitType.equal:
         final memberCount = _group!.members.length;
         final share = memberCount > 0 ? (totalAmount / memberCount) : 0.0;
         _splitControllers.forEach((id, controller) {
           controller.text = share.toStringAsFixed(2);
           _splitValues[id] = share; // Store precise value
         });
         break;

       case SplitType.unequal:
         _splitControllers.forEach((id, controller) {
           // Use amount directly from splitDetails
           final amount = expense.splitDetails[id] ?? 0.0;
           controller.text = amount.toStringAsFixed(2);
           _splitValues[id] = amount;
         });
         break;

       case SplitType.percentage:
         // Convert stored amounts back to percentages for display
         if (totalAmount > 0) {
            _splitControllers.forEach((id, controller) {
               final amount = expense.splitDetails[id] ?? 0.0;
               final percentage = (amount / totalAmount) * 100.0;
               controller.text = percentage.toStringAsFixed(1); // Display percentage
               _splitValues[id] = percentage; // Store percentage for validation logic
            });
         } else {
            // Handle zero amount case - display 0%?
             _splitControllers.forEach((id, controller) {
                controller.text = '0.0';
                _splitValues[id] = 0.0;
             });
         }
         break;

       case SplitType.shares:
         // Need total shares to display individual shares. SplitDetails stores amounts.
         // We can't perfectly recover the original shares if only amounts are stored.
         // Option 1: Store original shares AND amounts (more complex model)
         // Option 2: Show the calculated *amounts* instead of shares when editing shares split.
         // Option 3: Approximate shares based on ratios (might lead to floating point issues)

         // Let's go with Option 2 (Show Amounts) for simplicity here.
         // Change the display label or make it clear these are amounts.
         _splitControllers.forEach((id, controller) {
            final amount = expense.splitDetails[id] ?? 0.0;
            controller.text = amount.toStringAsFixed(2);
            // Store the amount temporarily; validation needs to be adapted
            _splitValues[id] = amount;
         });
         // Alternative: If we decide to store shares, populate here.
         break;
     }
     // Trigger rebuild
     if (mounted) setState(() {});
  }


    // --- Validation and Saving Logic (Mostly copied from AddExpenseScreen) ---
    // Needs slight adaptation for updating instead of adding

  bool _validateAndParseSplitDetails() {
     _splitValues.clear(); // Start fresh parsing
     double currentTotal = 0.0;
     final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

     if (totalAmount <= 0) {
        _showValidationError("Total amount must be positive.");
        return false;
     }
     if (_group == null) return false; // Should not happen if loaded correctly

     for (var member in _group!.members) {
       final controller = _splitControllers[member.id];
       final valueStr = controller?.text.trim() ?? '';
       final value = double.tryParse(valueStr) ?? 0.0;

       if (value < 0) {
          _showValidationError("Split value for ${member.name} cannot be negative.");
          return false;
       }
       _splitValues[member.id] = value; // Store parsed value for calculation
       currentTotal += value;
     }


     // --- Validation based on split type ---
     switch (_selectedSplitType) {
       case SplitType.equal:
          final memberCount = _group!.members.length;
          final expectedShare = memberCount > 0 ? (totalAmount / memberCount) : 0.0;
          _splitValues = { for (var m in _group!.members) m.id : expectedShare }; // Recalculate precise values
          double calculatedSum = _splitValues.values.fold(0.0, (prev, val) => prev + val);
          if ((calculatedSum - totalAmount).abs() > 0.01) {
              _showValidationError('Internal error: Equal split sum does not match total amount. Sum: ${calculatedSum.toStringAsFixed(2)}');
              return false;
          }
         break;

       case SplitType.unequal:
          if ((currentTotal - totalAmount).abs() > 0.01) {
            _showValidationError('The sum of unequal amounts (${currentTotal.toStringAsFixed(2)}) must equal the total amount (${totalAmount.toStringAsFixed(2)}).');
            return false;
          }
          // _splitValues already contains the parsed amounts
         break;

       case SplitType.percentage:
         if ((currentTotal - 100.0).abs() > 0.1) {
            _showValidationError('Percentages must add up to 100%. Current sum: ${currentTotal.toStringAsFixed(1)}%');
           return false;
         }
          // Convert percentages back to actual amounts for saving
         final Map<String, double> amounts = {};
         double calculatedSum = 0;
         Friend? lastMember;
         for (var member in _group!.members) {
           final percentage = _splitValues[member.id] ?? 0.0;
           amounts[member.id] = totalAmount * (percentage / 100.0);
           calculatedSum += amounts[member.id]!;
           lastMember = member;
         }
         // Adjust rounding
          if (lastMember != null) {
              double diff = totalAmount - calculatedSum;
              if (diff.abs() > 0.001 && diff.abs() < 0.02) {
                  amounts[lastMember.id] = (amounts[lastMember.id] ?? 0.0) + diff;
              } else if (diff.abs() >= 0.02) {
                   _showValidationError('Internal error calculating percentage split amounts. Sum: ${calculatedSum.toStringAsFixed(2)}');
                  return false;
              }
          }
         _splitValues = amounts; // Final amounts to save
         break;

       case SplitType.shares:
         // If using Option 2 (displaying/editing amounts directly for 'shares' type):
         // Validate the sum of amounts equals the total amount.
          if ((currentTotal - totalAmount).abs() > 0.01) {
             _showValidationError('If editing Shares split via amounts, the sum (${currentTotal.toStringAsFixed(2)}) must equal the total amount (${totalAmount.toStringAsFixed(2)}).');
             return false;
          }
          // _splitValues already contains the parsed amounts.

         // If attempting to work with Shares units:
         /*
         if (currentTotal <= 0) {
           _showValidationError('Total number of shares must be positive.');
           return false;
         }
         // Convert shares to actual amounts
         final Map<String, double> amounts = {};
         double calculatedSum = 0;
         Friend? lastMember;
         for (var member in _group!.members) {
            final shares = _splitValues[member.id] ?? 0.0;
            amounts[member.id] = totalAmount * (shares / currentTotal);
            calculatedSum += amounts[member.id]!;
            lastMember = member;
         }
         // Adjust rounding...
         if (lastMember != null) { ... }
         _splitValues = amounts; // Final amounts to save
         */
         break;
     }
     return true;
   }

   void _showValidationError(String message) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(message), backgroundColor: Colors.red),
       );
     }


  void _saveChanges() {
    if (_originalExpense == null || _group == null) return; // Should not happen

    if (_formKey.currentState!.validate()) {
      final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

      if (_selectedPayerId == null) {
          _showValidationError("Please select who paid.");
          return;
      }
       if (totalAmount <= 0) {
           _showValidationError("Amount must be greater than zero.");
           return;
       }

       // Validate and parse/calculate split details based on the selected type
       if (!_validateAndParseSplitDetails()) {
          return; // Validation failed
       }

       // Filter out zero amounts from split details before saving
       final finalSplitDetails = Map<String, double>.from(_splitValues)
        ..removeWhere((key, value) => value.abs() < 0.01);


      // Create updated expense object
      final updatedExpense = Expense(
        id: _originalExpense!.id, // Keep original ID
        groupId: _originalExpense!.groupId, // Keep original group ID
        title: _titleController.text.trim(),
        amount: totalAmount,
        payerId: _selectedPayerId!,
        dateTime: _selectedDate,
        splitType: _selectedSplitType,
        splitDetails: finalSplitDetails, // Use the validated & parsed values
      );

      Provider.of<AppData>(context, listen: false).updateExpense(updatedExpense);
      Navigator.of(context).pop(); // Go back after saving
    }
  }

   Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- UI Build Logic (Mostly copied from AddExpenseScreen) ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Expense...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_originalExpense == null || _group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Expense or Group not found.')),
      );
    }

     // Recalculate equal split fields if amount changes during editing
    final currentAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (_selectedSplitType == SplitType.equal) {
       final memberCount = _group!.members.length;
       final share = memberCount > 0 ? (currentAmount / memberCount) : 0.0;
        _splitControllers.forEach((id, controller) {
           if ((double.tryParse(controller.text) ?? -1) != share) {
              controller.text = share.toStringAsFixed(2);
           }
           _splitValues[id] = share;
        });
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
         actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Expense',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
               // --- Form Fields (same as AddExpenseScreen) ---
               TextFormField(
                 controller: _titleController,
                 decoration: const InputDecoration(labelText: 'Expense Title'),
                 validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a title.' : null,
               ),
               TextFormField(
                 controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                 inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                 validator: (value) {
                   if (value == null || value.isEmpty) return 'Please enter an amount.';
                   final amount = double.tryParse(value);
                   if (amount == null || amount <= 0) return 'Please enter a valid positive amount.';
                   return null;
                 },
                  onChanged: (value) {
                     if (_selectedSplitType == SplitType.equal) {
                       _updateSplitFieldsBasedOnType(SplitType.equal, totalAmount: double.tryParse(value));
                     }
                     setState(() {}); // Update UI (e.g., split sum)
                  },
               ),
               DropdownButtonFormField<String>(
                 value: _selectedPayerId,
                 hint: const Text('Paid by'),
                 decoration: const InputDecoration(labelText: 'Payer'),
                 items: _group!.members.map((friend) => DropdownMenuItem(value: friend.id, child: Text(friend.name))).toList(),
                 onChanged: (value) => setState(() => _selectedPayerId = value),
                 validator: (value) => value == null ? 'Please select who paid.' : null,
               ),
               ListTile(
                 contentPadding: EdgeInsets.zero,
                 title: Text("Date: ${DateFormat.yMd().format(_selectedDate)}"),
                 trailing: const Icon(Icons.calendar_today),
                 onTap: () => _selectDate(context),
               ),

              const SizedBox(height: 20),
              const Text('Split Method', style: TextStyle(fontSize: 16)),
              DropdownButtonFormField<SplitType>(
                 value: _selectedSplitType,
                 decoration: const InputDecoration(labelText: 'How to split?'),
                 items: SplitType.values.map((type) => DropdownMenuItem(value: type, child: Text(_splitTypeToString(type)))).toList(),
                 onChanged: (value) {
                    if (value != null) {
                     setState(() {
                       _selectedSplitType = value;
                       _updateSplitFieldsBasedOnType(value); // Reset/update fields
                     });
                    }
                 },
               ),

              const SizedBox(height: 10),
              _buildSplitInputSection(), // Dynamic split input fields

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // Helper to build the dynamic input fields (Identical to AddExpenseScreen)
  Widget _buildSplitInputSection() {
     bool isManuallyEditable = _selectedSplitType != SplitType.equal;
     double currentSplitSum = 0.0;

     // Calculate current sum based on controllers if manually editable
      if (isManuallyEditable) {
          _splitControllers.forEach((key, controller) {
             currentSplitSum += double.tryParse(controller.text.trim()) ?? 0.0;
          });
      } else {
         // For equal split, sum should match total amount
          currentSplitSum = double.tryParse(_amountController.text) ?? 0.0;
      }


      // Special handling explanation for editing "Shares" split if using Option 2
      String shareEditNote = '';
      if (_selectedSplitType == SplitType.shares) {
          shareEditNote = "\n(Note: Editing amounts directly. Sum must match total.)";
      }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         if (isManuallyEditable)
           Padding(
             padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
             child: Text(
                 _getSplitSumLabel(currentSplitSum) + (_selectedSplitType == SplitType.shares ? shareEditNote : ''),
                style: TextStyle(
                   color: _isSplitSumValid(currentSplitSum) ? Colors.green : Colors.red,
                   fontWeight: FontWeight.bold
                ),
             ),
           ),
        ...?_group?.members.map((member) { // Use null-aware operator
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(member.name, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                 Expanded(
                   flex: 2,
                   child: TextFormField(
                     controller: _splitControllers[member.id],
                     readOnly: !isManuallyEditable,
                      decoration: InputDecoration(
                        isDense: true,
                         prefixText: (_selectedSplitType == SplitType.unequal || (_selectedSplitType == SplitType.shares /*&& using option 2*/)) ? '\$ ' : null,
                         suffixText: _selectedSplitType == SplitType.percentage ? '%' : null, // Adjust suffix if needed for shares
                      ),
                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                     inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (value) {
                        if (isManuallyEditable) {
                           if (value == null || value.trim().isEmpty) return 'Enter value';
                           if ((double.tryParse(value) ?? -1.0) < 0) return '>= 0';
                        }
                        return null;
                      },
                      onChanged: isManuallyEditable ? (_) => setState(() {}) : null,
                   ),
                 ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }


   // Update split fields based on type/amount (Similar to AddExpenseScreen, but uses loaded amount)
  void _updateSplitFieldsBasedOnType(SplitType type, {double? totalAmount}) {
     totalAmount ??= double.tryParse(_amountController.text) ?? 0.0;
     if (_group == null) return;

     switch (type) {
       case SplitType.equal:
         final memberCount = _group!.members.length;
         final share = memberCount > 0 ? (totalAmount / memberCount) : 0.0;
         _splitControllers.forEach((id, controller) {
           controller.text = share.toStringAsFixed(2);
           _splitValues[id] = share;
         });
         break;
       case SplitType.unequal:
       case SplitType.percentage:
       case SplitType.shares:
          // When switching type, clear fields or maybe try to pre-populate intelligently?
          // Clearing seems safer to avoid confusion.
         _splitControllers.forEach((id, controller) => controller.clear());
         _splitValues.forEach((id, _) => _splitValues[id] = 0.0);
         break;
     }
     if (mounted) setState(() {});
  }

  // --- Helper methods (Identical to AddExpenseScreen) ---
   String _getSplitSumLabel(double currentSum) {
     final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
      switch (_selectedSplitType) {
         case SplitType.unequal:
            double remaining = totalAmount - currentSum;
            return 'Total: ${currentSum.toStringAsFixed(2)} / ${totalAmount.toStringAsFixed(2)}\nRemaining: ${remaining.toStringAsFixed(2)}';
         case SplitType.percentage:
            double remaining = 100.0 - currentSum;
            return 'Total: ${currentSum.toStringAsFixed(1)}% / 100%\nRemaining: ${remaining.toStringAsFixed(1)}%';
         case SplitType.shares:
            // If using option 2 (amounts)
             double remaining = totalAmount - currentSum;
             return 'Total Amount: ${currentSum.toStringAsFixed(2)} / ${totalAmount.toStringAsFixed(2)}\nRemaining: ${remaining.toStringAsFixed(2)}';
            // If using shares units: return 'Total Shares: ${currentSum.toStringAsFixed(2)}';
         case SplitType.equal:
           return '';
      }
   }

   bool _isSplitSumValid(double currentSum) {
     final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
     switch (_selectedSplitType) {
       case SplitType.unequal:
       case SplitType.shares: // If using option 2 (amounts)
         return (currentSum - totalAmount).abs() < 0.01;
       case SplitType.percentage:
         return (currentSum - 100.0).abs() < 0.1;
       // case SplitType.shares: return currentSum > 0; // If using share units
       case SplitType.equal:
         return true;
     }
   }

  String _splitTypeToString(SplitType type) {
    switch (type) {
      case SplitType.equal: return 'Equally';
      case SplitType.unequal: return 'Unequally (by Amount)';
      case SplitType.percentage: return 'By Percentage';
       case SplitType.shares: return 'By Shares / Amounts'; // Clarify if using Option 2
    }
  }

  // --- Delete Confirmation ---
   void _showDeleteConfirmation(BuildContext context) {
     if (_originalExpense == null) return;
      final appData = Provider.of<AppData>(context, listen: false);

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Delete Expense?'),
         content: const Text('Are you sure you want to delete this expense? This cannot be undone.'),
         actions: <Widget>[
           TextButton(
             child: const Text('Cancel'),
             onPressed: () => Navigator.of(ctx).pop(),
           ),
           TextButton(
             style: TextButton.styleFrom(foregroundColor: Colors.red),
             child: const Text('Delete'),
             onPressed: () {
               appData.deleteExpense(_originalExpense!.id);
               Navigator.of(ctx).pop(); // Close the dialog
               Navigator.of(context).pop(); // Go back from edit screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted')),
                );
             },
           ),
         ],
       ),
     );
   }


  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _splitControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}