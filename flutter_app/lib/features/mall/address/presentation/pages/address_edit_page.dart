import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/mall_widgets.dart';
import '../../domain/address_models.dart';
import '../../domain/region_models.dart';
import '../address_controller.dart';
import '../widgets/region_picker.dart';

class AddressEditPage extends StatefulWidget {
  const AddressEditPage({super.key, required this.controller, this.existing});

  final AddressController controller;
  final ShippingAddress? existing;

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  late final _name = TextEditingController(text: widget.existing?.receiverName);
  late final _phone = TextEditingController(
    text: widget.existing?.receiverPhone,
  );
  late final _detail = TextEditingController(
    text: widget.existing?.detailAddress,
  );
  late RegionValue? _region = widget.existing == null
      ? null
      : RegionValue(
          provinceCode: widget.existing!.provinceCode,
          provinceName: widget.existing!.provinceName,
          cityCode: widget.existing!.cityCode,
          cityName: widget.existing!.cityName,
          districtCode: widget.existing!.districtCode,
          districtName: widget.existing!.districtName,
        );
  late bool _isDefault = widget.existing?.isDefault ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mallBackground,
      appBar: AppBar(title: Text(widget.existing == null ? '新增地址' : '编辑地址')),
      body: AutofillGroup(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _field(
              _name,
              fieldKey: const ValueKey('address-name-field'),
              label: '收货人',
              hint: '请输入收货人姓名',
              maxLength: 20,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 18),
            _field(
              _phone,
              fieldKey: const ValueKey('address-phone-field'),
              label: '手机号',
              hint: '请输入手机号',
              maxLength: 11,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 18),
            _fieldLabel('所在地区'),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: RegionPicker(
                value: _region,
                onChanged: (value) => setState(() => _region = value),
              ),
            ),
            const SizedBox(height: 18),
            _field(
              _detail,
              fieldKey: const ValueKey('address-detail-field'),
              label: '详细地址',
              hint: '请输入街道、楼栋号、门牌号等',
              maxLength: 200,
              multiline: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              autofillHints: const [AutofillHints.fullStreetAddress],
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                value: _isDefault,
                activeTrackColor: mallPrimary,
                onChanged: (value) => setState(() => _isDefault = value),
                title: const Text(
                  '设为默认地址',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required Key fieldKey,
    required String label,
    required String hint,
    required int maxLength,
    bool multiline = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 8),
        SizedBox(
          height: multiline ? 112 : 52,
          child: TextField(
            key: fieldKey,
            controller: controller,
            maxLength: maxLength,
            maxLines: multiline ? null : 1,
            expands: multiline,
            textAlignVertical: multiline
                ? TextAlignVertical.top
                : TextAlignVertical.center,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
            scrollPadding: const EdgeInsets.only(bottom: 140),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 2),
        const Text('*', style: TextStyle(color: Color(0xFFEF4444))),
      ],
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final region = _region;
    if (region == null) {
      showMallMessage(context, '请选择所在地区', error: true);
      return;
    }
    final input = AddressInput(
      receiverName: _name.text,
      receiverPhone: _phone.text,
      provinceCode: region.provinceCode,
      provinceName: region.provinceName,
      cityCode: region.cityCode,
      cityName: region.cityName,
      districtCode: region.districtCode,
      districtName: region.districtName,
      detailAddress: _detail.text,
      isDefault: _isDefault,
    );
    final error = input.validate();
    if (error != null) {
      showMallMessage(context, error, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.save(existing: widget.existing, input: input);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showMallMessage(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
