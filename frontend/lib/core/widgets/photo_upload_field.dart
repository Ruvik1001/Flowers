import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/core/widgets/app_message.dart';

/// Picks images and uploads them via files service. Exposes uploaded file ids.
class PhotoUploadField extends StatefulWidget {
  const PhotoUploadField({
    super.key,
    required this.fileIds,
    required this.onChanged,
    this.minCount = 1,
    this.maxCount = 10,
    this.label = 'Фото',
  });

  final List<String> fileIds;
  final ValueChanged<List<String>> onChanged;
  final int minCount;
  final int maxCount;
  final String label;

  @override
  State<PhotoUploadField> createState() => _PhotoUploadFieldState();
}

class _PhotoUploadFieldState extends State<PhotoUploadField> {
  final _names = <String, String>{};
  bool _busy = false;

  Future<void> _pick() async {
    if (widget.fileIds.length >= widget.maxCount) {
      AppMessage.showError(
        context,
        'Можно приложить не больше ${widget.maxCount} фото',
      );
      return;
    }
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      imageQuality: 85,
      limit: widget.maxCount - widget.fileIds.length,
    );
    if (files.isEmpty) return;

    setState(() => _busy = true);
    final next = List<String>.from(widget.fileIds);
    try {
      for (final file in files) {
        if (next.length >= widget.maxCount) break;
        final bytes = await file.readAsBytes();
        final meta = await Di.I.files.upload(
          bytes: bytes,
          filename: file.name.isEmpty ? 'photo.jpg' : file.name,
        );
        next.add(meta.id);
        _names[meta.id] = meta.originalName;
      }
      widget.onChanged(next);
    } on AppFailure catch (e) {
      if (mounted) AppMessage.showError(context, e.message);
    } catch (e) {
      if (mounted) {
        AppMessage.showError(context, 'Не удалось загрузить фото');
      }
      if (kDebugMode) {
        debugPrint('photo upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(String id) {
    final next = List<String>.from(widget.fileIds)..remove(id);
    _names.remove(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (widget.fileIds.isEmpty)
          Text(
            'Нужно от ${widget.minCount} до ${widget.maxCount} фото',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (final id in widget.fileIds)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: Text(_names[id] ?? 'Фото'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => _remove(id),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined),
          label: Text(_busy ? 'Загрузка…' : 'Добавить фото'),
        ),
      ],
    );
  }
}
