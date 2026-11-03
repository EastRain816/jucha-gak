import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Figma absoluteRenderBounds, measured relative to each source frame.
// Exports are clipped to their source frame; source node bounds are not valid
// image sizes. See assets/figma/manifest.json for the original node IDs.
const _bounds = <String, Rect>{
  'approach_position': Rect.fromLTWH(
    980.902344,
    536.86718,
    177.699219,
    152.950203,
  ),
  'change_map': Rect.fromLTWH(0.000000, 0.000000, 1920.000000, 720.000000),
  'near_map': Rect.fromLTWH(0.000000, 0.000000, 1920.000000, 720.000000),
  'inside_map': Rect.fromLTWH(193.976562, 0.000000, 1425.894531, 720.000000),
  'inside_route': Rect.fromLTWH(1289.285156, 0.000000, 125.808594, 589.294922),
  'approach_map': Rect.fromLTWH(424.964844, 0.000000, 1118.078125, 720.000000),
  'approach_route': Rect.fromLTWH(
    903.687500,
    303.871094,
    194.339844,
    416.128906,
  ),
  'blue_position': Rect.fromLTWH(1257.933594, 595.807103, 67.147751, 61.491862),
  'green_position': Rect.fromLTWH(
    1341.476562,
    543.472904,
    84.813876,
    77.669958,
  ),
  'logo': Rect.fromLTWH(225.925781, 136.223145, 69.101715, 43.588078),
  'card_background': Rect.fromLTWH(
    160.917969,
    30.445312,
    798.523438,
    662.175781,
  ),
  'banner_background': Rect.fromLTWH(
    160.238281,
    30.412109,
    798.523438,
    202.175781,
  ),
  'microphone': Rect.fromLTWH(141.445312, 559.093750, 152.640625, 152.638672),
  'recenter': Rect.fromLTWH(275.882812, 559.093750, 152.640625, 152.638672),
  'legend': Rect.fromLTWH(1410.398438, 30.288086, 489.000000, 63.000000),
  'grid': Rect.fromLTWH(18.699219, 635.413513, 96.000008, 46.933350),
  'turn_right': Rect.fromLTWH(224.527344, 61.800293, 99.222656, 93.693848),
  'turn_left': Rect.fromLTWH(207.320312, 281.269531, 22.000000, 27.865723),
};

class FigmaGraphic extends StatelessWidget {
  const FigmaGraphic(
    this.name, {
    super.key,
    this.onTap,
    this.semanticLabel,
    this.clipHeight,
  });
  final String name;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double? clipHeight;
  @override
  Widget build(BuildContext context) {
    final Widget artwork =
        const {
          'change_map',
          'near_map',
          'inside_map',
          'approach_map',
        }.contains(name)
        ? Image.asset(
            'assets/figma/$name.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        : SvgPicture.asset('assets/figma/$name.svg', fit: BoxFit.contain);
    final Widget image = clipHeight == null
        ? artwork
        : ClipRect(clipper: _TopClip(clipHeight!), child: artwork);
    return Positioned.fromRect(
      rect: _bounds[name]!,
      child: onTap == null
          ? IgnorePointer(child: image)
          : Semantics(
              label: semanticLabel,
              button: true,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: image,
              ),
            ),
    );
  }
}

class _TopClip extends CustomClipper<Rect> {
  const _TopClip(this.height);
  final double height;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, height);
  @override
  bool shouldReclip(_TopClip oldClipper) => height != oldClipper.height;
}
