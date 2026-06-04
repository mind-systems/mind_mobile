import 'package:flutter/material.dart';
import 'package:mind_l10n/mind_l10n.dart';

class MeditationNoteScreen extends StatefulWidget {
  const MeditationNoteScreen({super.key});

  @override
  State<MeditationNoteScreen> createState() => _MeditationNoteScreenState();
}

class _MeditationNoteScreenState extends State<MeditationNoteScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.meditationNotePrompt,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor?.withValues(alpha: 0.5),
                    ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_controller.text),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
