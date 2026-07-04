import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';

final exportServiceProvider = Provider<ExportService>((final ref) {
  return ExportService();
});
