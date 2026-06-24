import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/sync/pos_v2_customer_service.dart';
import '../../../../l10n/app_localizations.dart';

Future<PosCustomerRecord?> showCustomerPickerDialog(
  BuildContext context, {
  PosCustomerRecord? initiallySelected,
}) {
  return showDialog<PosCustomerRecord>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CustomerPickerDialog(initiallySelected: initiallySelected),
  );
}

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({this.initiallySelected});

  final PosCustomerRecord? initiallySelected;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _searchController = TextEditingController();
  final _createNameController = TextEditingController();
  final _createPhoneController = TextEditingController();
  final _createAddressController = TextEditingController();

  Timer? _searchDebounce;
  bool _isSearching = false;
  bool _isCreating = false;
  bool _showCreateForm = false;
  String? _errorMessage;
  List<PosCustomerRecord> _results = const <PosCustomerRecord>[];

  @override
  void initState() {
    super.initState();
    _createPhoneController.text = '-';
    _createAddressController.text = '-';
    _loadInitialResults();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _createNameController.dispose();
    _createPhoneController.dispose();
    _createAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialResults() async {
    final defaultCustomer = await PosV2CustomerService.instance
        .ensureDefaultWalkInCustomer();
    final results = await PosV2CustomerService.instance.searchLocal('');
    if (!mounted) {
      return;
    }
    setState(() {
      _results = _prependIfMissing(results, defaultCustomer);
    });
  }

  List<PosCustomerRecord> _prependIfMissing(
    List<PosCustomerRecord> source,
    PosCustomerRecord customer,
  ) {
    if (source.any((item) => item.remoteId == customer.remoteId)) {
      return source;
    }
    return <PosCustomerRecord>[customer, ...source];
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String rawValue) async {
    final query = rawValue.trim();
    setState(() {
      _isSearching = true;
      _showCreateForm = false;
      _errorMessage = null;
    });

    try {
      final localResults = await PosV2CustomerService.instance.searchLocal(
        query,
      );
      final remoteResults = query.length >= 2
          ? await PosV2CustomerService.instance.searchRemote(query)
          : const <PosCustomerRecord>[];

      final merged = <String, PosCustomerRecord>{};
      for (final customer in [...localResults, ...remoteResults]) {
        merged[customer.remoteId] = customer;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _results = merged.values.toList(growable: false);
        if (_results.isEmpty && query.isNotEmpty) {
          _showCreateForm = true;
          _createNameController.text = query;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _createCustomer() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isCreating) {
      return;
    }

    if (_createNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = l10n.customerNameRequiredMessage;
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final customer = await PosV2CustomerService.instance.createCustomer(
        name: _createNameController.text.trim(),
        phone: _createPhoneController.text.trim(),
        address: _createAddressController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(customer);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final searchQuery = _searchController.text.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 380,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showCreateForm
                          ? Colors.orange.withValues(alpha: 0.1)
                          : primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _showCreateForm
                          ? Icons.person_add_alt_1_rounded
                          : Icons.people_alt_rounded,
                      color: _showCreateForm ? Colors.orange : primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _showCreateForm
                          ? 'Tambah Pelanggan ✨'
                          : 'Cari Pelanggan 🔍',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.grey.shade400,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_showCreateForm) ...[
                // Search Field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Ketik nama atau no. telp...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),

                // Results or Empty State
                if (_results.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          searchQuery.isNotEmpty
                              ? Icons.person_search_rounded
                              : Icons.sentiment_dissatisfied_rounded,
                          size: 36,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Pelanggan tidak ditemukan.'
                              : 'Belum ada pelanggan.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showCreateForm = true;
                              if (searchQuery.isNotEmpty) {
                                _createNameController.text = searchQuery;
                              }
                            });
                          },
                          icon: const Icon(
                            Icons.add_reaction_rounded,
                            size: 16,
                          ),
                          label: Text(
                            searchQuery.isNotEmpty
                                ? 'Tambahkan "$searchQuery"'
                                : 'Buat Profil',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height:
                        250, // Fixed height for results list to keep dialog constrained
                    child: ListView.separated(
                      itemCount: _results.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == _results.length) {
                          return OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showCreateForm = true;
                                _createNameController.text = _searchController
                                    .text
                                    .trim();
                              });
                            },
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Buat Pelanggan Baru',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          );
                        }

                        final customer = _results[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(customer),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    customer.isDefaultWalkIn
                                        ? Icons.person_outline_rounded
                                        : Icons.person_rounded,
                                    color: primaryColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.isDefaultWalkIn
                                            ? AppLocalizations.of(
                                                context,
                                              )!.walkInCustomer
                                            : customer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if ((customer.phone ?? '').isNotEmpty)
                                        Text(
                                          customer.phone!,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      if ((customer.address ?? '').isNotEmpty)
                                        Text(
                                          customer.address!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ] else ...[
                // Add Form
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _createNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      labelStyle: const TextStyle(fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: 'Misal: John Doe',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _createPhoneController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'No. Telp',
                      labelStyle: const TextStyle(fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _createAddressController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Alamat',
                      labelStyle: const TextStyle(fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isCreating
                            ? null
                            : () {
                                setState(() {
                                  _showCreateForm = false;
                                  _errorMessage = null;
                                });
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Kembali',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Simpan & Gunakan ✨',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
