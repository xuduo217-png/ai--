import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/platform/external_uri_launcher.dart';
import '../../../../core/widgets/app_permission_dialog.dart';
import '../../domain/emergency_models.dart';
import '../../platform/emergency_location_gateway.dart';
import '../emergency_controller.dart';
import '../widgets/emergency_widgets.dart';
import 'aid_guide_detail_page.dart';
import 'aid_guide_list_page.dart';

class EmergencyCenterPage extends StatefulWidget {
  const EmergencyCenterPage({
    super.key,
    required this.gateway,
    this.locationGateway = const MethodChannelEmergencyLocationGateway(),
    this.uriLauncher = const MethodChannelExternalUriLauncher(),
  });

  final EmergencyGateway gateway;
  final EmergencyLocationGateway locationGateway;
  final ExternalUriLauncher uriLauncher;

  @override
  State<EmergencyCenterPage> createState() => _EmergencyCenterPageState();
}

class _EmergencyCenterPageState extends State<EmergencyCenterPage>
    with WidgetsBindingObserver {
  late final EmergencyController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = EmergencyController(
      gateway: widget.gateway,
      locationGateway: widget.locationGateway,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refreshGrantedLocation());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: emergencyBackground,
      appBar: AppBar(
        backgroundColor: emergencyRed,
        foregroundColor: Colors.white,
        surfaceTintColor: emergencyRed,
        title: const Text('紧急求助'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEEEE), emergencyBackground],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => ListView(
            key: const ValueKey('emergency-center-scroll'),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HotlinePanel(
                        config: _controller.config,
                        onCall: _confirmEmergencyCall,
                      ),
                      const SizedBox(height: 14),
                      _GuidePanel(
                        loading: _controller.loadingGuides,
                        guides: _controller.guides,
                        error: _controller.guideError,
                        onRetry: _controller.loadGuides,
                        onOpenAll: _openAllGuides,
                        onOpenGuide: _openGuide,
                      ),
                      const SizedBox(height: 20),
                      _NearbyHospitalSection(
                        state: _controller.nearbyState,
                        hospitals: _controller.hospitals,
                        error: _controller.locationError,
                        onRequestLocation: _requestNearbyHospitals,
                        onOpenSettings: _openLocationSettings,
                        onNavigate: _navigateToHospital,
                        onCall: _confirmHospitalCall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestNearbyHospitals() {
    return _controller.requestNearbyHospitals(() async {
      if (defaultTargetPlatform != TargetPlatform.android) return true;
      return showAppPermissionDialog(
        context: context,
        icon: Icons.location_on_rounded,
        title: '允许访问位置信息',
        description: '位置信息仅用于查找并排序附近的宠物医院。',
        assurances: const ['只在查找附近医院时访问位置', '不会将位置用于其他用途'],
        confirmText: '继续',
        cancelText: '暂不需要',
        accentColor: emergencyRed,
        confirmButtonKey: const ValueKey('emergency-location-confirm'),
        cancelButtonKey: const ValueKey('emergency-location-cancel'),
      );
    });
  }

  Future<void> _openLocationSettings() async {
    final opened = await _controller.openLocationSettings();
    if (!mounted || opened) return;
    _showMessage('无法打开系统设置，请手动开启定位权限');
  }

  Future<void> _confirmEmergencyCall() =>
      _callPhone(_controller.config.emergencyHotline);

  Future<void> _confirmHospitalCall(String phone) => _callPhone(phone);

  Future<void> _callPhone(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.isEmpty) {
      _showMessage('暂未提供联系电话');
      return;
    }
    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await _launchUri(uri)) {
      await Clipboard.setData(ClipboardData(text: normalized));
      if (mounted) _showMessage('无法打开拨号界面，号码已复制');
    }
  }

  Future<void> _navigateToHospital(NearbyHospital hospital) async {
    final uri = buildHospitalNavigationUri(hospital);
    if (!await _launchUri(uri) && mounted) {
      _showMessage('无法打开地图导航，请稍后重试');
    }
  }

  Future<bool> _launchUri(Uri uri) async {
    try {
      return widget.uriLauncher.launch(uri);
    } on Object {
      return false;
    }
  }

  void _openGuide(AidGuide guide) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            AidGuideDetailPage(gateway: widget.gateway, guideId: guide.id),
      ),
    );
  }

  void _openAllGuides() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AidGuideListPage(gateway: widget.gateway),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

Uri buildHospitalNavigationUri(NearbyHospital hospital) {
  return Uri.https('uri.amap.com', '/navigation', {
    'to': '${hospital.longitude},${hospital.latitude},${hospital.name}',
    'mode': 'car',
    'policy': '1',
    'src': 'com.good.pet.hospital',
    'coordinate': 'gaode',
    'callnative': '1',
  });
}

class _HotlinePanel extends StatelessWidget {
  const _HotlinePanel({required this.config, required this.onCall});

