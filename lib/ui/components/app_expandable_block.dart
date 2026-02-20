import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

class AppExpandableBlock extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final IconData expandedIcon;
  final IconData collapsedIcon;
  final Widget? preview;
  final Widget? trailing;

  const AppExpandableBlock({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.expandedIcon = Icons.remove_circle_outline,
    this.collapsedIcon = Icons.add_circle_outline,
    this.preview,
    this.trailing,
  });

  @override
  State<AppExpandableBlock> createState() => _AppExpandableBlockState();
}

class _AppExpandableBlockState extends State<AppExpandableBlock>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                if (widget.preview != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 48, height: 48, child: widget.preview!),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(widget.icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(widget.title, style: AppTypography.titleMedium),
                ),
                if (widget.trailing != null) widget.trailing!,
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? widget.expandedIcon : widget.collapsedIcon,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _animation,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: widget.content,
          ),
        ),
      ],
    );
  }
}
