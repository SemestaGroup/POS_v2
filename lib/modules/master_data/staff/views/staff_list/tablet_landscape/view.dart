import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/master_data_page_widgets.dart';
import '../../../../stores/master_data_read_stores.dart';

class StaffListView extends StatefulWidget {
  const StaffListView({super.key});

  @override
  State<StaffListView> createState() => _StaffListViewState();
}

class _StaffListViewState extends State<StaffListView> {
  final StaffListStore _store = StaffListStore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _StaffStrings.of(context);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<MasterDataListSnapshot<StaffListRecord>>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final records = snapshot.records;
        final activeCount = records.where((staff) => staff.isActive).length;

        if (snapshot.isLoading && snapshot.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.records.isEmpty) {
          return MasterDataErrorView(message: snapshot.errorMessage!);
        }

        return Column(
          children: [
            MasterDataSearchHeader(
              searchController: _searchController,
              searchHint: strings.searchHint,
              onSearchChanged: _store.setSearchQuery,
              countText:
                  '${records.length} ${strings.countLabel} • $activeCount ${strings.activeLabel}',
              onRefresh: _store.refresh,
              filterBar: _buildFilterBar(),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: records.isEmpty
                  ? MasterDataEmptyState(
                      icon: Icons.badge_outlined,
                      title: strings.emptyState,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final staff = records[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    staff.fullName.isNotEmpty
                                        ? staff.fullName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.fullName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      (staff.email ?? '').trim().isEmpty
                                          ? '—'
                                          : staff.email!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B7280),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  staff.roleName ?? staff.roleCode ?? '—',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  (staff.phoneNumber ?? '').trim().isEmpty
                                      ? '—'
                                      : staff.phoneNumber!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  staff.lastLoginAt != null
                                      ? dateFmt.format(staff.lastLoginAt!)
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              MasterDataStatusBadge(
                                label: staff.isActive
                                    ? strings.activeStatus
                                    : strings.inactiveStatus,
                                foreground: staff.isActive
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF6B7280),
                                background: staff.isActive
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF3F4F6),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        _buildDropdown<String>(
          hint: 'Semua Peran (Role)',
          value: _store.roleCode,
          items: const [
            DropdownMenuItem(value: null, child: Text('Semua Peran (Role)')),
            DropdownMenuItem(value: 'owner', child: Text('Owner')),
            DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
            DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
            DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
          ],
          onChanged: (val) {
            _store.setRoleCode(val);
            setState((){});
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          isDense: true,
        ),
      ),
    );
  }
}

class _StaffStrings {
  const _StaffStrings({required this.id});

  final bool id;

  static _StaffStrings of(BuildContext context) {
    return _StaffStrings(
      id: Localizations.localeOf(context).languageCode == 'id',
    );
  }

  String get searchHint => id
      ? 'Cari nama staf, email, atau peran...'
      : 'Search staff name, email, or role...';
  String get countLabel => id ? 'staf' : 'staff';
  String get activeLabel => id ? 'aktif' : 'active';
  String get emptyState =>
      id ? 'Tidak ada data staf.' : 'No staff records available.';
  String get activeStatus => id ? 'Aktif' : 'Active';
  String get inactiveStatus => id ? 'Nonaktif' : 'Inactive';
}
