import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/providers.dart';
import 'admin_widgets.dart';

/// Image field that can either take a pasted URL or upload a file from the
/// computer. Uploading fills the URL in, so the form still saves a plain URL.
class ImageUrlField extends ConsumerStatefulWidget {
  const ImageUrlField({
    super.key,
    required this.controller,
    required this.label,
    this.folder = 'catalog',
  });

  final TextEditingController controller;
  final String label;
  final String folder;

  @override
  ConsumerState<ImageUrlField> createState() => _ImageUrlFieldState();
}

class _ImageUrlFieldState extends ConsumerState<ImageUrlField> {
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Keep the preview in step when a URL is typed or pasted.
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _upload() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ref.read(apiProvider).uploadImage(
            await picked.readAsBytes(),
            fileName: picked.name,
            folder: widget.folder,
          );
      widget.controller.text = url;
      if (mounted) AdminSnack.success(context, 'Image uploaded');
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = widget.controller.text.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            color: theme.colorScheme.surfaceContainerHighest,
            child: url.isEmpty
                ? Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Icon(Icons.broken_image_outlined, color: theme.colorScheme.error),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Upload'),
          ),
        ),
      ],
    );
  }
}
