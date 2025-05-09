import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/services.dart'; 
import 'package:intl/intl.dart'; // For date formatting
import 'package:splitwise/models/expense.dart';
import 'package:splitwise/models/friend.dart';
import 'package:splitwise/models/group.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
// import 'dart:math'; // For max function

class AddExpenseScreen extends StatefulWidget {
  final Group group;

  const AddExpenseScreen({super.key, required this.group});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedPayerId;
  SplitType _selectedSplitType = SplitType.equal;
  DateTime _selectedDate = DateTime.now();

  // For managing dynamic split inputs
  Map<String, TextEditingController> _splitControllers = {};
  Map<String, double> _splitValues = {}; // Stores the parsed numeric values

  @override
  void initState() {
    super.initState();
    // Initialize payer if members exist
    if (widget.group.members.isNotEmpty) {
      _selectedPayerId = widget.group.members.first.id;
    }
    // Initialize controllers for unequal/percentage/shares based on default split type
    _initializeSplitControllers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _splitControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // Initialize or clear controllers based on members
  void _initializeSplitControllers() {
     // Dispose existing controllers first
    _splitControllers.forEach((_, controller) => controller.dispose());
    _splitControllers = {};
    _splitValues = {};

    // Create new controllers for current members
    for (var member in widget.group.members) {
      _splitControllers[member.id] = TextEditingController();
       _splitValues[member.id] = 0.0; // Initialize value
    }
     // Set default values if split type requires it (e.g., equal)
     _updateSplitFieldsBasedOnType(_selectedSplitType);
  }

  // Updates the TextFields when split type changes or amount changes for 'equal'
  void _updateSplitFieldsBasedOnType(SplitType type, {double? totalAmount}) {
     totalAmount ??= double.tryParse(_amountController.text) ?? 0.0;

     switch (type) {
       case SplitType.equal:
         final memberCount = widget.group.members.length;
         final share = memberCount > 0 ? (totalAmount / memberCount) : 0.0;
         _splitControllers.forEach((id, controller) {
            // Format to 2 decimal places for display
           controller.text = share.toStringAsFixed(2);
           _splitValues[id] = share; // Store the precise value
         });
         break;
       case SplitType.unequal:
       case SplitType.percentage:
       case SplitType.shares:
         // Clear fields or keep existing manual input? Let's keep for editing.
         // Optionally, clear them:
         // _splitControllers.forEach((id, controller) => controller.clear());
         // _splitValues.forEach((id, _) => _splitValues[id] = 0.0);
         // Or pre-fill percentages/shares if desired, e.g., equal percentage
         if (type == SplitType.percentage && totalAmount == 0.0) { // Only if amount is not yet set
             final memberCount = widget.group.members.length;
             final percent = memberCount > 0 ? (100.0 / memberCount) : 0.0;
             _splitControllers.forEach((id, controller) {
               controller.text = percent.toStringAsFixed(1); // Display percent
             });
         }
         // For shares, typically start blank or with '1'
         if (type == SplitType.shares && totalAmount == 0.0) {
             _splitControllers.forEach((id, controller) {
               controller.text = '1';
             });
         }
         break;
     }
      // Update the state to rebuild the UI with new controller text
     if (mounted) {
       setState(() {});
     }
  }

  // Validate and parse the input fields for non-equal splits
  bool _validateAndParseSplitDetails() {
     _splitValues.clear();
     double currentTotal = 0.0;
     final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

     if (totalAmount <= 0) {
        _showValidationError("Total amount must be positive.");
        return false;
     }

     for (var member in widget.group.members) {
       final controller = _splitControllers[member.id];
       final valueStr = controller?.text.trim() ?? '';
       final value = double.tryParse(valueStr) ?? 0.0;

       if (value < 0) {
          _showValidationError("Split value for ${member.name} cannot be negative.");
          return false;
       }
       _splitValues[member.id] = value; // Store parsed value
       currentTotal += value;
     }


     // --- Validation based on split type ---
     switch (_selectedSplitType) {
       case SplitType.equal:
          // Already calculated, but double check consistency
          final memberCount = widget.group.members.length;
          final expectedShare = memberCount > 0 ? (totalAmount / memberCount) : 0.0;
          for (var member in widget.group.members) {
             if ((_splitValues[member.id]! - expectedShare).abs() > 0.01) {
                 if (kDebugMode) {
                   print("Equal split mismatch for ${member.name}. Expected: $expectedShare, Got: ${_splitValues[member.id]}");
                 }
                // Maybe recalculate here? For now, assume _updateSplitFieldsBasedOnType handled it.
             }
              // Re-assign precise value for saving
             _splitValues[member.id] = expectedShare;
          }
          // Ensure the sum is very close to the total amount
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
         break;

       case SplitType.percentage:
         if ((currentTotal - 100.0).abs() > 0.1) { // Allow slightly larger tolerance for percentages
            _showValidationError('Percentages must add up to 100%. Current sum: ${currentTotal.toStringAsFixed(1)}%');
           return false;
         }
          // Convert percentages to actual amounts for storage in splitDetails
         final Map<String, double> amounts = {};
         double calculatedSum = 0;
         Friend? lastMember; // For rounding adjustment
         for (var member in widget.group.members) {
           final percentage = _splitValues[member.id] ?? 0.0;
           amounts[member.id] = totalAmount * (percentage / 100.0);
           calculatedSum += amounts[member.id]!;
           lastMember = member;
         }
         // Adjust last member's share for rounding errors
          if (lastMember != null) {
              double diff = totalAmount - calculatedSum;
              if (diff.abs() > 0.001 && diff.abs() < 0.02) { // Only adjust small rounding diffs
                  amounts[lastMember.id] = (amounts[lastMember.id] ?? 0.0) + diff;
                  if (kDebugMode) print("Adjusted ${lastMember.name}'s share by $diff due to rounding.");
              } else if (diff.abs() >= 0.02) {
                  // If difference is significant, it's likely a calculation error, but warn
                   if (kDebugMode) print("Significant difference ($diff) after percentage calculation. Sum: ${calculatedSum}");
                    _showValidationError('Internal error calculating percentage split amounts. Sum: ${calculatedSum.toStringAsFixed(2)}');
                   return false; // Prevent saving with large discrepancy
              }
          }
         _splitValues = amounts; // Replace percentages with calculated amounts
         break;

       case SplitType.shares:
          if (currentTotal <= 0) {
            _showValidationError('Total number of shares must be positive.');
            return false;
          }
          // Convert shares to actual amounts
          final Map<String, double> amounts = {};
          double calculatedSum = 0;
          Friend? lastMember;
          for (var member in widget.group.members) {
             final shares = _splitValues[member.id] ?? 0.0;
             amounts[member.id] = totalAmount * (shares / currentTotal);
             calculatedSum += amounts[member.id]!;
             lastMember = member;
          }
          // Adjust last member's share for rounding errors
           if (lastMember != null) {
              double diff = totalAmount - calculatedSum;
              if (diff.abs() > 0.001 && diff.abs() < 0.02) {
                  amounts[lastMember.id] = (amounts[lastMember.id] ?? 0.0) + diff;
                   if (kDebugMode) print("Adjusted ${lastMember.name}'s share by $diff due to rounding.");
              } else if (diff.abs() >= 0.02) {
                  if (kDebugMode) print("Significant difference ($diff) after shares calculation. Sum: ${calculatedSum}");
                   _showValidationError('Internal error calculating share split amounts. Sum: ${calculatedSum.toStringAsFixed(2)}');
                  return false;
              }
           }
          _splitValues = amounts; // Replace shares with calculated amounts
         break;
     }
     return true;
   }

  void _showValidationError(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }

  void _saveExpense() {
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

      if (_selectedSplitType != SplitType.equal) {
        if (!_validateAndParseSplitDetails()) {
          return; // Validation failed, message already shown
        }
      } else {
         // Ensure splitValues are calculated correctly for equal split even if fields weren't touched
          final memberCount = widget.group.members.length;
          final share = memberCount > 0 ? (totalAmount / memberCount) : 0.0;
           _splitValues = { for (var m in widget.group.members) m.id : share };
      }


      // Filter out zero amounts from split details before saving
      final finalSplitDetails = Map<String, double>.from(_splitValues)
        ..removeWhere((key, value) => value.abs() < 0.01);


      final newExpense = Expense(
        groupId: widget.group.id,
        title: _titleController.text.trim(),
        amount: totalAmount,
        payerId: _selectedPayerId!,
        dateTime: _selectedDate,
        splitType: _selectedSplitType,
        splitDetails: finalSplitDetails, // Use the validated & parsed values
      );

      Provider.of<AppData>(context, listen: false).addExpense(newExpense);
      Navigator.of(context).pop();
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 365))); // Allow future dates? Adjust if needed
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Recalculate equal split if amount changes
    final currentAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (_selectedSplitType == SplitType.equal) {
       final memberCount = widget.group.members.length;
       final share = memberCount > 0 ? (currentAmount / memberCount) : 0.0;
        _splitControllers.forEach((id, controller) {
           // Only update text if it differs significantly, avoid loops
           if ((double.tryParse(controller.text) ?? -1) != share) {
               controller.text = share.toStringAsFixed(2);
           }
           _splitValues[id] = share; // Always update stored value
        });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Use ListView for scrolling on small screens
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Expense Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _amountController,
                 decoration: const InputDecoration(
                     labelText: 'Amount', prefixText: '\$ '), // Adjust currency symbol/locale
                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                   FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow digits and decimal point (max 2 decimal places)
                 ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount.';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid positive amount.';
                  }
                  return null;
                },
                 onChanged: (value) {
                    // Update split fields if type is equal when amount changes
                    if (_selectedSplitType == SplitType.equal) {
                      _updateSplitFieldsBasedOnType(SplitType.equal, totalAmount: double.tryParse(value));
                    }
                     // Trigger rebuild to update sum display if needed
                    setState(() {});
                 },
              ),
              DropdownButtonFormField<String>(
                value: _selectedPayerId,
                hint: const Text('Paid by'),
                decoration: const InputDecoration(labelText: 'Payer'),
                items: widget.group.members.map((friend) {
                  return DropdownMenuItem(
                    value: friend.id,
                    child: Text(friend.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPayerId = value;
                  });
                },
                validator: (value) => value == null ? 'Please select who paid.' : null,
              ),
               // Date Picker
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
                 items: SplitType.values.map((type) {
                   return DropdownMenuItem(
                     value: type,
                     child: Text(_splitTypeToString(type)),
                   );
                 }).toList(),
                 onChanged: (value) {
                    if (value != null) {
                     setState(() {
                       _selectedSplitType = value;
                       // Update the input fields based on the new type
                       _updateSplitFieldsBasedOnType(value);
                     });
                    }
                 },
               ),

              const SizedBox(height: 10),
               // Dynamic Split Input Section
              _buildSplitInputSection(),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: const Text('Add Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build the dynamic input fields
  Widget _buildSplitInputSection() {
    bool isManuallyEditable = _selectedSplitType != SplitType.equal;
     double currentSplitSum = 0.0;
     if (isManuallyEditable) {
        _splitControllers.forEach((key, controller) {
           currentSplitSum += double.tryParse(controller.text.trim()) ?? 0.0;
        });
     }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         if (isManuallyEditable) // Show sum for manual splits
           Padding(
             padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
             child: Text(
                 _getSplitSumLabel(currentSplitSum),
                style: TextStyle(
                   color: _isSplitSumValid(currentSplitSum) ? Colors.green : Colors.red,
                   fontWeight: FontWeight.bold
                ),
             ),
           ),
        ...widget.group.members.map((member) {
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
                     readOnly: !isManuallyEditable, // Read-only for equal split
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: _selectedSplitType == SplitType.unequal ? '\$ ' : null,
                        suffixText: _selectedSplitType == SplitType.percentage ? '%' : (_selectedSplitType == SplitType.shares ? ' units' : null),
                      ),
                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                     inputFormatters: [
                       FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                     ],
                      validator: (value) {
                        // Basic validation handled centrally, but can add field-specific checks if needed
                        if (isManuallyEditable) {
                           if (value == null || value.trim().isEmpty) return 'Enter value';
                           if ((double.tryParse(value) ?? -1.0) < 0) return '>= 0';
                        }
                        return null;
                      },
                      onChanged: isManuallyEditable ? (_) => setState(() {}) : null, // Trigger rebuild to update sum display
                   ),
                 ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

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
           return 'Total Shares: ${currentSum.toStringAsFixed(2)}'; // No target total, just display sum
         case SplitType.equal:
           return ''; // No sum needed for equal
      }
   }

   bool _isSplitSumValid(double currentSum) {
     final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
     switch (_selectedSplitType) {
       case SplitType.unequal:
         return (currentSum - totalAmount).abs() < 0.01;
       case SplitType.percentage:
         return (currentSum - 100.0).abs() < 0.1;
       case SplitType.shares:
         return currentSum > 0; // Valid if shares are positive
       case SplitType.equal:
         return true; // Always valid by calculation
     }
   }

  // Helper for displaying enum nicely
  String _splitTypeToString(SplitType type) {
    switch (type) {
      case SplitType.equal: return 'Equally';
      case SplitType.unequal: return 'Unequally (by Amount)';
      case SplitType.percentage: return 'By Percentage';
      case SplitType.shares: return 'By Shares';
    }
  }
}