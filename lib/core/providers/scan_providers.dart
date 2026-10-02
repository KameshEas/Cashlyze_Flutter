import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart';

import '../models/scanned_bill.dart';
import '../services/bill_ocr_service.dart';
import '../services/bill_parser_service.dart';
import '../services/merchant_categorizer_service.dart';
import '../utils/repo_error_handler.dart';

// OCR Service
final billOCRServiceProvider = Provider<BillOCRService>((final ref) {
  return BillOCRService();
});

// Bill Parser Service
final billParserServiceProvider = Provider<BillParserService>((final ref) {
  return BillParserService();
});

// Merchant Categorizer Service
final merchantCategorizerProvider = Provider<MerchantCategorizerService>((final ref) {
  return MerchantCategorizerService();
});

// Scanning state
class ScanState {

  ScanState({
    this.isProcessing = false,
    this.errorMessage,
    this.result,
  });
  final bool isProcessing;
  final String? errorMessage;
  final ScannedBill? result;

  ScanState copyWith({
    final bool? isProcessing,
    final String? errorMessage,
    final ScannedBill? result,
    final bool clearError = false,
  }) {
    return ScanState(
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      result: result ?? this.result,
    );
  }
}

class ScanNotifier extends Notifier<ScanState> {
  late BillOCRService ocrService;
  late BillParserService parserService;
  late MerchantCategorizerService categorizerService;

  @override
  ScanState build() {
    ocrService = ref.watch(billOCRServiceProvider);
    parserService = ref.watch(billParserServiceProvider);
    categorizerService = ref.watch(merchantCategorizerProvider);
    return ScanState();
  }

  Future<void> scanImage(final String imagePath) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      // Extract text from image
      final ocrText = await ocrService.extractTextFromImage(imagePath);

      // Parse text into bill data
      final bill = parserService.parseBillText(ocrText);

      // Categorize based on merchant
      final categorizedBill = categorizerService.categorize(bill);

      // Save image locally and get attachment path
      final attachmentPath = await _saveReceiptImage(imagePath);
      final billWithAttachment = categorizedBill.copyWith(attachmentPath: attachmentPath);

      state = state.copyWith(
        isProcessing: false,
        result: billWithAttachment,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: repoErrorMessage(e),
      );
    }
  }

  Future<String?> _saveReceiptImage(final String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${appDir.path}/receipts');
      // ignore: avoid_slow_async_io
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(sourcePath).copy('${receiptsDir.path}/$fileName');
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  void reset() {
    state = ScanState();
  }

  void updateBill(final ScannedBill bill) {
    state = state.copyWith(result: bill);
  }
}

final scanProvider = NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);
