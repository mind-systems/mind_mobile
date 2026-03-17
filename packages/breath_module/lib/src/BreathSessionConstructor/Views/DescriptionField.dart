import 'package:flutter/material.dart';

class DescriptionField extends StatefulWidget {
  const DescriptionField({super.key, required this.description, required this.onChanged});

  final String description;
  final ValueChanged<String> onChanged;

  @override
  State<DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<DescriptionField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.description)
      ..selection = TextSelection.collapsed(offset: widget.description.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.next,
            onChanged: widget.onChanged,
            style: TextStyle(
              color: onSurface,
              fontSize: 16,
              height: 1.2,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ),
    );
  }
}
