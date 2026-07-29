import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Data for a menu card in a mobile section list.
class MobileMenuItem {
  const MobileMenuItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackground,
    this.iconColor,
    this.view,
    this.trailing,
    this.onTap,
  }) : assert(view != null || onTap != null);

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconBackground;
  final Color? iconColor;
  final Widget? view;
  final Widget? trailing;
  final VoidCallback? onTap;
}

class MobileMenuGroup {
  const MobileMenuGroup({required this.label, required this.items});

  final String label;
  final List<MobileMenuItem> items;
}

class MobileMenuListPage extends StatelessWidget {
  const MobileMenuListPage({
    super.key,
    required this.title,
    required this.groups,
  });

  final String title;
  final List<MobileMenuGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1D2E),
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
            if (groups[groupIndex].items.isNotEmpty) ...[
              if (groupIndex > 0) const SizedBox(height: 16),
              _SectionLabel(label: groups[groupIndex].label),
              ...groups[groupIndex].items.map(
                (item) => MobileMenuCard(item: item),
              ),
            ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8E8E93),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class MobileMenuCard extends StatelessWidget {
  const MobileMenuCard({super.key, required this.item});

  final MobileMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          minTileHeight: item.icon == null ? 58 : null,
          leading: item.icon == null
              ? null
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 22),
                ),
          title: Text(
            item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D2E),
            ),
          ),
          subtitle: item.subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
          trailing:
              item.trailing ??
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          onTap: item.onTap ?? () => _openDestination(context),
        ),
      ),
    );
  }

  void _openDestination(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: AppLocalizations.of(context)!.backAction,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              color: const Color(0xFF1A1D2E),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D2E),
              ),
            ),
            centerTitle: true,
          ),
          body: item.view!,
        ),
      ),
    );
  }
}
