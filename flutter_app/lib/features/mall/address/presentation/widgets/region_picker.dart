import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';

import '../../domain/region_models.dart';

class RegionPicker extends StatefulWidget {
  const RegionPicker({super.key, required this.value, required this.onChanged});

  final RegionValue? value;
  final ValueChanged<RegionValue> onChanged;

  @override
  State<RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<RegionPicker> {
  RegionPickerData? _pickerData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final source = await rootBundle.loadString('assets/data/address.json');
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final levels = decoded.map(
      (key, value) => MapEntry(
        key,
        (value as Map).map(
          (childKey, childValue) => MapEntry('$childKey', '$childValue'),
        ),
      ),
    );
    if (mounted) {
      setState(() => _pickerData = RegionPickerData(RegionData(levels)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('address-region-picker'),
      onTap: _pickerData == null ? null : _openPicker,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.fromLTRB(16, 14, 8, 14),
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.chevron_right, size: 22),
          suffixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        child: Text(
          widget.value?.displayName ??
              (_pickerData == null ? '地区加载中...' : '请选择地区'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.value == null
                ? const Color(0xFF9298A5)
                : const Color(0xFF22252B),
          ),
        ),
      ),
    );
  }

  void _openPicker() {
    final pickerData = _pickerData!;
    final style = DefaultPickerStyle(haveRadius: true, title: '选择所在地区')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = const Color(0xFF22252B);
    Pickers.showMultiLinkPicker(
      context,
      data: pickerData.tree,
      columnNum: 3,
      selectData: pickerData.selectionFor(widget.value),
      pickerStyle: style,
      onConfirm: (selection, _) {
        widget.onChanged(pickerData.valueFor(selection));
      },
    );
  }
}
