import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/scan_providers.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: MotionFadeIn(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large camera icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                // Heading
                Text(
                  'Scan Your Receipt',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s12),

                // Subtitle
                Text(
                  'Take a photo of your receipt or bill to automatically extract details and categorize your expense.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s40),

                // Camera button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Gallery button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Choose from Gallery'),
                  ),
                ),

                const SizedBox(height: AppSpacing.s40),

                // Tips section
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips for best results:',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      _buildTip('Clear lighting with no glare'),
                      _buildTip('Entire receipt visible in frame'),
                      _buildTip('Receipt is flat, not folded'),
                      _buildTip('Text is clear and readable'),
                    ],
                  ),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(final String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (file != null) {
        await _processImage(file.path);
      }
    } on PlatformException catch (e) {
      _showPickerError(e, deniedMessage: 'Camera access is denied. Enable it in Settings to scan receipts.');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        await _processImage(file.path);
      }
    } on PlatformException catch (e) {
      _showPickerError(e, deniedMessage: 'Photo access is denied. Enable it in Settings to pick a receipt.');
    }
  }

  /// Surfaces an `image_picker` permission-denial (or other platform)
  /// failure as a snackbar - previously these calls had no error handling
  /// at all, so a denied camera/gallery permission failed completely
  /// silently with no feedback, indistinguishable from a frozen screen.
  void _showPickerError(final PlatformException e, {required final String deniedMessage}) {
    if (!mounted) return;
    final isDenied = e.code == 'camera_access_denied' || e.code == 'photo_access_denied';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDenied ? deniedMessage : 'Could not open the camera/gallery. Please try again.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _processImage(final String imagePath) async {
    // Show loading dialog
    if (!mounted) return;
    // Loading dialog is dismissed below via Navigator.pop, so we don't await it.
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (final ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    ));

    // Start OCR processing
    await ref.read(scanProvider.notifier).scanImage(imagePath);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      final scanState = ref.read(scanProvider);
      if (scanState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(scanState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else if (scanState.result != null) {
        // Navigate to result screen
        if (mounted) {
          await context.push('/scan/result');
        }
      }
    }
  }
}
