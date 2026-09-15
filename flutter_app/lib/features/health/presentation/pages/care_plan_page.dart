import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/health_models.dart';
import '../health_controller.dart';
import 'health_page.dart';

enum _PlanTab { nutrition, care }

class CarePlanPage extends StatefulWidget {
  const CarePlanPage({super.key, required this.gateway, required this.petId});

  final HealthGateway gateway;
  final int petId;

  @override
  State<CarePlanPage> createState() => _CarePlanPageState();
}

class _CarePlanPageState extends State<CarePlanPage> {
  late final CarePlanController _controller;
  _PlanTab _tab = _PlanTab.nutrition;

  @override
  void initState() {
    super.initState();
    _controller = CarePlanController(
      gateway: widget.gateway,
      petId: widget.petId,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), healthBackground],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: const Color(0xFF1F2937),
          centerTitle: true,
          title: const Text(
            '护理计划',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.loading) return const _CarePlanLoading();
            if (_controller.error != null && _controller.state == null) {
              return _CarePlanState(
                icon: Icons.cloud_off_outlined,
                iconColor: const Color(0xFF9CA3AF),
                iconBackground: const Color(0xFFF3F4F6),
                title: _controller.error!,
                description: '请检查网络连接后重试',
                buttonLabel: '重新加载',
                onPressed: _controller.load,
              );
            }
            final state = _controller.state!;
            if (state.status == CarePlanStatus.generating) {
              return const _CarePlanGenerating();
            }
            if (state.status == CarePlanStatus.failed) {
              return _CarePlanState(
                icon: Icons.error_outline_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBackground: const Color(0xFFFEF2F2),
                title: '生成失败',
                description: _friendlyError(state.error),
                buttonLabel: _controller.generating ? '启动中...' : '重新生成',
                onPressed: _controller.generating ? null : _controller.generate,
              );
            }
            if (state.plan == null ||
                state.status == CarePlanStatus.notGenerated) {
              return _CarePlanState(
                icon: Icons.description_outlined,
                iconColor: healthPrimary,
                iconBackground: const Color(0xFFEFF6FF),
                title: '暂无护理计划',
                description: '创建宠物后自动生成',
                buttonLabel: _controller.generating ? '启动中...' : '立即生成',
                onPressed: _controller.generating ? null : _controller.generate,
              );
            }
            return _buildPlan(state.plan!);
          },
        ),
      ),
    );
  }

  Widget _buildPlan(CarePlan plan) {
    return RefreshIndicator(
      color: healthPrimary,
      onRefresh: _controller.load,
      child: ListView(
        key: const ValueKey('care-plan-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlanTabBar(
                    selected: _tab,
                    onSelected: (tab) => setState(() => _tab = tab),
                  ),
                  if (_controller.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _controller.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _tab == _PlanTab.nutrition
                        ? _NutritionContent(
                            key: const ValueKey('care-plan-nutrition'),
                            plan: plan.nutrition,
                          )
                        : _CareContent(
                            key: const ValueKey('care-plan-care'),
                            plan: plan.care,
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
}

class _PlanTabBar extends StatelessWidget {
  const _PlanTabBar({required this.selected, required this.onSelected});

  final _PlanTab selected;
  final ValueChanged<_PlanTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('care-plan-tabs'),
      children: [
        Expanded(
          child: _PlanTabButton(
            tab: _PlanTab.nutrition,
            label: '营养计划',
            icon: Icons.restaurant_rounded,
            selected: selected == _PlanTab.nutrition,
            onTap: () => onSelected(_PlanTab.nutrition),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanTabButton(
            tab: _PlanTab.care,
            label: '护理计划',
            icon: Icons.health_and_safety_rounded,
            selected: selected == _PlanTab.care,
            onTap: () => onSelected(_PlanTab.care),
          ),
        ),
      ],
    );
  }
}

class _PlanTabButton extends StatelessWidget {
  const _PlanTabButton({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final _PlanTab tab;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: ValueKey('care-plan-tab-${tab.name}'),
        color: selected ? healthPrimary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: selected ? 2 : 0,
        shadowColor: healthPrimary.withAlpha(80),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF6B7280),
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NutritionContent extends StatelessWidget {
  const _NutritionContent({super.key, required this.plan});

  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    final ratios = <_NutrientData>[
      _NutrientData(
        label: '蛋白质',
        value: plan.protein,
        color: const Color(0xFF10B981),
        background: const Color(0xFFECFDF5),
      ),
      _NutrientData(
        label: '脂肪',
        value: plan.fat,
        color: const Color(0xFFF59E0B),
        background: const Color(0xFFFFFBEB),
      ),
      _NutrientData(
        label: '碳水化合物',
        value: plan.carbs,
        color: healthPrimary,
        background: const Color(0xFFEFF6FF),
      ),
    ].where((item) => item.value.trim().isNotEmpty).toList(growable: false);
    final hasData =
        plan.dailyCalories.trim().isNotEmpty ||
        ratios.isNotEmpty ||
        plan.recommendedFoods.isNotEmpty ||
        plan.avoidFoods.isNotEmpty ||
        plan.supplements.isNotEmpty ||
        plan.feedingSchedule.isNotEmpty;
    if (!hasData) return const _PlanEmpty(message: '暂无营养计划数据');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.dailyCalories.trim().isNotEmpty)
          _PlanPanel(
            key: const ValueKey('care-plan-calories-card'),
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6B6B),
            iconBackground: const Color(0xFFF3F4F6),
            title: '每日卡路里需求',
            highlighted: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _calorieValue(plan.dailyCalories),
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 32,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'kcal',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (ratios.isNotEmpty)
          _PlanPanel(
            key: const ValueKey('care-plan-ratio-card'),
            icon: Icons.pie_chart_rounded,
            iconColor: const Color(0xFF0EA5E9),
            iconBackground: const Color(0xFFE0F2FE),
            title: '营养比例',
            child: Column(
              children: [
                for (var index = 0; index < ratios.length; index++)
                  _NutrientRow(
                    data: ratios[index],
                    showDivider: index < ratios.length - 1,
                  ),
              ],
            ),
          ),
        if (plan.recommendedFoods.isNotEmpty)
          _NutritionListPanel(
            kind: _NutritionListKind.recommended,
            items: plan.recommendedFoods,
          ),
        if (plan.avoidFoods.isNotEmpty)
          _NutritionListPanel(
            kind: _NutritionListKind.avoid,
            items: plan.avoidFoods,
          ),
        if (plan.supplements.isNotEmpty)
          _NutritionListPanel(
            kind: _NutritionListKind.supplement,
            items: plan.supplements,
          ),
        if (plan.feedingSchedule.isNotEmpty)
          _NutritionListPanel(
            kind: _NutritionListKind.schedule,
            items: plan.feedingSchedule,
          ),
      ],
    );
  }
}

class _CareContent extends StatelessWidget {
  const _CareContent({super.key, required this.plan});

  final CareAdvice plan;

  @override
  Widget build(BuildContext context) {
    final categories = [
      _CareCategory(
        title: '美容护理',
        icon: Icons.content_cut_rounded,
        color: const Color(0xFFFF8C78),
        background: const Color(0xFFFFEFEC),
        items: plan.grooming,
      ),
      _CareCategory(
        title: '医疗护理',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFFEF4444),
        background: const Color(0xFFFEE2E2),
        items: plan.medical,
      ),
      _CareCategory(
        title: '运动建议',
        icon: Icons.directions_run_rounded,
        color: const Color(0xFF10B981),
        background: const Color(0xFFD1FAE5),
        items: plan.exercise,
      ),
      _CareCategory(
        title: '疫苗接种',
        icon: Icons.vaccines_rounded,
        color: const Color(0xFF3B82F6),
        background: const Color(0xFFDBEAFE),
        items: plan.vaccination,
      ),
      _CareCategory(
        title: '环境管理',
        icon: Icons.home_rounded,
        color: const Color(0xFFF59E0B),
        background: const Color(0xFFFEF3C7),
        items: plan.environment,
      ),
    ].where((category) => category.items.isNotEmpty).toList(growable: false);
    if (categories.isEmpty) return const _PlanEmpty(message: '暂无护理计划数据');

    return Column(
      children: [
        for (final category in categories)
          _PlanPanel(
            icon: category.icon,
            iconColor: category.color,
            iconBackground: category.background,
            title: category.title,
            child: Column(
              children: [
                for (var index = 0; index < category.items.length; index++)
                  _CareItem(
                    text: category.items[index],
                    color: category.color,
                    showDivider: index < category.items.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.child,
    this.highlighted = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFFFB5A7)
              : const Color(0xFFE5E7EB),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? const Color(0x1AFFB5A7)
                : const Color(0x0A000000),
            offset: const Offset(0, 1),
            blurRadius: highlighted ? 6 : 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

enum _NutritionListKind { recommended, avoid, supplement, schedule }

class _NutritionListPanel extends StatelessWidget {
  const _NutritionListPanel({required this.kind, required this.items});

  final _NutritionListKind kind;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final config = switch (kind) {
      _NutritionListKind.recommended => const _NutritionListConfig(
        title: '推荐食物',
        icon: Icons.thumb_up_rounded,
        color: Color(0xFF10B981),
        background: Color(0xFFD1FAE5),
      ),
      _NutritionListKind.avoid => const _NutritionListConfig(
        title: '避免的食物',
        icon: Icons.block_rounded,
        color: Color(0xFFEF4444),
        background: Color(0xFFFEE2E2),
      ),
      _NutritionListKind.supplement => const _NutritionListConfig(
        title: '营养补充剂',
        icon: Icons.medication_rounded,
        color: Color(0xFF8B5CF6),
        background: Color(0xFFEDE9FE),
      ),
      _NutritionListKind.schedule => const _NutritionListConfig(
        title: '喂养时间表',
        icon: Icons.schedule_rounded,
        color: Color(0xFF3B82F6),
        background: Color(0xFFDBEAFE),
      ),
    };
    return _PlanPanel(
      icon: config.icon,
      iconColor: config.color,
      iconBackground: config.background,
      title: config.title,
      child: Column(
        children: [
          for (final item in items)
            _NutritionListItem(text: item, kind: kind, color: config.color),
        ],
      ),
    );
  }
}

class _NutritionListItem extends StatelessWidget {
  const _NutritionListItem({
    required this.text,
    required this.kind,
    required this.color,
  });

  final String text;
  final _NutritionListKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final marker = switch (kind) {
      _NutritionListKind.recommended => _CircleMarker(
        color: color,
        icon: Icons.check_rounded,
      ),
      _NutritionListKind.avoid => _CircleMarker(
        color: color,
        icon: Icons.close_rounded,
      ),
      _NutritionListKind.supplement => _DotMarker(color: color),
      _NutritionListKind.schedule => Icon(
        Icons.access_time_rounded,
        color: color,
        size: 19,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: marker),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({required this.data, required this.showDivider});

  final _NutrientData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: data.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.label,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: data.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                data.value,
                style: TextStyle(
                  color: data.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareItem extends StatelessWidget {
  const _CareItem({
    required this.text,
    required this.color,
    required this.showDivider,
  });

  final String text;
  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleMarker extends StatelessWidget {
  const _CircleMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

class _DotMarker extends StatelessWidget {
  const _DotMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 21,
      height: 21,
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _PlanEmpty extends StatelessWidget {
  const _PlanEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _PlanPanel(
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF9CA3AF),
      iconBackground: const Color(0xFFF3F4F6),
      title: message,
      child: const SizedBox.shrink(),
    );
  }
}

class _NutrientData {
  const _NutrientData({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;
}

class _NutritionListConfig {
  const _NutritionListConfig({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color background;
}

class _CareCategory {
  const _CareCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final List<String> items;
}

String _calorieValue(String value) {
  return value
      .trim()
      .replaceFirst(RegExp(r'\s*kcal\s*$', caseSensitive: false), '')
      .trim();
}

class _CarePlanLoading extends StatelessWidget {
  const _CarePlanLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: healthPrimary),
          SizedBox(height: 12),
          Text('加载中...', style: TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _CarePlanGenerating extends StatelessWidget {
  const _CarePlanGenerating();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: healthPrimary),
            SizedBox(height: 18),
            Text(
              '护理计划生成中...',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '生成过程可能需要 1-2 分钟\n请稍后下拉刷新查看',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarePlanState extends StatelessWidget {
  const _CarePlanState({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.description,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? description;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 38, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            if (buttonLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: healthPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(148, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onPressed,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _friendlyError(String error) {
  const technicalPatterns = [
    'ETIMEDOUT',
    'ECONNABORTED',
    'ECONNREFUSED',
    'ECONNRESET',
    'AI 接口调用失败',
  ];
  if (error.isEmpty) return '护理方案暂时生成失败，请稍后重试';
  if (technicalPatterns.any(error.contains)) return 'AI 服务暂时不可用，请稍后重新生成';
  return error;
}
