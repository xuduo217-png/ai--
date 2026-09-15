class RegionValue {
  const RegionValue({
    required this.provinceCode,
    required this.provinceName,
    required this.cityCode,
    required this.cityName,
    required this.districtCode,
    required this.districtName,
  });

  final String provinceCode;
  final String provinceName;
  final String cityCode;
  final String cityName;
  final String districtCode;
  final String districtName;

  String get displayName => provinceCode == cityCode
      ? '$provinceName $districtName'
      : '$provinceName $cityName $districtName';
}

class RegionOption {
  const RegionOption(this.code, this.name);
  final String code;
  final String name;

  @override
  String toString() => name;
}

class RegionData {
  const RegionData(this._levels);
  final Map<String, Map<String, String>> _levels;

  List<RegionOption> childrenOf(String code) {
    final values = _levels[code] ?? const {};
    return values.entries
        .map((entry) => RegionOption(entry.key, entry.value))
        .toList(growable: false);
  }

  List<RegionOption> get provinces => childrenOf('86');
}

class RegionPickerData {
  RegionPickerData(RegionData data) : tree = _buildTree(data);

  final Map<RegionOption, Map<RegionOption, List<RegionOption>>> tree;

  List<RegionOption> selectionFor(RegionValue? value) {
    if (value == null) return const [];

    final province = _findByCode(tree.keys, value.provinceCode);
    if (province == null) return const [];

    final cities = tree[province]!;
    final city = _findByCode(cities.keys, value.cityCode);
    if (city == null) return [province];

    final district = _findByCode(cities[city]!, value.districtCode);
    if (district == null) return [province, city];
    return [province, city, district];
  }

  RegionValue valueFor(List<dynamic> selection) {
    if (selection.length != 3 ||
        selection.any((item) => item is! RegionOption)) {
      throw ArgumentError.value(selection, 'selection', '必须包含省、市、区');
    }

    final province = selection[0] as RegionOption;
    final city = selection[1] as RegionOption;
    final district = selection[2] as RegionOption;
    return RegionValue(
      provinceCode: province.code,
      provinceName: province.name,
      cityCode: city.code,
      cityName: city.name,
      districtCode: district.code,
      districtName: district.name,
    );
  }

  static Map<RegionOption, Map<RegionOption, List<RegionOption>>> _buildTree(
    RegionData data,
  ) {
    final tree = <RegionOption, Map<RegionOption, List<RegionOption>>>{};
    for (final province in data.provinces) {
      final sourceCities = data.childrenOf(province.code);
      final cities = <RegionOption, List<RegionOption>>{};
      for (final city in sourceCities) {
        final districts = data.childrenOf(city.code);
        if (districts.isNotEmpty) cities[city] = districts;
      }

      // 港澳数据直接挂在省级节点下，补一个同编码市级节点以保持三列。
      if (cities.isEmpty && sourceCities.isNotEmpty) {
        cities[RegionOption(province.code, province.name)] = sourceCities;
      }
      if (cities.isNotEmpty) tree[province] = cities;
    }
    return tree;
  }

  static RegionOption? _findByCode(
    Iterable<RegionOption> options,
    String code,
  ) {
    for (final option in options) {
      if (option.code == code) return option;
    }
    return null;
  }
}
