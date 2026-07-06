import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction.dart';
import '../utils/format.dart';

class ExportService {
  Future<String> generateTransactionsCSV(
    final List<TransactionModel> transactions,
    final String currency,
  ) async {
    final csvData = <List<String>>[
      ['Date', 'Title', 'Category', 'Amount', 'Type', 'Tags'],
      ...transactions.map((final t) => [
        DateFormat('yyyy-MM-dd').format(t.date),
        t.title,
        t.categoryName ?? 'General',
        t.amount.toString(),
        t.amount > 0 ? 'Income' : 'Expense',
        t.tags?.join(', ') ?? '',
      ]),
    ];
    final csv = const ListToCsvConverter().convert(csvData);
    return csv;
  }

  Future<File> saveTransactionsCSV(
    final List<TransactionModel> transactions,
    final String currency,
  ) async {
    final csv = await generateTransactionsCSV(transactions, currency);
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);
    return file;
  }

  Future<File> generateInsightsPDF(
    final Map<String, double> categoryBreakdown,
    final double totalIncome,
    final double totalExpense,
    final double savings,
    final String currency,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (final context) => [
          pw.Center(
            child: pw.Text(
              'Spending Insights',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Income',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(formatAmount(totalIncome, currency)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Total Expense',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(formatAmount(totalExpense, currency)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Net Savings',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(formatAmount(savings, currency)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Category Breakdown',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Category',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Percentage',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...categoryBreakdown.entries.map((final e) {
                final total = categoryBreakdown.values.fold<double>(
                    0, (final sum, final value) => sum + value);
                final pct = total > 0 ? (e.value / total * 100) : 0.0;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(e.key),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(formatAmount(e.value, currency)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${pct.toStringAsFixed(1)}%'),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'insights_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
