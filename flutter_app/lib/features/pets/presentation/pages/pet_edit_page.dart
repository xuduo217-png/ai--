import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:flutter_pickers/time_picker/model/date_mode.dart';
import 'package:flutter_pickers/time_picker/model/pduration.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../domain/pet_models.dart';
import '../pet_edit_controller.dart';
import 'pet_page_chrome.dart';

class PetEditPage extends StatefulWidget {
  const PetEditPage({
    super.key,
    required this.gateway,
    this.petId,
    this.imagePicker,
    this.fileExists,
  });

  final PetGateway gateway;
  final int? petId;
  final PetImagePicker? imagePicker;
  final PetFileExists? fileExists;

  @override
  State<PetEditPage> createState() => _PetEditPageState();
}

class _PetEditPageState extends State<PetEditPage> {
  late final PetEditController _controller;
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _vaccineController;
  bool _detailSynced = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _weightController = TextEditingController();
    _vaccineController = TextEditingController(text: '0');
    _controller = PetEditController(
      gateway: widget.gateway,
      petId: widget.petId,
      imagePicker: widget.imagePicker,
      fileExists: widget.fileExists,
    )..addListener(_syncLoadedDetail);
    _detailSynced = widget.petId == null;
    unawaited(_controller.load());
  }

  void _syncLoadedDetail() {
    if (_detailSynced ||
        widget.petId == null ||
        _controller.isLoading ||
        _controller.loadError != null) {
      return;
    }
    final draft = _controller.draft;
    _nameController.text = draft.name;
    _weightController.text = draft.weightText;
    _vaccineController.text = draft.vaccineCountText;
    _detailSynced = true;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncLoadedDetail)
      ..dispose();
    _nameController.dispose();
    _weightController.dispose();
    _vaccineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && widget.petId != null) {
          return const _EditInitialLoading();
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.transparent,
          body: PetGradientBackground(
            child: SafeArea(
              child: Column(
                children: [
                  PetPageHeader(
                    title: widget.petId == null ? '添加宠物' : '编辑宠物',
                    onBack: () => Navigator.maybePop(context),
                  ),
                  SizedBox(height: petDesignPx(context, 30)),
                  if (_controller.loadError != null && widget.petId != null)
                    Expanded(child: _EditLoadError(onRetry: _controller.retry))
                  else ...[
                    Expanded(child: _buildForm()),
                    _buildFooter(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    final draft = _controller.draft;
    final category = _categoryFor(draft.categoryId);
    final subCategory = category?.children
        .where((item) => item.id == draft.subCategoryId)
        .firstOrNull;
    final categoryLabel = category == null
        ? '请选择品种'
        : [
            category.name,
            if (subCategory != null) subCategory.name,
          ].join(' > ');
    final busy = _controller.isBusy;

    return ListView(
      key: const ValueKey('pet-edit-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: petDesignPx(context, 16)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAvatar(draft, busy),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormFieldBlock(
                        label: '宠物名字',
                        required: true,
                        child: _TextControl(
                          key: const ValueKey('pet-edit-name'),
                          controller: _nameController,
                          enabled: !busy,
                          maxLength: 50,
                          textInputAction: TextInputAction.next,
                          hintText: '请输入宠物名字',
                          onChanged: _controller.updateName,
                        ),
                      ),
                      _FormFieldBlock(
                        label: '宠物品种',
                        required: true,
                        child: _SelectControl(
                          key: const ValueKey('pet-edit-category'),
                          value: categoryLabel,
                          placeholder: category == null,
                          enabled: !busy,
                          onTap: _pickCategory,
                        ),
                      ),
                      _FormFieldBlock(
                        label: '出生日期',
                        required: true,
                        child: _SelectControl(
                          key: const ValueKey('pet-edit-birth-date'),
                          value: draft.birthDate == null
                              ? '请选择出生日期'
                              : formatPetDate(draft.birthDate!),
                          placeholder: draft.birthDate == null,
                          enabled: !busy,
                          onTap: _pickBirthDate,
                        ),
                      ),
                      _FormFieldBlock(
                        label: '性别',
                        child: _SegmentedControl<PetGender>(
                          key: const ValueKey('pet-edit-gender'),
                          selected: draft.gender,
                          enabled: !busy,
                          options: const [
                            _SegmentOption(PetGender.male, '弟弟'),
                            _SegmentOption(PetGender.female, '妹妹'),
                          ],
                          onChanged: _controller.updateGender,
                        ),
                      ),
                      _FormFieldBlock(
                        label: '是否绝育',
                        child: _SegmentedControl<bool>(
                          key: const ValueKey('pet-edit-neutered'),
                          selected: draft.isNeutered,
                          enabled: !busy,
                          options: const [
                            _SegmentOption(false, '未绝育'),
                            _SegmentOption(true, '已绝育'),
                          ],
                          onChanged: _controller.updateNeutered,
                        ),
                      ),
                      _FormFieldBlock(
                        label: '宠物体重',
                        required: true,
                        child: _TextControl(
                          key: const ValueKey('pet-edit-weight'),
                          controller: _weightController,
                          enabled: !busy,
                          hintText: '请输入体重',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d{0,3}(?:\.\d{0,2})?'),
                            ),
                          ],
                          suffix: 'kg',
                          onChanged: _controller.updateWeight,
                        ),
                      ),
                      _FormFieldBlock(
                        label: '已接种针数',
                        child: _TextControl(
                          key: const ValueKey('pet-edit-vaccine-count'),
                          controller: _vaccineController,
                          enabled: !busy,
                          hintText: '请输入已接种针数',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          suffix: '针',
                          onChanged: _controller.updateVaccineCount,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final busy = _controller.isBusy;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: petBorderColor)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          petDesignPx(context, 16),
          16,
          petDesignPx(context, 16),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.petId != null) ...[
                  SizedBox(
                    height: petDesignPx(context, 90),
                    child: OutlinedButton(
                      key: const ValueKey('pet-edit-delete'),
                      onPressed: busy ? null : _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        disabledForegroundColor: const Color(0xFFEF4444),
                        side: BorderSide(
                          color: const Color(0xFFEF4444),
                          width: petDesignPx(context, 2),
                        ),
                        shape: const StadiumBorder(),
                        textStyle: TextStyle(
                          fontSize: petDesignPx(context, 30),
                          height: 34 / 30,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      child: _controller.isDeleting
                          ? SizedBox.square(
                              dimension: petDesignPx(context, 34),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFEF4444),
                              ),
                            )
                          : const Text('删除宠物'),
                    ),
                  ),
                  SizedBox(height: petDesignPx(context, 12)),
                ],
                PetPrimaryButton(
                  key: const ValueKey('pet-edit-save'),
                  label: widget.petId == null ? '完成添加' : '保存修改',
                  busy: _controller.isSaving,
                  onPressed: busy ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(PetDraft draft, bool busy) {
    final url = Pet(
      id: 0,
      name: draft.name.trim().isEmpty ? '宠' : draft.name.trim(),
      avatarUrl: draft.avatarUrl,
      categoryId: null,
      subCategoryId: null,
      gender: draft.gender,
      birthDate: null,
      weight: 0,
      isNeutered: false,
      vaccineCount: 0,
      category: null,
      subCategory: null,
      ownerId: 0,
      createdAt: null,
      updatedAt: null,
    ).resolvedAvatarUrl();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final size = screenWidth < 600 ? 80.0 : 160.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: petDesignPx(context, 16)),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: '选择宠物头像',
            child: InkWell(
              key: const ValueKey('pet-edit-avatar'),
              customBorder: const CircleBorder(),
              onTap: busy ? null : _chooseImageSource,
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.isEmpty)
                      CustomPaint(
                        painter: const _DashedCirclePainter(
                          color: petPrimaryColor,
                          strokeWidth: 2,
                        ),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+',
                                style: TextStyle(
                                  fontSize: petDesignPx(context, 48),
                                  height: 1,
                                  color: petPrimaryColor,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 0,
                                ),
                              ),
                              SizedBox(height: petDesignPx(context, 4)),
                              Text(
                                '添加照片',
                                style: TextStyle(
                                  fontSize: petDesignPx(context, 18),
                                  height: 24 / 18,
                                  color: petTextSecondaryColor,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ClipOval(
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFF9FAFB),
                            child: Icon(
                              Icons.pets_rounded,
                              color: petPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                    if (_controller.isUploading)
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xD97E97FA),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: petDesignPx(context, 8)),
                              Text(
                                '上传中...',
                                style: TextStyle(
                                  fontSize: petDesignPx(context, 20),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: petDesignPx(context, 8)),
          Text(
            '点击上传头像',
            style: TextStyle(
              fontSize: petDesignPx(context, 22),
              height: 30 / 22,
              color: petTextSecondaryColor,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  PetCategory? _categoryFor(int? id) {
    if (id == null) return null;
    return _controller.categories.where((item) => item.id == id).firstOrNull;
  }

  void _pickCategory() {
    final pickerData = <_PetCategoryPickerItem, List<_PetCategoryPickerItem>>{};
    for (final category in _controller.categories) {
      if (category.children.isEmpty) continue;
      pickerData[_PetCategoryPickerItem(category)] = category.children
          .map(_PetCategoryPickerItem.new)
          .toList(growable: false);
    }
    if (pickerData.isEmpty) {
      _showMessage(_controller.categoryError ?? '暂无可用品种，请稍后重试');
      return;
    }
    final category =
        pickerData.keys
            .where((item) => item.value.id == _controller.draft.categoryId)
            .firstOrNull ??
        pickerData.keys.first;
    final subCategories = pickerData[category]!;
    final subCategory =
        subCategories
            .where((item) => item.value.id == _controller.draft.subCategoryId)
            .firstOrNull ??
        subCategories.first;
    final style = DefaultPickerStyle(haveRadius: true, title: '选择品种')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = petTextPrimaryColor;

    Pickers.showMultiLinkPicker(
      context,
      data: pickerData,
      columnNum: 2,
      selectData: [category, subCategory],
      pickerStyle: style,
      onConfirm: (selection, _) {
        if (selection.length < 2) return;
        final selectedCategory = selection[0] as _PetCategoryPickerItem;
        final selectedSubCategory = selection[1] as _PetCategoryPickerItem;
        _controller.updateCategory(selectedCategory.value.id);
        _controller.updateSubCategory(selectedSubCategory.value.id);
      },
    );
  }

  void _pickBirthDate() {
    final now = DateTime.now();
    final lastDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final firstDate = DateTime(2000);
    final fallback = DateTime(lastDate.year - 1, lastDate.month, lastDate.day);
    final birthDate = _controller.draft.birthDate;
    final initialDate =
        birthDate != null &&
            !birthDate.isBefore(firstDate) &&
            !birthDate.isAfter(lastDate)
        ? birthDate
        : fallback;
    final style = DefaultPickerStyle(haveRadius: true, title: '选择出生日期')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = petTextPrimaryColor;

    Pickers.showDatePicker(
      context,
      mode: DateMode.YMD,
      selectDate: PDuration.parse(initialDate),
      minDate: PDuration.parse(firstDate),
      maxDate: PDuration.parse(lastDate),
      pickerStyle: style,
      onConfirm: (value) {
        _controller.updateBirthDate(
          DateTime(value.year!, value.month!, value.day!),
        );
      },
    );
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<PetImageSource>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('pet-image-camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(sheetContext, PetImageSource.camera),
              ),
              ListTile(
                key: const ValueKey('pet-image-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () =>
                    Navigator.pop(sheetContext, PetImageSource.gallery),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Center(child: Text('取消')),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _uploadAvatar(source);
  }

  Future<void> _uploadAvatar(PetImageSource source) async {
    final result = await _controller.pickAndUploadAvatar(
      source,
      context: context,
    );
    if (!mounted) return;
    switch (result.status) {
      case PetAvatarUploadStatus.cancelled:
        return;
      case PetAvatarUploadStatus.uploaded:
        _showMessage('头像上传成功');
      case PetAvatarUploadStatus.failed:
      case PetAvatarUploadStatus.busy:
        _showMessage(result.message ?? '头像上传失败，请稍后重试');
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final result = await _controller.save();
      if (mounted) Navigator.of(context).pop(result);
    } on PetValidationException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('宠物资料保存失败，请稍后重试');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.delete_outline_rounded),
        title: const Text('删除宠物档案'),
        content: const Text('确定要删除这个宠物吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await _controller.delete();
      if (mounted) Navigator.of(context).pop(result);
    } on Object {
      if (mounted) _showMessage('删除失败，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FormFieldBlock extends StatelessWidget {
  const _FormFieldBlock({
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: petDesignPx(context, 26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: petDesignPx(context, 30),
                  height: 34 / 30,
                  color: const Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: petDesignPx(context, 24),
                    height: 32 / 24,
                    color: const Color(0xFFEF4444),
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
          SizedBox(height: petDesignPx(context, 10)),
          child,
        ],
      ),
    );
  }
}

class _TextControl extends StatelessWidget {
  const _TextControl({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.enabled,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(petDesignPx(context, 10));
    final normalBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: petBorderColor,
        width: petDesignPx(context, 1),
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: petPrimaryColor,
        width: petDesignPx(context, 2),
      ),
    );

    return SizedBox(
      height: petDesignPx(context, 100),
      child: TextField(
        controller: controller,
        enabled: enabled,
        expands: true,
        minLines: null,
        maxLines: null,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        scrollPadding: const EdgeInsets.only(bottom: 180),
        textAlignVertical: TextAlignVertical.center,
        buildCounter: maxLength == null
            ? null
            : (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: petDesignPx(context, 30),
          height: 36 / 30,
          color: petTextPrimaryColor,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: petDesignPx(context, 30),
            height: 36 / 30,
            color: petTextTertiaryColor,
            letterSpacing: 0,
          ),
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    left: petDesignPx(context, 8),
                    right: petDesignPx(context, 16),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      suffix!,
                      style: TextStyle(
                        fontSize: petDesignPx(context, 30),
                        height: 36 / 30,
                        color: petTextTertiaryColor,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: petDesignPx(context, 16),
          ),
          border: normalBorder,
          enabledBorder: normalBorder,
          disabledBorder: normalBorder,
          focusedBorder: focusedBorder,
        ),
      ),
    );
  }
}

class _SelectControl extends StatelessWidget {
  const _SelectControl({
    super.key,
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  final String value;
  final bool placeholder;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(petDesignPx(context, 10)),
        side: BorderSide(color: petBorderColor, width: petDesignPx(context, 1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: petDesignPx(context, 100),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: petDesignPx(context, 16)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: petDesignPx(context, 30),
                      height: 36 / 30,
                      color: placeholder
                          ? petTextTertiaryColor
                          : petTextPrimaryColor,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                SizedBox(width: petDesignPx(context, 8)),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: petDesignPx(context, 28),
                  color: petTextTertiaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentOption<T> {
  const _SegmentOption(this.value, this.label);

  final T value;
  final String label;
}

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    super.key,
    required this.selected,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final T selected;
  final List<_SegmentOption<T>> options;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: petDesignPx(context, 108),
      padding: EdgeInsets.all(petDesignPx(context, 4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(petDesignPx(context, 10)),
        border: Border.all(
          color: petBorderColor,
          width: petDesignPx(context, 1),
        ),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: identical(option, options.last)
                      ? 0
                      : petDesignPx(context, 4),
                ),
                child: _SegmentButton<T>(
                  option: option,
                  selected: selected == option.value,
                  enabled: enabled,
                  onTap: () => onChanged(option.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _SegmentOption<T> option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? petPrimaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(petDesignPx(context, 12)),
      elevation: selected ? petDesignPx(context, 2) : 0,
      shadowColor: petPrimaryColor.withValues(alpha: 0.3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Center(
          child: Text(
            option.label,
            style: TextStyle(
              fontSize: petDesignPx(context, 30),
              height: 34 / 30,
              color: selected ? Colors.white : petTextSecondaryColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _PetCategoryPickerItem {
  const _PetCategoryPickerItem(this.value);

  final PetCategory value;

  @override
  String toString() => value.name;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(size.width, size.height) / 2;
    final dashAngle = 7 / radius;
    final gapAngle = 5 / radius;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (var angle = 0.0; angle < math.pi * 2; angle += dashAngle + gapAngle) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        angle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _EditLoadError extends StatelessWidget {
  const _EditLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: petTextTertiaryColor,
            ),
            const SizedBox(height: 14),
            const Text(
              '宠物资料加载失败',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('pet-edit-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditInitialLoading extends StatelessWidget {
  const _EditInitialLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: PetGradientBackground(
        child: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: petPrimaryColor),
          ),
        ),
      ),
    );
  }
}
