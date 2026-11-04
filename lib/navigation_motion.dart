import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'figma_graphics.dart';

const parkingDriveDuration = Duration(seconds: 52);
const parkingEntryEnd = 12 / 52;
const _parkingRouteEnd = 30 / 52;
const parkingJEntranceX = 903.0;
// Derive the boundary from the route, so changing its speed or length cannot
// make the 3D view start after the vehicle has already entered J.
final parkingTopViewEnd = _findJEntryProgress();
const parkingReverseStart = 38 / 52;

// The opening 3D pose is the exact Figma 262:45216 composition. Move through
// that illustration's clear aisle towards its original P-marked parking bay.
const _approachMarkerBounds = Rect.fromLTWH(
  980.902344,
  536.86718,
  177.699219,
  152.950203,
);
const _approachSceneBounds = Rect.fromLTWH(425, -369, 1118, 1289.272705);

// All coordinates belong to the original Figma lot, not to the iPad screen.
// This keeps the car on the aisles while the camera zooms and rotates.
// Three straight aisle-center segments in the original map coordinates:
// entrance -> entrance corner -> lower aisle -> J zone.
Path get parkingAisle => Path()
  ..moveTo(244, 351)
  ..lineTo(333, 273)
  ..lineTo(580, 480)
  ..lineTo(1066, 480);

class VehiclePose {
  const VehiclePose(this.position, this.heading);
  final Offset position;

  /// Clockwise rotation from the top of the display.
  final double heading;
}

VehiclePose sampleDrive(Path path, double progress, {bool reverse = false}) {
  final metric = path.computeMetrics().first;
  final distance = metric.length * progress.clamp(0, 1);
  final tangent = metric.getTangentForOffset(distance)!;
  // Smooth only the heading around a corner; position stays on the straight
  // segments. Otherwise the following camera would snap at each vertex.
  final before = metric.getTangentForOffset(
    (distance - 18).clamp(0, metric.length),
  )!;
  final after = metric.getTangentForOffset(
    (distance + 18).clamp(0, metric.length),
  )!;
  final direction = after.position - before.position;
  return VehiclePose(
    tangent.position,
    math.atan2(direction.dy, direction.dx) +
        (reverse ? -math.pi / 2 : math.pi / 2),
  );
}

double _findJEntryProgress() {
  var before = 0.0;
  var after = _parkingRouteEnd;
  for (var i = 0; i < 48; i++) {
    final middle = (before + after) / 2;
    if (ParkingMotionFrame(middle).hasEnteredJ) {
      after = middle;
    } else {
      before = middle;
    }
  }
  return after;
}

double _segment(double p, double start, double end) =>
    ((p - start) / (end - start)).clamp(0.0, 1.0);
double _smooth(double p) => p * p * (3 - 2 * p);
double _mix(double a, double b, double t) => a + (b - a) * t;

/// One continuous timeline covers entry, top view, 3D approach and reversing.
/// Stage labels change at boundaries, but the car/camera never restart there.
class ParkingMotionFrame {
  ParkingMotionFrame(this.progress, {this.completionProgress = 0});
  final double progress;
  final double completionProgress;
  double get topProgress => _segment(progress, 0, _parkingRouteEnd);
  double get approachProgress =>
      _segment(progress, parkingTopViewEnd, parkingReverseStart);
  double get reverseProgress => _segment(progress, parkingReverseStart, 1);
  VehiclePose get topPose => sampleDrive(parkingAisle, _smooth(topProgress));
  bool get hasEnteredJ =>
      topPose.position.dx >= parkingJEntranceX && topPose.position.dy >= 460;
  // The full original 3D keyframe appears on the first frame inside J.
  double get viewBlend => hasEnteredJ ? 1 : 0;

  // The marker advances relative to the parked cars, while a following camera
  // also translates the scene. Neither layer freezes during the 3D approach.
  double get approachTravel => _smooth(approachProgress);
  Offset get approachPosition => Offset.lerp(
    _approachMarkerBounds.center,
    Offset(_approachMarkerBounds.center.dx, 350),
    approachTravel,
  )!;
  Offset get approachCameraOffset => Offset(0, 140 * approachTravel);
  Offset get approachScreenPosition => approachPosition + approachCameraOffset;

