import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/pet_models.dart';
import '../pet_list_controller.dart';
import 'pet_edit_page.dart';
import 'pet_page_chrome.dart';

typedef PetEditPageBuilder = Widget Function(BuildContext context, int? petId);

const petLostFoundUnavailableMessage = '走失寻宠功能尚未迁移，请在原应用中使用';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key, required this.gateway, this.editPageBuilder});

  final PetGateway gateway;
  final PetEditPageBuilder? editPageBuilder;

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  late final PetListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PetListController(gateway: widget.gateway);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isInitialLoading && _controller.pets.isEmpty) {
          return const _PetInitialLoading();
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: PetGradientBackground(
            child: SafeArea(
              child: Column(
                children: [
                  PetPageHeader(
                    title: '我的宠物',
                    onBack: () => Navigator.maybePop(context),
                    trailing: TextButton(
                      key: const ValueKey('pet-lost-found'),
                      onPressed: () =>
                          _showMessage(petLostFoundUnavailableMessage),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: petPrimaryColor,
                        textStyle: TextStyle(
                          fontSize: petDesignPx(context, 26),
                          height: 34 / 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      child: const Text('我的走失'),
                    ),
                  ),
                  SizedBox(height: petDesignPx(context, 30)),
                  _buildCategories(),
                  Expanded(child: _buildPetList()),
                  _buildAddAction(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: petDesignPx(context, 68),
      child: ListView(
        key: const ValueKey('pet-category-list'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
          left: petDesignPx(context, 16),
          top: petDesignPx(context, 10),
          bottom: petDesignPx(context, 10),
        ),
        children: [
          _CategoryTab(
            key: const ValueKey('pet-category-all'),
            label: '全部',
            selected: _controller.selectedCategoryId == null,
            onTap: () => unawaited(_controller.selectCategory(null)),
          ),
          for (final category in _controller.categories)
            _CategoryTab(
              key: ValueKey('pet-category-${category.id}'),
              label: category.name,
              selected: _controller.selectedCategoryId == category.id,
              onTap: () => unawaited(_controller.selectCategory(category.id)),
            ),
        ],
      ),
    );
  }

  Widget _buildPetList() {
    if (_controller.errorMessage != null && _controller.pets.isEmpty) {
      return RefreshIndicator(
        color: petPrimaryColor,
        onRefresh: _controller.retry,
        child: _PetStateView(
          icon: Icons.wifi_off_rounded,
          title: '宠物列表加载失败',
          description: '请检查网络后重试',
          action: TextButton.icon(
            key: const ValueKey('pet-list-retry'),
            onPressed: _controller.retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
      );
    }
    if (_controller.pets.isEmpty) {
      return RefreshIndicator(
        color: petPrimaryColor,
        onRefresh: _controller.refresh,
        child: const _PetStateView(title: '暂无宠物', description: '点击下方按钮添加'),
      );
    }

    return RefreshIndicator(
      color: petPrimaryColor,
      onRefresh: _controller.refresh,
      child: ListView.builder(
        key: const ValueKey('pet-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: petDesignPx(context, 8),
          bottom: petDesignPx(context, 16),
        ),
        itemCount: _controller.pets.length,
        itemBuilder: (context, index) {
          final pet = _controller.pets[index];
          return _PetCard(pet: pet, onTap: () => _openEditor(pet.id));
        },
      ),
    );
  }

  Widget _buildAddAction() {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: petBorderColor)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            petDesignPx(context, 16),
            petDesignPx(context, 16),
            petDesignPx(context, 16),
            petDesignPx(context, 24),
          ),
          child: PetPrimaryButton(
            key: const ValueKey('pet-add'),
            label: '+ 添加宠物',
            onPressed: () => _openEditor(null),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(int? petId) async {
    final builder = widget.editPageBuilder;
    final result = await Navigator.of(context).push<PetEditorResult>(
      MaterialPageRoute<PetEditorResult>(
        builder: (routeContext) => builder != null
            ? builder(routeContext, petId)
            : PetEditPage(gateway: widget.gateway, petId: petId),
      ),
    );
    if (!mounted) return;
    await _controller.handleEditorResult(result);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    return Padding(
      padding: EdgeInsets.only(right: petDesignPx(context, 14)),
      child: Material(
        color: selected ? petPrimaryColor : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(petDesignPx(context, 14)),
          side: BorderSide(
            color: selected ? petPrimaryColor : petBorderColor,
            width: petDesignPx(context, 1),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: petDesignPx(context, 92)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: petDesignPx(context, 16),
                vertical: petDesignPx(context, 8),
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: petDesignPx(context, 30),
                    height: 34 / 30,
                    color: selected ? Colors.white : petTextSecondaryColor,
                    fontWeight: FontWeight.w600,
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

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: petDesignPx(context, 16),
        vertical: petDesignPx(context, 6),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(petDesignPx(context, 12)),
        border: Border.all(
          color: petBorderColor,
          width: petDesignPx(context, 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: Offset(0, petDesignPx(context, 2)),
            blurRadius: petDesignPx(context, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(petDesignPx(context, 12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('pet-card-${pet.id}'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(petDesignPx(context, 14)),
            child: Row(
              children: [
                _PetAvatar(pet: pet),
                SizedBox(width: petDesignPx(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: petDesignPx(context, 30),
                          height: 38 / 30,
                          fontWeight: FontWeight.w500,
                          color: petTextPrimaryColor,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: petDesignPx(context, 8)),
                      Text(
                        '${pet.breedLabel} · ${formatPetAge(pet.birthDate)} · ${pet.genderLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: petDesignPx(context, 26),
                          height: 34 / 26,
                          color: petTextSecondaryColor,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: petDesignPx(context, 8)),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(
                            petDesignPx(context, 4),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: petDesignPx(context, 10),
                            vertical: petDesignPx(context, 4),
                          ),
                          child: Text(
                            pet.vaccineLabel,
                            style: TextStyle(
                              fontSize: petDesignPx(context, 24),
                              height: 32 / 24,
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: petDesignPx(context, 10)),
                Text(
                  '›',
                  style: TextStyle(
                    fontSize: petDesignPx(context, 72),
                    height: 1,
                    color: petTextTertiaryColor,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
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

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final url = pet.resolvedAvatarUrl();
    final size = petDesignPx(context, 56);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(petDesignPx(context, 10)),
        child: url.isEmpty
            ? ColoredBox(
                color: petBorderColor,
                child: Center(
                  child: Text(
                    pet.name.characters.firstOrNull ?? '宠',
                    style: TextStyle(
                      fontSize: petDesignPx(context, 26),
                      color: petTextTertiaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: petBorderColor,
                  child: Icon(Icons.pets_rounded, color: petTextTertiaryColor),
                ),
              ),
      ),
    );
  }
}

class _PetStateView extends StatelessWidget {
  const _PetStateView({
    required this.title,
    required this.description,
    this.icon,
    this.action,
  });

  final IconData? icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: petDesignPx(context, 32),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: petDesignPx(context, 72),
                        color: petTextTertiaryColor,
                      ),
                      SizedBox(height: petDesignPx(context, 20)),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: petDesignPx(context, 34),
                        height: 42 / 34,
                        fontWeight: FontWeight.w600,
                        color: petTextPrimaryColor,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: petDesignPx(context, 12)),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: petDesignPx(context, 28),
                        height: 36 / 28,
                        color: petTextSecondaryColor,
                        letterSpacing: 0,
                      ),
                    ),
                    if (action != null) ...[
                      SizedBox(height: petDesignPx(context, 12)),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetInitialLoading extends StatelessWidget {
  const _PetInitialLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PetGradientBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: petPrimaryColor),
                SizedBox(height: petDesignPx(context, 16)),
                Text(
                  '加载中...',
                  style: TextStyle(
                    fontSize: petDesignPx(context, 26),
                    height: 34 / 26,
                    color: petTextSecondaryColor,
                    letterSpacing: 0,
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
