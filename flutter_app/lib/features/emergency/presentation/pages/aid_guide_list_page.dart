import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/emergency_models.dart';
import '../emergency_controller.dart';
import '../widgets/emergency_widgets.dart';
import 'aid_guide_detail_page.dart';

class AidGuideListPage extends StatefulWidget {
  const AidGuideListPage({super.key, required this.gateway});

  final EmergencyGateway gateway;

  @override
  State<AidGuideListPage> createState() => _AidGuideListPageState();
}

class _AidGuideListPageState extends State<AidGuideListPage> {
  late final AidGuideListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AidGuideListController(widget.gateway);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: emergencyBackground,
      appBar: AppBar(
        backgroundColor: emergencyRed,
        foregroundColor: Colors.white,
        surfaceTintColor: emergencyRed,
        title: const Text('常见急救指南'),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            _CategoryBar(controller: _controller),
            Expanded(child: _buildGuideList()),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideList() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: emergencyRed),
      );
    }
    if (_controller.error != null) {
      return EmergencyEmptyState(
        icon: Icons.cloud_off_outlined,
        title: _controller.error!,
        action: OutlinedButton.icon(
          onPressed: _controller.initialize,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }
    if (_controller.guides.isEmpty) {
      return const EmergencyEmptyState(
        icon: Icons.medical_information_outlined,
        title: '暂无急救指南',
      );
    }
    return RefreshIndicator(
      color: emergencyRed,
      onRefresh: _controller.refresh,
      child: ListView.separated(
        key: const ValueKey('aid-guide-list'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        itemCount: _controller.guides.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final guide = _controller.guides[index];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFFFD9DB)),
                ),
                child: InkWell(
                  key: ValueKey('aid-guide-list-item-${guide.id}'),
                  onTap: () => _openGuide(guide.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        AidGuideIcon(
                          iconUrl: guide.iconUrl,
                          size: 54,
                          iconSize: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guide.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                              if (guide.category != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  guide.category!.name,
                                  style: const TextStyle(
                                    color: emergencyRed,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFA3A6AD),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openGuide(int guideId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            AidGuideDetailPage(gateway: widget.gateway, guideId: guideId),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.controller});

  final AidGuideListController controller;

  @override
  Widget build(BuildContext context) {
    final categories = controller.categories;
    return SizedBox(
      key: const ValueKey('aid-guide-category-bar'),
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = index == 0 ? null : categories[index - 1];
          final categoryId = category?.id;
          return _CategoryTab(
            key: ValueKey(
              category == null
                  ? 'aid-guide-category-all'
                  : 'aid-guide-category-${category.id}',
            ),
            label: category?.name ?? '全部',
            selected: controller.selectedCategoryId == categoryId,
            onTap: () => controller.selectCategory(categoryId),
          );
        },
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? emergencyRed : Colors.white,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
