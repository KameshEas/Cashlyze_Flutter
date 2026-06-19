import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class BillOCRService {

  BillOCRService() {
    _textRecognizer = TextRecognizer();
  }
  late final TextRecognizer _textRecognizer;

  Future<String> extractTextFromImage(final String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String extractedText = '';
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      return extractedText;
    } catch (e) {
      throw OCRException('Failed to extract text: $e');
    }
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

class OCRException implements Exception {
  OCRException(this.message);
  final String message;

  @override
  String toString() => message;
}
