import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class BillOCRService {
  late final TextRecognizer _textRecognizer;

  BillOCRService() {
    _textRecognizer = TextRecognizer();
  }

  Future<String> extractTextFromImage(String imagePath) async {
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
  final String message;
  OCRException(this.message);
  
  @override
  String toString() => message;
}
