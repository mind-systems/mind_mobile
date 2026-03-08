import 'package:flutter/material.dart';

class SettingsEditableCell extends StatefulWidget {
  final String title;
  final String? value;
  final ValueChanged<String>? onSave;

  const SettingsEditableCell({
    super.key,
    required this.title,
    this.value,
    this.onSave,
  });

  @override
  State<SettingsEditableCell> createState() => _SettingsEditableCellState();
}

class _SettingsEditableCellState extends State<SettingsEditableCell> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    setState(() => _focused = hasFocus);
    if (!hasFocus) {
      _save();
    }
  }

  void _save() {
    final text = _controller.text;
    if (text != (widget.value ?? '')) {
      widget.onSave?.call(text);
    }
  }

  @override
  void didUpdateWidget(SettingsEditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            widget.title,
            style: TextStyle(fontSize: 16, color: onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.6)),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: _focused
                    ? UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: onSurface.withValues(alpha: 0.3),
                        ),
                      )
                    : InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _focusNode.unfocus(),
            ),
          ),
        ],
      ),
    );
  }
}
