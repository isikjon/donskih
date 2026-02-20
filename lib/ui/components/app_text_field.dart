import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Минималистичное текстовое поле
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.validator,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTypography.labelLarge),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscureText,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          style: AppTypography.bodyLarge,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppColors.textTertiary, size: 22)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}

/// Поле поиска
class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    super.key,
    this.controller,
    this.hint = 'Поиск',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_outlined, color: AppColors.textTertiary, size: 22),
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