  int get metersRemaining => ((1 - topProgress) * 150).round();
}

class RoadNavigationMotion extends StatelessWidget {
  const RoadNavigationMotion({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final p = _smooth(progress);
    return ClipRect(
      child: Stack(
        children: [
          // Camera follows the vehicle. The slight change of anchor still lets the
          // viewer see the marker advance along the actual blue road.
          Positioned(
            left: 0,
            top: -72 + 72 * p,
            width: 2112,
            height: 792,
            child: Image.asset('assets/driving.png', fit: BoxFit.contain),
          ),
          Positioned(
            left: 1387,
            top: 582 - 25 * p,
            width: 76,
            height: 70,
            child: SvgPicture.asset('assets/figma/blue_position.svg'),
          ),
        ],
      ),
    );
  }
}

class ParkingJourney extends StatelessWidget {
  const ParkingJourney({
    super.key,
    required this.progress,
    this.completionProgress = 0,
  });
  final double progress;
  final double completionProgress;
  @override
  Widget build(BuildContext context) {
    final frame = ParkingMotionFrame(
      progress,
      completionProgress: completionProgress,
    );
    final topView = _TopView(frame: frame);
    final parkingComplete = progress >= 1;
    final cameras = progress >= parkingReverseStart && !parkingComplete;
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xffe4e2dc))),
          if (cameras) const Positioned.fill(child: ParkingCameraStill()),
          if (!cameras && !parkingComplete) ...[
            if (frame.viewBlend < 1)
              Positioned.fill(
                child: Opacity(opacity: 1 - frame.viewBlend, child: topView),
              ),
            if (frame.viewBlend > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: frame.viewBlend,
                  child: ParkingApproachMotion(frame: frame),
                ),
              ),
          ],
          if (parkingComplete) ...[
            if (completionProgress < 1)
              Positioned.fill(
                child: Opacity(
                  opacity: 1 - completionProgress,
                  child: const ParkingCameraStill(),
                ),
              ),
            Positioned.fill(
              child: Opacity(
                opacity: completionProgress,
                child: const _ParkedKeyframe(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Original Figma 3D artwork with independently moving navigation and camera
/// layers. At progress zero every layer occupies its original Figma slot.
class ParkingApproachMotion extends StatelessWidget {
  const ParkingApproachMotion({super.key, required this.frame});
  final ParkingMotionFrame frame;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Transform.translate(
          key: const ValueKey('parking-3d-camera'),
          offset: frame.approachCameraOffset,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: _approachSceneBounds,
                child: Image.asset(
                  // Full original scene, exported without the baked-in marker
                  // so the moving marker is never duplicated. Offscreen artwork
                  // is retained to prevent empty edges as the camera follows.
                  'assets/figma/approach_scene.png',
                  fit: BoxFit.fill,
                ),
              ),
              FigmaGraphic(
                'approach_route',
                clipHeight: frame.approachPosition.dy - 303.871094,
              ),
            ],
          ),
        ),
      ),
      Positioned.fromRect(
        key: const ValueKey('parking-3d-position'),
        rect: Rect.fromCenter(
          center: frame.approachScreenPosition,
          width: _approachMarkerBounds.width,
          height: _approachMarkerBounds.height,
        ),
        child: SvgPicture.asset('assets/figma/approach_position.svg'),
      ),
    ],
  );
}

class _ParkedKeyframe extends StatelessWidget {
  const _ParkedKeyframe();
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 90,
        top: 0,
        width: 1830,
        height: 720,
        child: Image.asset('assets/parked.png', fit: BoxFit.contain),
      ),
    ],
  );
}