  final EmergencyCenterConfig config;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return EmergencyPanel(
      child: Column(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFFFE7E8),
            child: Icon(
              Icons.phone_in_talk_rounded,
              color: emergencyRed,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '紧急求助热线',
            style: TextStyle(
              color: Color(0xFF292325),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          if (config.emergencyTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              config.emergencyTime,
              style: const TextStyle(color: Color(0xFF766B6D), fontSize: 14),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('emergency-hotline-call'),
              onPressed: onCall,
              style: FilledButton.styleFrom(backgroundColor: emergencyRed),
              icon: const Icon(Icons.call_rounded),
              label: const Text('立即拨打急救热线'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '紧急热线：${config.emergencyHotline}',
            style: const TextStyle(color: emergencyRed, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.loading,
    required this.guides,
    required this.error,
    required this.onRetry,
    required this.onOpenAll,
    required this.onOpenGuide,
  });

  final bool loading;
  final List<AidGuide> guides;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onOpenAll;
  final ValueChanged<AidGuide> onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('emergency-guide-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '常见急救指南',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('emergency-view-all-guides'),
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  foregroundColor: emergencyRed,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '查看全部',
                  style: TextStyle(fontSize: 14, letterSpacing: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              height: 96,
              child: Center(
                child: CircularProgressIndicator(color: emergencyRed),
              ),
            )
          else if (error != null)
            EmergencyEmptyState(
              icon: Icons.cloud_off_outlined,
              title: error!,
              action: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            )
          else if (guides.isEmpty)
            const EmergencyEmptyState(
              icon: Icons.medical_information_outlined,
              title: '暂无急救指南',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 10,
                  children: [
                    for (final guide in guides)
                      SizedBox(
                        width: itemWidth,
                        child: Material(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(7.5),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('emergency-guide-${guide.id}'),
                            onTap: () => onOpenGuide(guide),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    AidGuideIcon(
                                      iconUrl: guide.iconUrl,
                                      size: 28,
                                      iconSize: 20,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        guide.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF333333),
                                          fontSize: 14,
                                          height: 1.3,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NearbyHospitalSection extends StatelessWidget {
  const _NearbyHospitalSection({
    required this.state,
    required this.hospitals,
    required this.error,
    required this.onRequestLocation,
    required this.onOpenSettings,
    required this.onNavigate,
    required this.onCall,
  });

  final NearbyHospitalsViewState state;
  final List<NearbyHospital> hospitals;
  final String? error;
  final VoidCallback onRequestLocation;
  final VoidCallback onOpenSettings;
  final ValueChanged<NearbyHospital> onNavigate;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.location_on_rounded, color: emergencyRed),
            SizedBox(width: 6),
            Text(
              '附近急诊医院',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        switch (state) {
          NearbyHospitalsViewState.guide => EmergencyPanel(
            child: EmergencyEmptyState(
              icon: Icons.location_searching_rounded,
              title: '查找附近的宠物医院',
              description: error ?? '开启定位服务，为您推荐最近的急诊医院并提供导航路线。',
              action: FilledButton.icon(
                key: const ValueKey('emergency-nearby-request'),
                onPressed: onRequestLocation,
                style: FilledButton.styleFrom(backgroundColor: emergencyRed),
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('查看附近的医院'),
              ),
            ),
          ),
          NearbyHospitalsViewState.loading => const EmergencyPanel(
            child: SizedBox(
              height: 128,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: emergencyRed),
                    SizedBox(height: 12),
                    Text('正在加载附近医院...'),
                  ],
                ),
              ),
            ),
          ),
          NearbyHospitalsViewState.blocked => EmergencyPanel(
            child: EmergencyEmptyState(
              icon: Icons.location_disabled_outlined,
              title: '位置权限已禁止',
              description: '请在系统设置中开启定位权限后，再查看附近急诊医院。',
              action: FilledButton.icon(
                key: const ValueKey('emergency-open-settings'),
                onPressed: onOpenSettings,
                style: FilledButton.styleFrom(backgroundColor: emergencyRed),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('前往设置'),
              ),
            ),
          ),
          NearbyHospitalsViewState.empty => EmergencyPanel(
            child: EmergencyEmptyState(
              icon: Icons.local_hospital_outlined,
              title: '暂无附近医院信息',
              action: OutlinedButton.icon(
                onPressed: onRequestLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新查找'),
              ),
            ),
          ),
          NearbyHospitalsViewState.error => EmergencyPanel(
            child: EmergencyEmptyState(
              icon: Icons.wrong_location_outlined,
              title: error ?? '附近医院加载失败',
              action: OutlinedButton.icon(
                onPressed: onRequestLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ),
          ),
          NearbyHospitalsViewState.list => Column(
            children: [
              for (final hospital in hospitals) ...[
                _HospitalCard(
                  hospital: hospital,
                  onNavigate: () => onNavigate(hospital),
                  onCall: hospital.phone.isEmpty
                      ? null
                      : () => onCall(hospital.phone),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        },
        if (state == NearbyHospitalsViewState.guide) ...[
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: Color(0xFF218A57),
              ),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  '位置信息仅用于查找附近医院',
                  style: TextStyle(fontSize: 12, color: Color(0xFF69746D)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.hospital,
    required this.onNavigate,
    required this.onCall,
  });

  final NearbyHospital hospital;
  final VoidCallback onNavigate;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final open = hospital.businessStatusText == '营业中';
    return EmergencyPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: hospital.logoUrl.isEmpty
                    ? const Icon(Icons.local_hospital_outlined)
                    : Image.network(
                        hospital.logoUrl,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.local_hospital_outlined),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: open
                                ? const Color(0xFFE9F7EF)
                                : const Color(0xFFF1F2F4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            child: Text(
                              hospital.businessStatusText.isEmpty
                                  ? '营业状态未知'
                                  : hospital.businessStatusText,
                              style: TextStyle(
                                color: open
                                    ? const Color(0xFF218A57)
                                    : const Color(0xFF73777F),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${hospital.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Color(0xFF73777F),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hospital.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF73777F),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('emergency-hospital-navigation-${hospital.id}'),
                  onPressed: onNavigate,
                  style: _hospitalActionButtonStyle(),
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('导航'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('emergency-hospital-call-${hospital.id}'),
                  onPressed: onCall,
                  style: _hospitalActionButtonStyle(),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('联系医院'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

ButtonStyle _hospitalActionButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: emergencyRed,
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFFFB7BA)),
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );
}
