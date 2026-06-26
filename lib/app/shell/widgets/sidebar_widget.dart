import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/motion/smooth_reveal.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../../modules/auth/widgets/pin_account_switch_dialog.dart';
import '../../role_access/role_manager.dart';

class SidebarItem {
  SidebarItem({
    required this.title,
    required this.icon,
    required this.sectionLabel,
  });

  final String title;
  final IconData icon;
  final String sectionLabel;
}

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    this.onToggle,
  });

  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCollapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final l10n = AppLocalizations.of(context)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      width: isCollapsed ? 80 : 160,
      decoration: const BoxDecoration(color: AppColors.primary),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            SmoothReveal(
              delay: const Duration(milliseconds: 60),
              offset: const Offset(-10, 0),
              child: _SidebarHeader(isCollapsed: isCollapsed),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    SmoothReveal(
                      delay: Duration(milliseconds: 100 + (index * 22)),
                      offset: const Offset(-14, 0),
                      child: _SidebarMenuTile(
                        item: items[index],
                        isCollapsed: isCollapsed,
                        isSelected: selectedIndex == index,
                        backgroundColor: backgroundColor,
                        onTap: () => onItemSelected(index),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            InkWell(
              onTap: () => showPinAccountSwitchDialog(context),
              child: _SidebarFooterActionLabel(
                isCollapsed: isCollapsed,
                icon: Icons.switch_account_rounded,
                label: l10n.switchAccountAction,
              ),
            ),
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_right_rounded
                          : Icons.keyboard_arrow_left_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarMenuTile extends StatefulWidget {
  const _SidebarMenuTile({
    required this.item,
    required this.isCollapsed,
    required this.isSelected,
    required this.backgroundColor,
    required this.onTap,
  });

  final SidebarItem item;
  final bool isCollapsed;
  final bool isSelected;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  State<_SidebarMenuTile> createState() => _SidebarMenuTileState();
}

class _SidebarMenuTileState extends State<_SidebarMenuTile> {
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _showText = !widget.isCollapsed;
  }

  @override
  void didUpdateWidget(covariant _SidebarMenuTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        // Hide text immediately when collapsing
        _showText = false;
      } else {
        // Wait for sidebar to expand before showing text smoothly
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && !widget.isCollapsed) {
            setState(() {
              _showText = true;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.isSelected)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                right: 0,
                top: widget.isCollapsed ? -14 : -10,
                bottom: widget.isCollapsed ? -14 : -10,
                width: widget.isCollapsed ? 55 : 150,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    widget.isCollapsed
                        ? 'assets/aktif_2.webp'
                        : 'assets/aktif_1.webp',
                    key: ValueKey(widget.isCollapsed ? 'aktif2' : 'aktif1'),
                    fit: BoxFit.fill,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 8,
                top: 12,
                bottom: 12,
              ),
              child: Row(
                mainAxisAlignment: widget.isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 360),
                    scale: widget.isSelected ? 1.05 : 1,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      widget.item.icon,
                      color: widget.isSelected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.78),
                      size: 20,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showText ? 1.0 : 0.0,
                      child: _showText
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 14),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 360),
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    color: widget.isSelected
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.78),
                                    fontSize: 14,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                  child: Text(
                                    widget.item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatefulWidget {
  const _SidebarHeader({required this.isCollapsed});

  final bool isCollapsed;

  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _showText = !widget.isCollapsed;
  }

  @override
  void didUpdateWidget(covariant _SidebarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _showText = false;
      } else {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && !widget.isCollapsed) {
            setState(() {
              _showText = true;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: widget.isCollapsed ? 12 : 24,
        right: widget.isCollapsed ? 12 : 8,
        top: 12,
        bottom: 12,
      ),
      alignment: widget.isCollapsed ? Alignment.center : Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          // Animasi dari bawah ke atas
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.5),
            end: Offset.zero,
          ).animate(animation);

          // Jika sedang menutup (isCollapsed = true), gunakan Interval
          // agar teks memudar lebih dulu (1.0 -> 0.5), baru ikon muncul (0.5 -> 1.0)
          Animation<double> opacity = animation;
          if (widget.isCollapsed) {
            opacity = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.5, 1.0),
            );
          }

          return FadeTransition(
            opacity: opacity,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: widget.isCollapsed || !_showText
            ? const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 30,
                key: ValueKey('icon'),
              )
            : const Text(
                'FlinkPOS',
                key: ValueKey('text'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
      ),
    );
  }
}

class _SidebarFooterActionLabel extends StatefulWidget {
  const _SidebarFooterActionLabel({
    required this.isCollapsed,
    required this.icon,
    required this.label,
  });

  final bool isCollapsed;
  final IconData icon;
  final String label;

  @override
  State<_SidebarFooterActionLabel> createState() =>
      _SidebarFooterActionLabelState();
}

class _SidebarFooterActionLabelState extends State<_SidebarFooterActionLabel> {
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _showText = !widget.isCollapsed;
  }

  @override
  void didUpdateWidget(covariant _SidebarFooterActionLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        setState(() {
          _showText = false;
        });
      } else {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && !widget.isCollapsed) {
            setState(() {
              _showText = true;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        mainAxisAlignment: widget.isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.end,
        children: [
          Icon(widget.icon, color: Colors.white70, size: 20),
          if (!widget.isCollapsed)
            Expanded(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showText ? 1 : 0,
                  child: !_showText
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(left: 8, right: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
