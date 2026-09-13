import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/syllabus.dart';
import 'download_destination_modal.dart';

class ResourceViewerModal extends StatefulWidget {
  final LessonResource resource;
  final String lessonTitle;
  final bool isDark;

  const ResourceViewerModal({
    super.key,
    required this.resource,
    required this.lessonTitle,
    required this.isDark,
  });

  static void show(BuildContext context, LessonResource resource, {String lessonTitle = 'Clase'}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResourceViewerModal(
        resource: resource,
        lessonTitle: lessonTitle,
        isDark: isDark,
      ),
    );
  }

  @override
  State<ResourceViewerModal> createState() => _ResourceViewerModalState();
}

class _ResourceViewerModalState extends State<ResourceViewerModal> {
  int _currentPdfPage = 1;
  final int _totalPdfPages = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final res = widget.resource;
    final type = (res.fileType ?? '').toLowerCase();

    IconData headerIcon = Icons.description_rounded;
    Color headerColor = AppColors.primary;
    String badgeText = 'DOCUMENTO';

    if (type.contains('pdf')) {
      headerIcon = Icons.picture_as_pdf_rounded;
      headerColor = const Color(0xFFEF4444);
      badgeText = 'GUÍA PDF INTERACTIVA';
    } else if (type.contains('xls') || type.contains('sheet')) {
      headerIcon = Icons.table_chart_rounded;
      headerColor = const Color(0xFF10B981);
      badgeText = 'HOJA DE CÁLCULO EXCEL';
    } else if (type.contains('zip') || type.contains('rar')) {
      headerIcon = Icons.folder_zip_rounded;
      headerColor = const Color(0xFFF59E0B);
      badgeText = 'PAQUETE DE RECURSOS';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(headerIcon, color: headerColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: headerColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: headerColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        res.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Compartir',
                  onPressed: () {
                    Share.share(
                      '📄 Material de apoyo: "${res.title}" de la lección "${widget.lessonTitle}" en Master Academy.',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Viewer Body
          Expanded(
            child: type.contains('pdf')
                ? _buildPdfViewer(isDark)
                : (type.contains('xls') || type.contains('sheet'))
                    ? _buildExcelViewer(isDark)
                    : _buildZipViewer(isDark),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Cerrar Visor', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        DownloadDestinationModal.show(
                          context,
                          fileName: '${res.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.${res.fileType?.toLowerCase() == 'pdf' ? 'pdf' : (res.fileType?.toLowerCase() ?? 'pdf')}',
                          fileTitle: res.title,
                          fileType: res.fileType?.toUpperCase() ?? 'PDF',
                          textContent: '===================================================\n'
                              'MASTER ACADEMY - MATERIAL DE APOYO\n'
                              '===================================================\n\n'
                              'Material: ${res.title}\n'
                              'Clase: ${widget.lessonTitle}\n'
                              'Tipo: ${res.fileType ?? "PDF"}\n'
                              'URL de consulta: ${res.fileUrl ?? "Local"}\n\n'
                              'Contenido del recurso educativo proporcionado por Master Academy.\n'
                              'Todos los derechos reservados.',
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Descargar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer(bool isDark) {
    final pagesContent = [
      {
        'title': '1. Resumen Ejecutivo y Metodología',
        'content': 'Esta guía cubre la arquitectura de seguridad y mitigación de riesgos operativos. Cada módulo está diseñado para alinear las políticas internas con el marco de cumplimiento internacional ISO 27001.\n\n• Diagnóstico inicial de vulnerabilidades\n• Definición de matrices de criticidad\n• Protocolos de respuesta rápida ante incidentes',
      },
      {
        'title': '2. Parámetros Técnicos y Configuración',
        'content': 'Para desplegar las medidas requeridas en el entorno de producción:\n\n1. Validar la configuración del firewall perimetral.\n2. Establecer directivas de autenticación multifactor en todos los accesos administrativos.\n3. Segmentar redes operativas de las redes de uso corporativo general.\n4. Realizar pruebas de penetración trimestrales.',
      },
      {
        'title': '3. Monitoreo, Auditoría y KPIs',
        'content': 'Métricas clave de evaluación continua:\n\n• Tiempo medio de detección (MTTD): < 15 min\n• Tiempo medio de remediación (MTTR): < 1 hora\n• Cobertura de parches de seguridad críticos: 99.5%\n• Tasa de incidentes mitigados en capa perimetral: 98%',
      },
      {
        'title': '4. Checklist de Validación Final',
        'content': 'Puntos de verificación antes de finalizar la lección:\n\n[✓] Roles de acceso con privilegios mínimos aplicados.\n[✓] Registro de logs centralizado en servidor inmutable.\n[✓] Notificaciones de alerta automáticas configuradas.\n[✓] Plan de continuidad de negocio (BCP) actualizado.',
      },
    ];

    final page = pagesContent[_currentPdfPage - 1];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pagination Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Página $_currentPdfPage de $_totalPdfPages',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _currentPdfPage > 1 ? () => setState(() => _currentPdfPage--) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _currentPdfPage < _totalPdfPages ? () => setState(() => _currentPdfPage++) : null,
                  ),
                ],
              ),
            ],
          ),

          // Rendered Digital Page Canvas
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page['title']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: isDark ? AppColors.darkBorder : AppColors.divider),
                    const SizedBox(height: 12),
                    Text(
                      page['content']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelViewer(bool isDark) {
    final rows = [
      {'item': '01', 'cat': 'Seguridad', 'desc': 'Auditoría de Políticas', 'estado': 'Completado', 'val': '100%'},
      {'item': '02', 'cat': 'Redes', 'desc': 'Aislamiento de VLAN', 'estado': 'En Progreso', 'val': '75%'},
      {'item': '03', 'cat': 'Accesos', 'desc': 'Revisión MFA en VPN', 'estado': 'Completado', 'val': '100%'},
      {'item': '04', 'cat': 'Backups', 'desc': 'Respaldo Cifrado Diario', 'estado': 'Verificado', 'val': '100%'},
      {'item': '05', 'cat': 'Incidentes', 'desc': 'Simulacro de Contingencia', 'estado': 'Pendiente', 'val': '0%'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_view_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                'Plantilla de Evaluación y Métricas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
              ),
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Avance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: rows.map((r) {
                final isDone = r['estado'] == 'Completado' || r['estado'] == 'Verificado';
                return DataRow(
                  cells: [
                    DataCell(Text(r['item']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataCell(Text(r['cat']!, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(r['desc']!, style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDone ? const Color(0xFF10B981) : Colors.orange).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r['estado']!,
                          style: TextStyle(
                            color: isDone ? const Color(0xFF10B981) : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(r['val']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZipViewer(bool isDark) {
    final files = [
      {'name': 'diagrama_arquitectura_v2.png', 'size': '2.4 MB', 'icon': Icons.image_rounded},
      {'name': 'checklist_auditoria_seguridad.pdf', 'size': '1.1 MB', 'icon': Icons.picture_as_pdf_rounded},
      {'name': 'plantilla_matriz_riesgos.xlsx', 'size': '850 KB', 'icon': Icons.table_chart_rounded},
      {'name': 'scripts_automatizacion_bash.sh', 'size': '45 KB', 'icon': Icons.code_rounded},
      {'name': 'guia_rapida_incidentes.md', 'size': '18 KB', 'icon': Icons.article_rounded},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, idx) {
        final f = files[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF59E0B).withOpacity(0.15),
              child: Icon(f['icon'] as IconData, color: const Color(0xFFF59E0B), size: 20),
            ),
            title: Text(
              f['name'] as String,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            subtitle: Text('Tamaño: ${f['size']}'),
            trailing: IconButton(
              icon: const Icon(Icons.remove_red_eye_outlined, size: 20, color: AppColors.primary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Visualizando elemento: ${f['name']}')),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
