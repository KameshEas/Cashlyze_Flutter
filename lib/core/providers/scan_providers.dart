import 'package:riverpod/riverpod.dart';

import '../models/scanned_bill.dart';
import '../services/bill_ocr_service.dart';
import '../services/bill_parser_service.dart';
import '../services/merchant_categorizer_service.dart';

// OCR Service
final billOCRServiceProvider = Provider<BillOCRService>((ref) {
  return BillOCRService();
});

// Bill Parser Service
final billParserServiceProvider = Provider<BillParserService>((ref) {
  return BillParserService();
});

// Merchant Categorizer Service
final merchantCategorizerProvider = Provider<MerchantCategorizerService>((ref) {
  return MerchantCategorizerService();
});

// Scanning state
class ScanState {
  final bool isProcessing;
  final String? errorMessage;
  final ScannedBill? result;

  ScanState({
    this.isProcessing = false,
    this.errorMessage,
    this.result,
  });

  ScanState copyWith({
    bool? isProcessing,
    String? errorMessage,
    ScannedBill? result,
  }) {
    return ScanState(
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage ?? this.errorMessage,
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

  Future<void> scanImage(String imagePath) async {
    state = state.copyWith(isProcessing: true);
    
    try {
      // Extract text from image
      final ocrText = await ocrService.extractTextFromImage(imagePath);
      
      // Parse text into bill data
      final bill = parserService.parseBillText(ocrText);
      
      // Categorize based on merchant
      final categorizedBill = categorizerService.categorize(bill);
      
      state = state.copyWith(
        isProcessing: false,
        result: categorizedBill,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to scan bill: ${e.toString()}',
      );
    }
  }

  void reset() {
    state = ScanState();
  }

  void updateBill(ScannedBill bill) {
    state = state.copyWith(result: bill);
  }
}

final scanProvider = NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);
