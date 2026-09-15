import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';

import '../../../../core/media/gallery_media_picker.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../../friends/presentation/pages/friend_video_player_page.dart';
import '../../../pets/domain/pet_models.dart';
import '../../domain/lost_found_models.dart';
import '../lost_found_design.dart';

class LostFoundEditorPage extends StatefulWidget {
  const LostFoundEditorPage({
    super.key,
    required this.gateway,
    this.initialType = LostFoundRecordType.lost,
    this.initialRecord,
    this.galleryMediaPicker,
  });

  final LostFoundGateway gateway;
  final LostFoundRecordType initialType;
  final LostFoundRecord? initialRecord;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<LostFoundEditorPage> createState() => _LostFoundEditorPageState();
}

class _LostFoundEditorPageState extends State<LostFoundEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _petNameController;
  late final TextEditingController _petCategoryController;
  late final TextEditingController _petBreedController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _descriptionController;
  late final GalleryMediaPicker _galleryMediaPicker;
  late LostFoundRecordType _recordType;
  late List<String> _images;
  late String _videoUrl;
  late String _videoCoverUrl;

  List<Pet> _pets = const [];
  int? _selectedPetId;
  late _PetSource _petSource;
  bool _loadingPets = true;
  bool _mediaUploading = false;
  bool _submitting = false;
  String? _loadError;

  bool get _editing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    _recordType = record?.recordType ?? widget.initialType;
    _selectedPetId = record?.petId;
    _petSource = record != null && record.petId == null
        ? _PetSource.manual
        : _PetSource.profile;
    _petNameController = TextEditingController(text: record?.displayPetName);
    _petCategoryController = TextEditingController(
      text: record?.petCategory.isNotEmpty == true
          ? record!.petCategory
          : record?.pet?.categoryName,
    );
    _petBreedController = TextEditingController(
      text: record?.petBreed.isNotEmpty == true
          ? record!.petBreed
          : record?.pet?.subCategoryName,
    );
    _contactNameController = TextEditingController(text: record?.contactName);
    _contactPhoneController = TextEditingController(text: record?.contactPhone);
    _descriptionController = TextEditingController(text: record?.description);
    _images = [...?record?.images];
    _videoUrl = record?.videoUrl ?? '';
    _videoCoverUrl = record?.videoCoverUrl ?? '';
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    unawaited(_loadPets());
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _petCategoryController.dispose();
    _petBreedController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    try {
      final pets = await widget.gateway.loadLostFoundPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loadingPets = false;
        _loadError = null;
        if (_selectedPetId != null &&
            !_pets.any((pet) => pet.id == _selectedPetId)) {
          _selectedPetId = null;
        }
        if (!_editing && _pets.isEmpty) {
          _petSource = _PetSource.manual;
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPets = false;
        _loadError = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LostFoundGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _EditorHeader(
                title: _editing ? '编辑信息' : '发布信息',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    key: const ValueKey('lost-found-editor-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      _buildTypeSelector(),
                      const SizedBox(height: 12),
                      _buildBasicSection(),
                      const SizedBox(height: 12),
                      _buildDescriptionSection(),
                      const SizedBox(height: 12),
                      _buildMediaSection(),
                      const SizedBox(height: 12),
                      _buildTips(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: lostFoundCardDecoration(radius: 13),
      child: Row(
        children: LostFoundRecordType.values
            .map((type) {
              final selected = _recordType == type;
              return Expanded(
                child: InkWell(
                  key: ValueKey('lost-found-editor-type-${type.wireValue}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: _submitting
                      ? null
                      : () => setState(() => _recordType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? lostFoundBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type == LostFoundRecordType.lost
                              ? Icons.search_rounded
                              : Icons.home_rounded,
                          size: 19,
                          color: selected
                              ? Colors.white
                              : lostFoundTextSecondary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          type == LostFoundRecordType.lost ? '发布走失' : '发布领养',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : lostFoundTextSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildBasicSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lostFoundCardDecoration(radius: 13),
      child: Column(
        children: [
          const LostFoundSectionTitle(
            icon: Icons.badge_outlined,
            title: '基本信息',
          ),
          const SizedBox(height: 16),
          _buildPetSourceSelector(),
          const SizedBox(height: 14),
          if (_petSource == _PetSource.manual)
            _buildManualPetFields()
          else if (_loadingPets)
            const SizedBox(
              height: 58,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            _InlineError(message: _loadError!, onRetry: _loadPets)
          else
            _buildPetPickerField(),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('lost-found-contact-name-field'),
            controller: _contactNameController,
            enabled: !_submitting,
            maxLength: 20,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              label: '联系人姓名',
              icon: Icons.person_outline_rounded,
              hint: '请输入联系人姓名',
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            key: const ValueKey('lost-found-contact-phone-field'),
            controller: _contactPhoneController,
            enabled: !_submitting,
            maxLength: 11,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              label: '联系电话',
              icon: Icons.phone_outlined,
              hint: '请输入手机号码',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lostFoundCardDecoration(radius: 13),
      child: Column(
        children: [
          LostFoundSectionTitle(
            icon: Icons.edit_note_rounded,
            title: _recordType == LostFoundRecordType.lost ? '走失描述' : '领养说明',
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('lost-found-description-field'),
            controller: _descriptionController,
            enabled: !_submitting,
            minLines: 6,
            maxLines: 9,
            maxLength: 500,
            decoration: _fieldDecoration(
              label: '详细描述',
              hint: _recordType == LostFoundRecordType.lost
                  ? '请描述走失时间、地点、宠物特征等关键信息'
                  : '请介绍宠物性格、健康状况和领养要求',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lostFoundCardDecoration(radius: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LostFoundSectionTitle(
            icon: Icons.perm_media_outlined,
            title: '图片与视频',
            trailing: Text(
              '${_images.length}/9',
              style: const TextStyle(
                color: lostFoundTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_images.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final url = resolveAssetUrl(_images[index]);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LostFoundNetworkImage(url: url),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _MediaRemoveButton(
                          onPressed: _mediaUploading || _submitting
                              ? null
                              : () => setState(() => _images.removeAt(index)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_images.isNotEmpty) const SizedBox(height: 10),
          if (_videoUrl.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LostFoundNetworkImage(
                      url: resolveAssetUrl(_videoCoverUrl),
                      placeholderIcon: Icons.videocam_rounded,
                    ),
                    Center(
                      child: IconButton.filled(
                        tooltip: '预览视频',
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                FriendVideoPlayerPage(videoUrl: _videoUrl),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: _MediaRemoveButton(
                        onPressed: _mediaUploading || _submitting
                            ? null
                            : () => setState(() {
                                _videoUrl = '';
                                _videoCoverUrl = '';
                              }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('lost-found-add-images'),
                  onPressed:
                      _mediaUploading || _submitting || _images.length >= 9
                      ? null
                      : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('添加图片'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('lost-found-add-video'),
                  onPressed: _mediaUploading || _submitting ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(_videoUrl.isEmpty ? '添加视频' : '更换视频'),
                ),
              ),
            ],
          ),
          if (_mediaUploading) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 9),
                Text('媒体上传中，请稍候…'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTips() {
    final lost = _recordType == LostFoundRecordType.lost;
    return Container(
      key: const ValueKey('lost-found-editor-tips'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE6EFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: lostFoundBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lost
                  ? '清晰照片、走失地点和明显特征，能让大家更快提供有效线索。'
                  : '请如实说明健康状况和领养要求，并认真核验领养人信息。',
              style: const TextStyle(
                color: Color(0xFF365683),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF),
        border: Border(top: BorderSide(color: lostFoundBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('lost-found-submit'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7E97FA),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _submitting || _mediaUploading ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_editing ? Icons.save_rounded : Icons.send_rounded),
            label: Text(_editing ? '保存修改' : '确认发布'),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterStyle: const TextStyle(fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: lostFoundBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: lostFoundBorder),
      ),
    );
  }

  Widget _buildPetPickerField() {
    final selectedPet = _petForId(_selectedPetId);
    final placeholder = _pets.isEmpty ? '请先在宠物档案中添加宠物' : '请选择宠物';
    return Material(
      key: const ValueKey('lost-found-pet-field'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _submitting || _pets.isEmpty ? null : _openPetPicker,
        child: InputDecorator(
          isEmpty: selectedPet == null,
          decoration: _fieldDecoration(label: '选择宠物', icon: Icons.pets_rounded)
              .copyWith(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: const Icon(Icons.chevron_right_rounded),
              ),
          child: Text(
            selectedPet == null
                ? placeholder
                : '${selectedPet.name}  ·  ${selectedPet.breedLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selectedPet == null
                  ? lostFoundTextSecondary
                  : lostFoundText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetSourceSelector() {
    return Container(
      key: const ValueKey('lost-found-pet-source'),
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _PetSource.values
            .map((source) {
              final selected = _petSource == source;
              return Expanded(
                child: InkWell(
                  key: ValueKey('lost-found-pet-source-${source.name}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: _submitting ? null : () => _selectPetSource(source),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x140F172A),
                                blurRadius: 5,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(source.icon, size: 17, color: lostFoundBlue),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            source.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? lostFoundText
                                  : lostFoundTextSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  void _selectPetSource(_PetSource source) {
    if (_petSource == source) return;
    if (source == _PetSource.manual) {
      final selectedPet = _petForId(_selectedPetId);
      if (selectedPet != null) {
        if (_petNameController.text.trim().isEmpty) {
          _petNameController.text = selectedPet.name;
        }
        if (_petCategoryController.text.trim().isEmpty) {
          _petCategoryController.text = selectedPet.category?.name ?? '';
        }
        if (_petBreedController.text.trim().isEmpty) {
          _petBreedController.text = selectedPet.subCategory?.name ?? '';
        }
      }
    }
    setState(() => _petSource = source);
  }

  Widget _buildManualPetFields() {
    return Column(
      children: [
        TextFormField(
          key: const ValueKey('lost-found-manual-pet-name'),
          controller: _petNameController,
          enabled: !_submitting,
          maxLength: 50,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: '宠物名称',
            icon: Icons.pets_outlined,
            hint: '请输入宠物名称',
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          key: const ValueKey('lost-found-manual-pet-category'),
          controller: _petCategoryController,
          enabled: !_submitting,
          maxLength: 50,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: '宠物类别',
            icon: Icons.category_outlined,
            hint: '如：猫、狗、鸟',
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          key: const ValueKey('lost-found-manual-pet-breed'),
          controller: _petBreedController,
          enabled: !_submitting,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: '宠物品种',
            icon: Icons.info_outline_rounded,
            hint: '如：中华田园犬',
          ),
        ),
      ],
    );
  }

  Pet? _petForId(int? petId) {
    if (petId == null) return null;
    for (final pet in _pets) {
      if (pet.id == petId) return pet;
    }
    return null;
  }

  void _openPetPicker() {
    final options = _pets.map(_PetPickerOption.new).toList(growable: false);
    final selectedPet = _petForId(_selectedPetId);
    final selectedOption = selectedPet == null
        ? null
        : options.firstWhere((option) => option.pet.id == selectedPet.id);
    final style = DefaultPickerStyle(haveRadius: true, title: '选择宠物')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = lostFoundText;

    Pickers.showSinglePicker(
      context,
      data: options,
      selectData: selectedOption,
      pickerStyle: style,
      onConfirm: (_, index) {
        if (!mounted) return;
        setState(() => _selectedPetId = options[index].pet.id);
      },
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
        maxWidth: 1800,
        maxHeight: 1800,
        onLimitExceeded: (_, _) => exceededLimit = true,
      );
      if (selected.isEmpty || !mounted) return;
      final queue = selected.take(available).toList(growable: false);
      setState(() => _mediaUploading = true);
      var failed = 0;
      final uploaded = <String>[];
      for (final file in queue) {
        try {
          final result = await widget.gateway.uploadLostFoundImage(
            filePath: file.path,
            filename: file.name,
          );
          if (result.url.isNotEmpty) uploaded.add(result.url);
        } on Object {
          failed++;
        }
      }
      if (!mounted) return;
      setState(() {
        _images = [..._images, ...uploaded].take(9).toList(growable: true);
        _mediaUploading = false;
      });
      if (failed > 0) {
        _showMessage(uploaded.isEmpty ? '图片上传失败，请稍后重试' : '部分图片上传失败，请重试');
      } else if (exceededLimit) {
        _showMessage('最多只能上传9张图片，本次已添加前$available张');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _mediaUploading = false);
      _showMessage('选择图片失败：$error');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final selected = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.video,
        maxVideoDuration: const Duration(minutes: 3),
      );
      if (selected.isEmpty || !mounted) return;
      final file = selected.single;
      setState(() => _mediaUploading = true);
      final result = await widget.gateway.uploadLostFoundVideo(
        filePath: file.path,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _videoUrl = result.url;
        _videoCoverUrl = result.thumbnailUrl;
        _mediaUploading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _mediaUploading = false);
      _showMessage('视频上传失败：$error');
    }
  }

  Future<void> _submit() async {
    final draft = LostFoundDraft(
      petId: _petSource == _PetSource.profile ? _selectedPetId : null,
      petName: _petNameController.text,
      petCategory: _petCategoryController.text,
      petBreed: _petBreedController.text,
      recordType: _recordType,
      contactName: _contactNameController.text,
      contactPhone: _contactPhoneController.text,
      description: _descriptionController.text,
      images: _images,
      videoUrl: _videoUrl,
      videoCoverUrl: _videoCoverUrl,
      isFound: widget.initialRecord?.isFound ?? false,
    );
    final validationMessage = draft.validate();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }
    setState(() => _submitting = true);
    try {
      final record = widget.initialRecord;
      if (record == null) {
        await widget.gateway.createLostFoundRecord(draft);
      } else {
        await widget.gateway.updateLostFoundRecord(record.id, draft);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_editing ? '修改成功' : '发布成功')));
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('${_editing ? '修改' : '发布'}失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PetSource {
  profile('宠物档案', Icons.folder_shared_outlined),
  manual('手动填写', Icons.edit_outlined);

  const _PetSource(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _PetPickerOption {
  const _PetPickerOption(this.pet);

  final Pet pet;

  @override
  String toString() => '${pet.name}  ·  ${pet.breedLabel}';
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: lostFoundText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MediaRemoveButton extends StatelessWidget {
  const _MediaRemoveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: '移除',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      style: IconButton.styleFrom(backgroundColor: const Color(0x990F172A)),
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded, size: 17),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}
