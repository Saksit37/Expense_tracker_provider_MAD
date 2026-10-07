//(การบ้าน)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../models/my_transaction.dart';

class AddEditTransactionScreen extends StatefulWidget {
  // ถ้าส่ง transaction มา = โหมดแก้ไข, ถ้าไม่ส่ง = โหมดเพิ่ม
  final MyTransaction? transaction;

  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;

  @override
  void initState() {
    super.initState();
    // ถ้าเป็นโหมดแก้ไข ใส่ค่าเดิมลงในฟอร์ม
    final tx = widget.transaction;
    if (tx != null) {
      _titleController.text = tx.title;
      _amountController.text = tx.amount.toString();
      _selectedDate = tx.date;
      _selectedType = tx.type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text);

    // ตรวจสอบข้อมูลเบื้องต้น
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อรายการและจำนวนเงินให้ถูกต้อง'),
        ),
      );
      return;
    }

    final provider = context.read<TransactionProvider>();

    if (widget.transaction == null) {
      // โหมดเพิ่ม
      await provider.addTransaction(
        title,
        amount,
        _selectedDate,
        _selectedType,
      );
    } else {
      // โหมดแก้ไข
      final newTx = MyTransaction(
        title: title,
        amount: amount,
        date: _selectedDate,
        type: _selectedType,
      );
      await provider.updateTransaction(widget.transaction!.id!, newTx);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'แก้ไขรายการ' : 'เพิ่มรายการ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'ชื่อรายการ'),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'จำนวนเงิน'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'วันที่: ${DateFormat.yMMMd().format(_selectedDate)}',
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('เลือกวันที่'),
                ),
              ],
            ),
            Row(
              children: [
                const Text('ประเภท: '),
                const SizedBox(width: 12),
                DropdownButton<TransactionType>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(
                      value: TransactionType.income,
                      child: Text('รายรับ'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.expense,
                      child: Text('รายจ่าย'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(isEdit ? 'บันทึกการแก้ไข' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}
