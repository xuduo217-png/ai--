import 'package:flutter/material.dart';

import '../../../../../core/media/gallery_media_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../shared/mall_widgets.dart';
import '../../domain/second_hand_models.dart';
import '../second_hand_controller.dart';

const _publishHeaderBackgroundColor = Color(0xFFDEE9FF);

class PublishProductPage extends StatefulWidget {
  const PublishProductPage({
    super.key,
    required this.gateway,
    this.pendingId,
    this.galleryMediaPicker,
  });

  final SecondHandGateway gateway;
  final int? pendingId;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<PublishProductPage> createState() => _PublishProductPageState();
}

class _PublishProductPageState extends State<PublishProductPage> {
  late final PublishProductController _controller;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '1');
  late final GalleryMediaPicker _galleryMediaPicker;

  final List<String> _images = [];
  int? _firstCategoryId;
  int? _secondCategoryId;
  ProductCondition _condition = ProductCondition.brandNew;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    _controller = PublishProductController(
      widget.gateway,
      pendingId: widget.pendingId,
    );
    _load();
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted || _filled || _controller.product == null) return;
    final product = _controller.product!;
    _title.text = product.title;
    _description.text = product.description;
    _price.text = product.price.toStringAsFixed(2);
    _stock.text = '${product.stock}';
    _condition = product.condition;
    _images.addAll(product.images);
    for (final category in _controller.categories) {
      if (category.id == product.categoryId) {
        _firstCategoryId = category.id;
        _secondCategoryId = category.id;
        break;
      }
      if (category.children.any((child) => child.id == product.categoryId)) {
        _firstCategoryId = category.id;
        _secondCategoryId = product.categoryId;
        break;
      }
    }
    _filled = true;
    setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: mallBackground,
        appBar: AppBar(
          backgroundColor: _publishHeaderBackgroundColor,
          surfaceTintColor: _publishHeaderBackgroundColor,
          foregroundColor: AppColors.ink,
          title: Text(widget.pendingId == null ? '发布商品' : '编辑商品'),
        ),
        body: _body(),
        bottomNavigationBar: _controller.loading ? null : _submitBar(),
      ),
    );
  }

  Widget _body() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && _controller.categories.isEmpty) {
      return MallStateView(
        icon: Icons.wifi_off_outlined,
        message: _controller.errorMessage!,
        onRetry: _load,
      );
    }
    return ListView(
      key: const ValueKey('publish-product-form'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        _panel(
          key: const ValueKey('publish-title-section'),
          title: '商品标题 *',
          child: TextField(
            controller: _title,
            maxLength: 50,
            decoration: const InputDecoration(hintText: '请输入商品标题（最多50个字符）'),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const ValueKey('publish-description-section'),
          title: '商品描述 *',
          child: TextField(
            controller: _description,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: '请详细描述商品的品牌、规格、型号、转手原因等信息',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const ValueKey('publish-price-section'),
          title: '价格（元）*',
          child: TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0.00',
              prefixText: '¥ ',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const ValueKey('publish-stock-section'),
          title: '库存（件）*',
          child: TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '1',
              helperText: '默认 1 件，最少 1 件',
              helperStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const ValueKey('publish-images-section'),
          title: '商品图片 *（最多9张）',
          subtitle: '${_images.length}/9',
          child: _imageGrid(),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const ValueKey('publish-category-section'),
          title: '商品分类 *',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _selectCategory,
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.chevron_right),
              ),
              child: Text(_categoryLabel()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const ValueKey('publish-condition-section'),
          title: '新旧程度 *',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProductCondition.values
                .map(
                  (condition) => ChoiceChip(
                    label: Text(condition.label),
                    selected: _condition == condition,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _condition = condition),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (_controller.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _controller.errorMessage!,
            style: const TextStyle(color: Color(0xFFD84949)),
          ),
        ],
      ],
    );
  }

  Widget _panel({
    Key? key,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF858C99)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _imageGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final itemSize = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            ...List.generate(_images.length, (index) {
              return SizedBox.square(
                dimension: itemSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: MallNetworkImage(url: _images[index]),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filled(
                        tooltip: '删除图片',
                        visualDensity: VisualDensity.compact,
                        onPressed: _controller.uploading
                            ? null
                            : () => setState(() => _images.removeAt(index)),
                        icon: const Icon(Icons.close, size: 17),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_images.length < 9)
              SizedBox.square(
                dimension: itemSize,
                child: OutlinedButton(
                  onPressed: _controller.uploading ? null : _pickImages,
                  child: _controller.uploading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined),
                            SizedBox(height: 5),
                            Text('添加图片'),
                          ],
                        ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _submitBar() {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton(
            onPressed: _controller.submitting || _controller.uploading
                ? null
                : _submit,
            child: _controller.submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.pendingId == null ? '提交审核' : '提交修改'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final available = 9 - _images.length;
      if (available <= 0) return;
      var exceededLimit = false;
      final selected = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.image,
        allowMultiple: true,
        maxCount: available,
        imageQuality: 85,
        onLimitExceeded: (_, _) => exceededLimit = true,
      );
      if (!mounted || selected.isEmpty) return;
      final picked = selected.take(available).toList(growable: false);
      if (exceededLimit) {
        showMallMessage(context, '最多上传9张图片');
      }
      for (final image in picked) {
        final url = await _controller.upload(image.path);
        if (!mounted) return;
        if (url != null) {
          setState(() => _images.add(url));
        } else {
          showMallMessage(
            context,
            _controller.errorMessage ?? '图片上传失败',
            error: true,
          );
        }
      }
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    }
  }

  Future<void> _selectCategory() async {
    if (_controller.categories.isEmpty) {
      showMallMessage(context, '暂无可用分类', error: true);
      return;
    }
    var first = _controller.categories.firstWhere(
      (category) => category.id == _firstCategoryId,
      orElse: () => _controller.categories.first,
    );
    final selected = await showModalBottomSheet<SecondHandCategory>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '选择商品分类',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 132,
                      child: ListView(
                        children: _controller.categories
                            .map(
                              (category) => ListTile(
                                selected: first.id == category.id,
                                title: Text(category.name),
                                onTap: () =>
                                    setSheetState(() => first = category),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: first.children.isEmpty
                          ? const MallStateView(
                              icon: Icons.category_outlined,
                              message: '暂无二级分类',
                            )
                          : ListView(
                              children: first.children
                                  .map(
                                    (category) => ListTile(
                                      title: Text(category.name),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () =>
                                          Navigator.pop(sheetContext, category),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _firstCategoryId = first.id;
      _secondCategoryId = selected.id;
    });
  }

  String _categoryLabel() {
    if (_firstCategoryId == null || _secondCategoryId == null) {
      return '请选择二级分类';
    }
    final first = _controller.categories.where(
      (category) => category.id == _firstCategoryId,
    );
    if (first.isEmpty) return '请选择二级分类';
    final second = first.first.children.where(
      (category) => category.id == _secondCategoryId,
    );
    if (second.isEmpty) return first.first.name;
    return '${first.first.name} / ${second.first.name}';
  }

  Future<void> _submit() async {
    final input = PublishProductInput(
      title: _title.text,
      description: _description.text,
      price: double.tryParse(_price.text.trim()) ?? 0,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      images: List.unmodifiable(_images),
      categoryId: _secondCategoryId ?? 0,
      condition: _condition,
    );
    final success = await _controller.submit(input);
    if (!mounted) return;
    if (!success) {
      showMallMessage(context, _controller.errorMessage ?? '提交失败', error: true);
      return;
    }
    showMallMessage(context, widget.pendingId == null ? '已提交审核' : '修改已提交审核');
    Navigator.pop(context, true);
  }
}
