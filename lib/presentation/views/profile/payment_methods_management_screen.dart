import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../viewmodels/theme_viewmodel.dart';

class PaymentMethodsManagementScreen extends StatefulWidget {
  const PaymentMethodsManagementScreen({super.key});

  @override
  State<PaymentMethodsManagementScreen> createState() => _PaymentMethodsManagementScreenState();
}

class _PaymentMethodsManagementScreenState extends State<PaymentMethodsManagementScreen> {
  List<Map<String, dynamic>> _savedCards = [
    {
      'type': 'Visa',
      'last4': '4242',
      'expiry': '12/28',
      'holder': 'JUAN CARLOS RAMIREZ',
      'isDefault': true,
      'color': const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    },
    {
      'type': 'Mastercard',
      'last4': '8891',
      'expiry': '09/27',
      'holder': 'JUAN CARLOS RAMIREZ',
      'isDefault': false,
      'color': const [Color(0xFF0F172A), Color(0xFF334155)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    try {
      final storage = sl<FlutterSecureStorage>();
      final raw = await storage.read(key: 'user_saved_payment_cards');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final loaded = decoded.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final colorValues = (map['colorValues'] as List?)?.cast<int>() ?? [0xFF0D9488, 0xFF14B8A6];
          return {
            'type': map['type'] ?? 'Visa',
            'last4': map['last4'] ?? '1234',
            'expiry': map['expiry'] ?? '12/29',
            'holder': map['holder'] ?? 'ESTUDIANTE',
            'isDefault': map['isDefault'] ?? false,
            'color': colorValues.map((v) => Color(v)).toList(),
          };
        }).toList();

        if (mounted && loaded.isNotEmpty) {
          setState(() {
            _savedCards = loaded;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSavedCards() async {
    try {
      final storage = sl<FlutterSecureStorage>();
      final serializable = _savedCards.map((c) {
        final colors = c['color'] as List<Color>;
        return {
          'type': c['type'],
          'last4': c['last4'],
          'expiry': c['expiry'],
          'holder': c['holder'],
          'isDefault': c['isDefault'],
          'colorValues': colors.map((col) => col.value).toList(),
        };
      }).toList();
      await storage.write(
        key: 'user_saved_payment_cards',
        value: jsonEncode(serializable),
      );
    } catch (_) {}
  }

  void _showAddCardModal(bool isDark) async {
    final cardNumberCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();
    final holderCtrl = TextEditingController();

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Agregar Nueva Tarjeta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cardNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de Tarjeta',
                    hintText: '0000 0000 0000 0000',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expiryCtrl,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'MM/AA',
                          hintText: '12/28',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: cvvCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Titular de la Tarjeta',
                    hintText: 'NOMBRE COMO APARECE EN LA TARJETA',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (cardNumberCtrl.text.isNotEmpty) {
                        setState(() {
                          _savedCards.add({
                            'type': 'Visa',
                            'last4': cardNumberCtrl.text.length >= 4
                                ? cardNumberCtrl.text.substring(cardNumberCtrl.text.length - 4)
                                : '1234',
                            'expiry': expiryCtrl.text.isNotEmpty ? expiryCtrl.text : '12/29',
                            'holder': holderCtrl.text.isNotEmpty ? holderCtrl.text.toUpperCase() : 'ESTUDIANTE',
                            'isDefault': false,
                            'color': const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                          });
                        });
                        await _saveSavedCards();
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tarjeta guardada exitosamente'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: const Text('Guardar Tarjeta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      cardNumberCtrl.dispose();
      expiryCtrl.dispose();
      cvvCtrl.dispose();
      holderCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeViewModel>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Métodos de Pago',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus Tarjetas Guardadas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddCardModal(isDark),
                icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                label: const Text(
                  'Nueva',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_savedCards.length, (index) {
            final card = _savedCards[index];
            final isDefault = card['isDefault'] as bool;
            final gradientColors = card['color'] as List<Color>;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        card['type'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PREDETERMINADA',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '•••• •••• •••• ${card['last4']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TITULAR', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                          Text(card['holder'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('EXPIRA', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                          Text(card['expiry'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Historial de Facturación',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptTile('Curso Especialidad Flutter Pro', '28 Ago 2026', '\$1,299 MXN', isDark),
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.divider),
                _buildReceiptTile('Membresía Anual Master Academy', '15 Jul 2026', '\$2,499 MXN', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTile(String title, String date, String amount, bool isDark) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary)),
      subtitle: Text(date, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF10B981))),
          const SizedBox(width: 8),
          const Icon(Icons.download_rounded, size: 18, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}
