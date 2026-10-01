import 'package:flutter/material.dart';

import '../attachments/attachment_rules.dart';
import '../attachments/picked_attachment.dart';
import '../theme/app_colors.dart';

/// Anexo escolhido e ainda não enviado.
class PickedAttachmentTile extends StatelessWidget {
  const PickedAttachmentTile({
    super.key,
    required this.file,
    required this.onRemove,
  });

  final PickedAttachment file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: file.isImage
                  ? Image.memory(
                      file.bytes,
                      cacheWidth: (40 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    )
                  : const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.danger,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatBytes(file.size),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover ${file.name}',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    ),
  );
}
