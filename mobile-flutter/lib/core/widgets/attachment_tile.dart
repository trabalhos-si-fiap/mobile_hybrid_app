import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../features/tickets/domain/ticket_models.dart';
import '../api/api_exception.dart';
import '../app_services.dart';
import '../attachments/attachment_rules.dart';
import '../attachments/file_opener.dart';
import '../theme/app_colors.dart';
import 'image_viewer_screen.dart';

/// Anexo já enviado: imagem em miniatura (toque abre em tela cheia) ou PDF
/// (toque baixa e abre no app padrão do aparelho).
class AttachmentTile extends StatefulWidget {
  const AttachmentTile({super.key, required this.attachment});

  final Attachment attachment;

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  Future<Uint8List>? _image;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) {
      _image = AppScope.of(context).attachments.load(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.attachment.isImage ? _buildImage() : _buildFile();

  Widget _buildImage() => Semantics(
    button: true,
    label: 'Imagem ${widget.attachment.fileName}',
    excludeSemantics: true,
    child: InkWell(
      onTap: _openImage,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 88,
          height: 88,
          child: FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes != null) {
                return Image.memory(
                  bytes,
                  cacheWidth: (88 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const _Placeholder(Icons.broken_image_outlined),
                );
              }
              return _Placeholder(
                snapshot.hasError
                    ? Icons.broken_image_outlined
                    : Icons.image_outlined,
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _buildFile() {
    final attachment = widget.attachment;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _opening ? null : _openPdf,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.inputBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatBytes(attachment.sizeBytes),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_opening) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openImage() async {
    final services = AppScope.of(context);
    final future = services.attachments.load(widget.attachment);
    setState(() {
      _image = future;
    });
    try {
      final bytes = await future;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ImageViewerScreen(name: widget.attachment.fileName, bytes: bytes),
        ),
      );
    } on ApiException catch (error) {
      _showApiError(error);
    }
  }

  Future<void> _openPdf() async {
    final services = AppScope.of(context);
    setState(() => _opening = true);
    try {
      final bytes = await services.attachments.load(widget.attachment);
      await services.opener.openPdf(
        widget.attachment.id,
        widget.attachment.fileName,
        bytes,
      );
    } on ApiException catch (error) {
      _showApiError(error);
    } on OpenFileException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showApiError(ApiException error) {
    if (error.kind == ApiErrorKind.unauthorized) return;
    _showMessage(error.message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.imagePlaceholder,
    child: Center(child: Icon(icon, color: AppColors.textSecondary)),
  );
}
