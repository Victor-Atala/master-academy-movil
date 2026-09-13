import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';

enum DownloadDestinationType {
  downloads,
  documents,
  appStorage,
}

class DownloadDestinationModal extends StatefulWidget {
  final String fileName;
  final String fileTitle;
  final String fileType;
  final Uint8List? fileBytes;
  final String? textContent;

  const DownloadDestinationModal({
    super.key,
    required this.fileName,
    required this.fileTitle,
    this.fileType = 'PDF',
    this.fileBytes,
    this.textContent,
  });

  static Future<String?> show(
    BuildContext context, {
    required String fileName,
    required String fileTitle,
    String fileType = 'PDF',
    Uint8List? fileBytes,
    String? textContent,
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final isPdf = fileType.toLowerCase().contains('pdf') || sanitizedName.toLowerCase().endsWith('.pdf');
      final mimeType = isPdf ? 'application/pdf' : 'text/plain';

      // 1. Preparar los bytes del archivo (soporte de PDF estándar)
      final Uint8List bytes;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        bytes = fileBytes;
      } else if (isPdf) {
        bytes = _generatePdfBytes(
          textContent ??
              'MASTER ACADEMY\n$fileTitle\nFecha: ${DateTime.now().toString().split(".")[0]}\nDocumento oficial de acreditación.',
          title: fileTitle,
        );
      } else {
        bytes = Uint8List.fromList(
          utf8.encode(
            textContent ??
                'Master Academy - Archivo Oficial\nDocumento: $fileTitle\nGenerado el: ${DateTime.now().toIso8601String()}',
          ),
        );
      }

      // 2. Guardar en almacenamiento de caché temporal accesible por FileProvider
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$sanitizedName';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      // Guardar copia de respaldo en documentos internos de la app
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final docFile = File('${docDir.path}/$sanitizedName');
        await docFile.writeAsBytes(bytes, flush: true);
      } catch (_) {}

      // 3. Abrir el explorador de archivos nativo del teléfono ("Guardar en..." / ACTION_CREATE_DOCUMENT)
      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.masteracademy.app/file_downloader');
          final res = await platform.invokeMethod<String>('openFileManagerToSave', {
            'fileName': sanitizedName,
            'bytes': bytes,
            'mimeType': mimeType,
          });

          if (res == 'CANCELLED') {
            // El usuario canceló la selección en el explorador de archivos
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Guardado cancelado por el usuario'),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
            return null;
          }

          if (res != null && res.isNotEmpty) {
            if (context.mounted) _showSuccessFeedback(context, sanitizedName);
            return tempPath;
          }
        } on MissingPluginException {
          debugPrint('openFileManagerToSave: canal aún no disponible en compilación actual');
        } catch (e) {
          debugPrint('Error al invocar explorador nativo: $e');
        }
      }

      // 4. Selector del sistema como alternativa
      Rect? sharePositionOrigin;
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
        }
      }

      await Share.shareXFiles(
        [
          XFile(
            tempPath,
            mimeType: mimeType,
            name: sanitizedName,
          ),
        ],
        text: fileTitle,
        subject: fileTitle,
        sharePositionOrigin: sharePositionOrigin,
      );

      return tempPath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar archivo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return null;
    }
  }

  static void _showSuccessFeedback(BuildContext context, String sanitizedName) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Archivo guardado exitosamente en la carpeta seleccionada ($sanitizedName)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Uint8List _generatePdfBytes(String text, {String title = 'Master Academy'}) {
    final lines = text.split('\n');
    final streamBuffer = StringBuffer();
    streamBuffer.writeln('BT');
    streamBuffer.writeln('/F1 12 Tf');
    streamBuffer.writeln('50 740 Td');
    streamBuffer.writeln('16 TL');
    for (final l in lines) {
      final clean = l.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
      streamBuffer.writeln('($clean) Tj');
      streamBuffer.writeln('T*');
    }
    streamBuffer.writeln('ET');
    final streamBytes = utf8.encode(streamBuffer.toString());

    const obj1 = '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n';
    const obj2 = '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n';
    const obj3 = '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n';
    const obj4 = '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n';
    final obj5Header = '5 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n';
    const obj5Footer = '\nendstream\nendobj\n';

    const header = '%PDF-1.4\n';
    final offsets = <int>[];
    var pos = header.length;

    offsets.add(pos);
    pos += obj1.length;

    offsets.add(pos);
    pos += obj2.length;

    offsets.add(pos);
    pos += obj3.length;

    offsets.add(pos);
    pos += obj4.length;

    offsets.add(pos);
    pos += obj5Header.length + streamBytes.length + obj5Footer.length;

    final xrefOffset = pos;
    final xref = StringBuffer();
    xref.writeln('xref');
    xref.writeln('0 6');
    xref.writeln('0000000000 65535 f ');
    for (final off in offsets) {
      xref.writeln('${off.toString().padLeft(10, '0')} 00000 n ');
    }
    xref.writeln('trailer\n<< /Size 6 /Root 1 0 R >>');
    xref.writeln('startxref\n$xrefOffset\n%%EOF');

    final bb = BytesBuilder();
    bb.add(utf8.encode(header));
    bb.add(utf8.encode(obj1));
    bb.add(utf8.encode(obj2));
    bb.add(utf8.encode(obj3));
    bb.add(utf8.encode(obj4));
    bb.add(utf8.encode(obj5Header));
    bb.add(streamBytes);
    bb.add(utf8.encode(obj5Footer));
    bb.add(utf8.encode(xref.toString()));
    return bb.toBytes();
  }

  @override
  State<DownloadDestinationModal> createState() => _DownloadDestinationModalState();
}

