import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/config/api_config.dart';
import '../../../core/media/rich_text_video_player.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/charity_models.dart';

const charityPrimary = Color(0xFF7E97FA);
const charityInk = Color(0xFF1F2937);
const charityMuted = Color(0xFF6B7280);
const charityHint = Color(0xFF9CA3AF);
const charityBorder = Color(0xFFE5E7EB);
const charityDonation = Color(0xFFF59E0B);

double charityDesignPx(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}

class CharityGradientBackground extends StatelessWidget {
  const CharityGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('charity-gradient-background'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: child,
    );
  }
}

class CharityAppBar extends StatelessWidget {
  const CharityAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.action,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const ValueKey('charity-back'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 22,
                    color: charityInk,
                  ),
                ),
                SizedBox(width: 48, height: 48, child: action),
              ],
            ),
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: charityInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CharityCard extends StatelessWidget {
  const CharityCard({
    super.key,
    required this.activity,
    required this.onPressed,
  });

  final CharityActivity activity;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = charityDesignPx(context, 12);
    return Material(
      key: ValueKey('charity-card-${activity.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      elevation: charityDesignPx(context, 2),
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onPressed,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CharityCoverImage(
                  url: activity.coverImageUrl,
                  semanticLabel: '${activity.title}公益封面',
                ),
                Padding(
                  padding: EdgeInsets.all(charityDesignPx(context, 20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: charityInk,
                          fontSize: charityDesignPx(context, 32),
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: charityDesignPx(context, 16)),
                      _CharityMetaRow(activity: activity),
                      if (activity.description.isNotEmpty) ...[
                        SizedBox(height: charityDesignPx(context, 16)),
                        Text(
                          activity.description,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: charityMuted,
                            fontSize: charityDesignPx(context, 28),
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (activity.showProgress) ...[
                        SizedBox(height: charityDesignPx(context, 16)),
                        CharityProgress(activity: activity, compact: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: charityDesignPx(context, 12),
              right: charityDesignPx(context, 12),
              child: CharityStatusBadge(status: activity.status),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharityMetaRow extends StatelessWidget {
  const _CharityMetaRow({required this.activity});

  final CharityActivity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: charityDesignPx(context, 12),
                vertical: charityDesignPx(context, 6),
              ),
              child: Text(
                '公益类型 · ${activity.participantType.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF4F46E5),
                  fontSize: charityDesignPx(context, 22),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (activity.isDonation) ...[
          SizedBox(width: charityDesignPx(context, 12)),
          Flexible(
            child: Text(
              '已捐 ¥${activity.donatedAmount.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: const Color(0xFFD97706),
                fontSize: charityDesignPx(context, 24),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CharityCoverImage extends StatelessWidget {
  const CharityCoverImage({
    super.key,
    required this.url,
    this.semanticLabel = '公益封面',
  });

  final String url;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _CharityImagePlaceholder();
    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : const _CharityImagePlaceholder();
      },
      errorBuilder: (_, _, _) => const _CharityImagePlaceholder(),
    );
  }
}

class _CharityImagePlaceholder extends StatelessWidget {
  const _CharityImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Icon(
            Icons.event_rounded,
            size: charityDesignPx(context, 128),
            color: const Color(0xFFBDBDBD),
          ),
        ),
      ),
    );
  }
}

class CharityStatusBadge extends StatelessWidget {
  const CharityStatusBadge({super.key, required this.status});

  final CharityStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      CharityStatus.active => (
        const Color(0xFF4CAF50),
        const Color(0xFFE8F5E9),
      ),
      CharityStatus.expired => (
        const Color(0xFF9E9E9E),
        const Color(0xFFF5F5F5),
      ),
      CharityStatus.draft => (const Color(0xFFFF9800), const Color(0xFFFFF3E0)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(charityDesignPx(context, 8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: charityDesignPx(context, 12),
          vertical: charityDesignPx(context, 6),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            color: foreground,
            fontSize: charityDesignPx(context, 22),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class CharityProgress extends StatelessWidget {
  const CharityProgress({
    super.key,
    required this.activity,
    this.compact = false,
  });

  final CharityActivity activity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final completed = activity.isCompleted;
    final accent = completed
        ? const Color(0xFF4CAF50)
        : const Color(0xFF2196F3);
    final percent = (activity.progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '任务总进度',
                style: TextStyle(
                  color: charityMuted,
                  fontSize: charityDesignPx(context, 24),
                ),
              ),
            ),
            Text(
              '${activity.completedCheckIns}/${activity.targetCheckIns}($percent%)',
              style: TextStyle(
                color: accent,
                fontSize: charityDesignPx(context, compact ? 24 : 26),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: charityDesignPx(context, 10)),
        ClipRRect(
          borderRadius: BorderRadius.circular(charityDesignPx(context, 5)),
          child: LinearProgressIndicator(
            key: ValueKey('charity-progress-${activity.id}'),
            minHeight: charityDesignPx(context, 10),
            value: activity.progress,
            backgroundColor: charityBorder,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
        if (completed && !compact) ...[
          SizedBox(height: charityDesignPx(context, 12)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(charityDesignPx(context, 8)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: charityDesignPx(context, 10),
              ),
              child: Text(
                '恭喜完成目标！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontSize: charityDesignPx(context, 24),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CharityRichContent extends StatelessWidget {
  const CharityRichContent({
    super.key,
    required this.content,
    this.baseUrl = ApiConfig.baseUrl,
  });

  final String content;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final document = HtmlParser.parseHTML(content);
    for (final image in document.querySelectorAll('img')) {
      final source = image.attributes['src']?.trim() ?? '';
      if (source.isEmpty || source.startsWith('data:')) continue;
      image.attributes['src'] = source.startsWith('//')
          ? 'https:$source'
          : resolveAssetUrl(source, assetBaseUrl: baseUrl);
      image.attributes.remove('width');
      image.attributes.remove('height');
    }

    var videoIndex = 0;
    for (final wrapper in document.querySelectorAll(
      'div[data-w-e-type="video"]',
    )) {
      wrapper.attributes['data-flutter-video-id'] = '${videoIndex++}';
    }
    for (final video in document.querySelectorAll('video')) {
      var ancestor = video.parent;
      var wrappedByWangEditor = false;
      while (ancestor != null) {
        if (ancestor.localName == 'div' &&
            ancestor.attributes['data-w-e-type'] == 'video') {
          wrappedByWangEditor = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      if (wrappedByWangEditor) continue;
      video.attributes['data-flutter-video-id'] = '${videoIndex++}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Html.fromElement(
          documentElement: document,
          shrinkWrap: true,
          extensions: [
            ImageExtension(
              handleAssetImages: false,
              handleDataImages: false,
              builder: (context) => Image.network(
                context.attributes['src'] ?? '',
                width: contentWidth,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 72,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
            MatcherExtension(
              matcher: _matchesCharityRichVideo,
              builder: (context) {
                final videoId =
                    context.attributes['data-flutter-video-id'] ??
                    'raw-${context.node.hashCode}';
                final source = _extractCharityVideoSource(context, baseUrl);
                if (source == null) {
                  return UnavailableRichTextVideo(
                    key: ValueKey('charity-rich-video-unavailable-$videoId'),
                    foregroundColor: charityMuted,
                  );
                }
                return RichTextVideoPlayer(
                  key: ValueKey('charity-rich-video-state-$videoId'),
                  source: source,
                  width: contentWidth,
                  semanticsKey: ValueKey('charity-rich-video-$videoId'),
                  semanticLabel: '公益详情视频播放器',
                  controlKeyPrefix: 'charity-rich-video',
                  accentColor: charityPrimary,
                  autoPlayWhenVisible: true,
                );
              },
            ),
          ],
          doNotRenderTheseTags: const {
            'script',
            'style',
            'iframe',
            'object',
            'embed',
          },
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              color: charityMuted,
              fontSize: FontSize(charityDesignPx(context, 26)),
              lineHeight: const LineHeight(1.45),
            ),
            'p': Style(margin: Margins.only(bottom: 10)),
            'img': Style(
              display: Display.block,
              width: Width(100, Unit.percent),
              height: Height.auto(),
            ),
          },
        );
      },
    );
  }
}

bool _charityVideoHasWangEditorAncestor(ExtensionContext context) {
  var ancestor = context.element?.parent;
  while (ancestor != null) {
    if (ancestor.localName == 'div' &&
        ancestor.attributes['data-w-e-type'] == 'video') {
      return true;
    }
    ancestor = ancestor.parent;
  }
  return false;
}

bool _matchesCharityRichVideo(ExtensionContext context) {
  if (context.elementName == 'div' &&
      context.attributes['data-w-e-type'] == 'video') {
    return true;
  }
  return context.elementName == 'video' &&
      !_charityVideoHasWangEditorAncestor(context);
}

RichTextVideoSource? _extractCharityVideoSource(
  ExtensionContext context,
  String baseUrl,
) {
  final element = context.element;
  if (element == null) return null;
  final video = context.elementName == 'video'
      ? element
      : element.querySelector('video');
  if (video == null) return null;

  final directSource = video.attributes['src']?.trim();
  final rawSource = directSource?.isNotEmpty == true
      ? directSource
      : video.querySelector('source')?.attributes['src'];
  final uri = _resolveCharityVideoUri(rawSource, baseUrl);
  if (uri == null) return null;

  return RichTextVideoSource(
    uri: uri,
    posterUri: _resolveCharityVideoUri(video.attributes['poster'], baseUrl),
  );
}

Uri? _resolveCharityVideoUri(String? value, String baseUrl) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  final resolved = source.startsWith('//')
      ? 'https:$source'
      : resolveAssetUrl(source, assetBaseUrl: baseUrl);
  final uri = Uri.tryParse(resolved);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}
