import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/constants.dart';

/// Six display boxes over ONE real, invisible [TextField]. Screen readers
/// see a single labelled field (not six), paste and the OS one-time-code
/// autofill work, and there is no per-box focus logic to break on backspace.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    required this.label,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onCompleted;
  final bool enabled;

  static const int _length = 6;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final focus = isDark ? AppColors.ocean400 : theme.colorScheme.primary;

    return Semantics(
      label: label,
      textField: true,
      child: SizedBox(
        height: 60,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (final context, final value, final _) {
                  final text = value.text;
                  return Row(
                    children: [
                      for (var i = 0; i < _length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceHigh : Colors.white,
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(
                                color: i == text.length.clamp(0, _length - 1)
                                    ? focus
                                    : theme.colorScheme.outline,
                                width: i == text.length.clamp(0, _length - 1) ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              i < text.length ? text[i] : '',
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: controller,
                autofocus: true,
                enabled: enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                // Invisible: the boxes above are the visual.
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (final v) {
                  if (v.length == _length) onCompleted?.call();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