class _TopView extends StatelessWidget {
  const _TopView({required this.frame});
  final ParkingMotionFrame frame;
  @override
  Widget build(BuildContext context) {
    final pose = frame.topPose;
    final follow = _smooth(_segment(frame.topProgress, 0, .28));
    final overviewAnchor = pose.position + const Offset(371.43, 50.256);
    final followingAnchor = Offset.lerp(
      overviewAnchor,
      const Offset(1220, 540),
      follow,
    )!;
    final anchor = followingAnchor;
    final zoom = _mix(1, 2.65, follow);
    final rotation = -pose.heading * follow;
    final transform = Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..rotateZ(rotation)
      ..scaleByDouble(zoom, zoom, 1, 1)
      ..translateByDouble(-pose.position.dx, -pose.position.dy, 0, 1);
    return Stack(
      children: [
        Positioned.fill(
          child: Transform(
            transform: transform,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: 1548.57,
                  height: 588.361,
                  child: RepaintBoundary(
                    child: Image.asset(
                      'assets/parking.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: 1548.57,
                  height: 588.361,
                  child: CustomPaint(
                    painter: _RoutePainter(progress: frame.topProgress),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: anchor.dx - 42,
          top: anchor.dy - 39,
          width: 84,
          height: 78,
          child: Transform.rotate(
            angle: pose.heading + rotation,
            child: SvgPicture.asset('assets/figma/green_position.svg'),
          ),
        ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final path = parkingAisle;
    final metric = path.computeMetrics().first;
    final distance = metric.length * _smooth(progress);
    final remaining = metric.extractPath(distance, metric.length);
    canvas.drawPath(
      remaining,
      Paint()
        ..color = const Color(0xfff6f7fc)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      remaining,
      Paint()
        ..color = const Color(0xff01df20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final chevron = Path()
      ..moveTo(-2, -2.2)
      ..lineTo(0, 0)
      ..lineTo(-2, 2.2);
    for (double d = distance + 12; d < metric.length; d += 18) {
      final tangent = metric.getTangentForOffset(d)!;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(math.atan2(tangent.vector.dy, tangent.vector.dx));
      canvas.drawPath(
        chevron,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
    // The selected bay is in the lower row of J, beside the arrival aisle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(989, 419, 19, 33),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xff01df20).withValues(alpha: .7),
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Figma frame 262:61880: a still rear camera on the left and surround camera
/// on the right. The image crops and overlays use the source node geometry.
class ParkingCameraStill extends StatelessWidget {
  const ParkingCameraStill({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '왼쪽 후방카메라 · 오른쪽 360 서라운드 카메라',
    child: Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xffe4e2dc))),
        Positioned(
          left: 90.304688,
          top: -119.703125,
          width: 1395.4375,
          height: 874.676392,
          child: Image.asset(
            'assets/figma/rear_camera.png',
            fit: BoxFit.contain,
          ),
        ),
        const Positioned(
          left: 1451,
          top: 0,
          width: 469,
          height: 720,
          child: SurroundParkingView(),
        ),
      ],
    ),
  );
}

class SurroundParkingView extends StatelessWidget {
  const SurroundParkingView({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '360 서라운드 뷰',
    child: Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xff92959c))),
        Positioned(
          left: 9.0390625,
          top: 0,
          width: 459.9609375,
          height: 720,
          child: Image.asset(
            'assets/figma/surround_view.png',
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          left: 9.0390625,
          top: 317.6347656,
          width: 7,
          height: 96,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        for (final (name, rect) in [
          ('camera_tab', Rect.fromLTWH(186, 0, 100, 41.734375)),
          (
            'camera_label',
            Rect.fromLTWH(218.5390625, 6.7265625, 36.20703125, 14.310546875),
          ),
          (
            'camera_arrow',
            Rect.fromLTWH(223.1015625, 28.833984375, 25.796875, 4.80078125),
          ),
          (
            'camera_arrowhead',
            Rect.fromLTWH(243.359375, 27.119140625, 6.59765625, 7.4140625),
          ),
        ])
          Positioned.fromRect(
            rect: rect,
            child: SvgPicture.asset(
              'assets/figma/$name.svg',
              fit: BoxFit.contain,
            ),
          ),
      ],
    ),
  );
}
