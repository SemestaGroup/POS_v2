import 'package:flutter/material.dart';

import '../../../../../core/services/sync/pos_v2_customer_service.dart';
import '../../../stores/master_data_read_stores.dart';

class EditCustomerDialog extends StatefulWidget {
  const EditCustomerDialog({
    required this.customer,
    super.key,
  });

  final CustomerListRecord customer;

  static Future<CustomerListRecord?> show(
    BuildContext context, {
    required CustomerListRecord customer,
  }) {
    return showDialog<CustomerListRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditCustomerDialog(customer: customer),
    );
  }

  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _emailController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.displayName);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber ?? '');
    _addressController = TextEditingController(text: widget.customer.address ?? '');
    _emailController = TextEditingController(text: widget.customer.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedName = _nameController.text.trim();
      final updatedPhone = _phoneController.text.trim();
      final updatedAddress = _addressController.text.trim();
      final updatedEmail = _emailController.text.trim();

      await PosV2CustomerService.instance.updateCustomer(
        localId: widget.customer.id,
        name: updatedName,
        phone: updatedPhone.isNotEmpty ? updatedPhone : null,
        address: updatedAddress.isNotEmpty ? updatedAddress : null,
        email: updatedEmail.isNotEmpty ? updatedEmail : null,
      );

      final updatedRecord = CustomerListRecord(
        id: widget.customer.id,
        remoteId: widget.customer.remoteId,
        displayName: updatedName,
        phoneNumber: updatedPhone.isNotEmpty ? updatedPhone : null,
        address: updatedAddress.isNotEmpty ? updatedAddress : null,
        email: updatedEmail.isNotEmpty ? updatedEmail : null,
        city: widget.customer.city,
        pointsBalance: widget.customer.pointsBalance,
      );

      // Refresh CustomerListStore
      CustomerListStore.instance.refresh();

      if (mounted) {
        Navigator.of(context).pop(updatedRecord);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Profil Pelanggan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Perbarui informasi kontak dan data pelanggan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Nama
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap / Perusahaan *',
                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Nomor Telepon
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor Telepon / WhatsApp',
                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                // Email
                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                // Alamat
                TextFormField(
                  controller: _addressController,
                  enabled: !_isSubmitting,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Alamat',
                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Batal',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
