import 'package:flutter/material.dart';

import '../../../../core/media/route_aware_video_surface.dart';
import '../../domain/emergency_models.dart';
import '../widgets/aid_guide_rich_content.dart';
import '../widgets/emergency_widgets.dart';

class AidGuideDetailPage extends StatefulWidget {
  const AidGuideDetailPage({
    super.key,
    required this.gateway,
    required this.guideId,
  });

  final EmergencyGateway gateway;
  final int guideId;

  @override
  State<AidGuideDetailPage> createState() => _AidGuideDetailPageState();
}

class _AidGuideDetailPageState extends State<AidGuideDetailPage> {
  late Future<AidGuide> _guideFuture;

  @override
  void initState() {
    super.initState();
    _guideFuture = widget.gateway.loadAidGuide(widget.guideId);
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: Scaffold(
        backgroundColor: emergencyBackground,
        appBar: AppBar(
          backgroundColor: emergencyRed,
          foregroundColor: Colors.white,
          surfaceTintColor: emergencyRed,
          title: const Text('急救指南详情'),
        ),
        body: FutureBuilder<AidGuide>(
          future: _guideFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: emergencyRed),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return EmergencyEmptyState(
                icon: Icons.error_outline_rounded,
                title: '指南详情加载失败',
                description: '请检查网络连接后重试。',
                action: FilledButton.icon(
                  onPressed: _retry,
                  style: FilledButton.styleFrom(backgroundColor: emergencyRed),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              );
            }
            return _GuideDetail(guide: snapshot.data!);
          },
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _guideFuture = widget.gateway.loadAidGuide(widget.guideId);
    });
  }
}

class _GuideDetail extends StatelessWidget {
  const _GuideDetail({required this.guide});

  final AidGuide guide;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('aid-guide-detail-scroll'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmergencyPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AidGuideIcon(
                            iconUrl: guide.iconUrl,
                            size: 58,
                            iconSize: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              guide.title,
                              style: const TextStyle(
                                color: Color(0xFF292325),
                                fontSize: 21,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (guide.category != null)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE7E8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  guide.category!.name,
                                  style: const TextStyle(
                                    color: emergencyRed,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            '发布于 ${_formatDate(guide.displayDate)}',
                            style: const TextStyle(
                              color: Color(0xFF7A7072),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                EmergencyPanel(
                  child: AidGuideRichContent(content: guide.content),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) => '${date.year}年${date.month}月${date.day}日';
