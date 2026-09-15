import 'dart:math' as math;
import 'dart:ui';

const double chatMediaMaxDisplayExtent = 200;
const double chatMediaViewportWidthFraction = 0.5;

Size chatMediaDisplaySize({
  required double viewportWidth,
  required double availableWidth,
  int? sourceWidth,
  int? sourceHeight,
  required double fallbackAspectRatio,
}) {
  final viewportLimit = viewportWidth.isFinite && viewportWidth > 0
      ? viewportWidth * chatMediaViewportWidthFraction
      : chatMediaMaxDisplayExtent;
  final availableLimit = availableWidth.isFinite && availableWidth > 0
      ? availableWidth
      : chatMediaMaxDisplayExtent;
  final maxExtent = math.max(
    1.0,
    math.min(
      chatMediaMaxDisplayExtent,
      math.min(viewportLimit, availableLimit),
    ),
  );
  final aspectRatio =
      sourceWidth != null &&
          sourceHeight != null &&
          sourceWidth > 0 &&
          sourceHeight > 0
      ? sourceWidth / sourceHeight
      : (fallbackAspectRatio.isFinite && fallbackAspectRatio > 0
            ? fallbackAspectRatio
            : 1.0);

  return aspectRatio >= 1
      ? Size(maxExtent, maxExtent / aspectRatio)
      : Size(maxExtent * aspectRatio, maxExtent);
}