class _DownloadDestinationModalState extends State<DownloadDestinationModal> {
  DownloadDestinationType _selectedType = DownloadDestinationType.downloads;
  bool _rememberChoice = false;
  bool _isSaving = false;

  Future<Directory> _resolveDirectory(DownloadDestinationType type) async {
    switch (type) {
      case DownloadDestinationType.downloads:
        final sysDownload = await getDownloadsDirectory();
        if (sysDownload != null) return sysDownload;
        return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();

      case DownloadDestinationType.documents:
        return await getApplicationDocumentsDirectory();

      case DownloadDestinationType.appStorage:
        return await getApplicationSupportDirectory();
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final targetDir = await _resolveDirectory(_selectedType);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Sanitizar el nombre del archivo
      final sanitizedName = widget.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetPath = '${targetDir.path}/$sanitizedName';
      final file = File(targetPath);

      if (widget.fileBytes != null && widget.fileBytes!.isNotEmpty) {
        await file.writeAsBytes(widget.fileBytes!, flush: true);
      } else {
        final content = widget.textContent ??
            'Master Academy - Archivo Oficial\nDocumento: ${widget.fileTitle}\nGenerado el: ${DateTime.now().toIso8601String()}';
        await file.writeAsString(content, flush: true);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, targetPath);

        final folderLabel = _selectedType == DownloadDestinationType.downloads
            ? 'Descargas'
            : (_selectedType == DownloadDestinationType.documents ? 'Documentos' : 'Almacenamiento Seguro');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Guardado en $folderLabel ($sanitizedName)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Compartir',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles(
                  [XFile(targetPath)],
                  text: 'Archivo descargado de Master Academy: ${widget.fileTitle}',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar archivo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle superior
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Dónde deseas guardar la descarga?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.fileType} • ${widget.fileName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? AppColors.darkBorder : AppColors.divider, height: 1),
            const SizedBox(height: 14),

            // Opciones de carpeta
            _buildFolderOption(
              type: DownloadDestinationType.downloads,
              icon: Icons.download_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Carpeta de Descargas (/Download)',
              subtitle: 'Recomendado. Visible en tu Administrador de Archivos y cualquier app.',
              isDark: isDark,
            ),
            _buildFolderOption(
              type: DownloadDestinationType.documents,
              icon: Icons.folder_special_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Carpeta de Documentos (/Documents)',
              subtitle: 'Ideal para archivar certificados y constancias oficiales.',
              isDark: isDark,
            ),
            _buildFolderOption(
              type: DownloadDestinationType.appStorage,
              icon: Icons.security_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Almacenamiento Seguro de la App',
              subtitle: 'Protegido dentro de Master Academy para consulta offline sin ocupar galería.',
              isDark: isDark,
            ),

            const SizedBox(height: 8),

            // Switch recordar elección
            InkWell(
              onTap: () => setState(() => _rememberChoice = !_rememberChoice),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    Checkbox(
                      value: _rememberChoice,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _rememberChoice = val ?? false),
                    ),
                    Text(
                      'Recordar mi elección para futuras descargas',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botón de confirmación de descarga
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.file_download_done_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Guardando en la carpeta seleccionada...' : 'Guardar Archivo Aquí',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderOption({
    required DownloadDestinationType type,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isSelected = _selectedType == type;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? iconColor.withOpacity(0.08)
            : (isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? iconColor : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? iconColor : (isDark ? Colors.white38 : Colors.grey.shade400),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
