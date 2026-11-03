import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const parkingDriveDuration = Duration(seconds: 52);
const parkingEntryEnd = 12 / 52;
const parkingTopViewEnd = 30 / 52;
const parkingReverseStart = 38 / 52;

// All coordinates belong to the original Figma lot, not to the iPad screen.
// This keeps the car on the aisles while the camera zooms and rotates.
Path get parkingAisle => Path()
  ..moveTo(190, 280)
  ..cubicTo(230, 305, 290, 350, 360, 350)
  ..lineTo(470, 350)
  ..cubicTo(530, 350, 550, 422, 580, 472)
  ..quadraticBezierTo(585, 480, 600, 480)
  ..lineTo(1060, 480);

Path get reverseManeuver => Path()
  ..moveTo(1000, 340)
  ..cubicTo(1000, 430, 800, 470, 620, 470);

class VehiclePose {
  const VehiclePose(this.position, this.heading);
  final Offset position;

  /// Clockwise rotation from the top of the display.
  final double heading;
}

VehiclePose sampleDrive(Path path, double progress, {bool reverse = false}) {
  final metric = path.computeMetrics().first;
  final tangent = metric.getTangentForOffset(
    metric.length * progress.clamp(0, 1),
  )!;
  return VehiclePose(
    tangent.position,
    math.atan2(tangent.vector.dy, tangent.vector.dx) +
        (reverse ? -math.pi / 2 : math.pi / 2),
  );
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
  double get topProgress => _segment(progress, 0, parkingTopViewEnd);
  double get approachProgress =>
      _segment(progress, parkingTopViewEnd, parkingReverseStart);
  double get reverseProgress => _segment(progress, parkingReverseStart, 1);
  double get viewBlend => _smooth(_segment(approachProgress, 0, .65));
  double get surroundReveal =>
      _smooth(_segment(reverseProgress, 0, .12)) *
      (1 - _smooth(completionProgress));
  VehiclePose get topPose => sampleDrive(parkingAisle, _smooth(topProgress));
  VehiclePose get reversePose =>
      sampleDrive(reverseManeuver, _smooth(reverseProgress), reverse: true);
  VehiclePose get perspectivePose {
    if (progress >= parkingReverseStart) return reversePose;
    final path = Path()
      ..moveTo(1220, 540)
      ..cubicTo(1100, 510, 1000, 430, 1000, 340);
    return sampleDrive(path, _smooth(approachProgress));
  }

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
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xffe4e2dc))),
          if (frame.viewBlend < 1)
            Positioned.fill(
              child: Opacity(
                opacity: 1 - frame.viewBlend,
                child: _TopView(frame: frame),
              ),
            ),
          if (frame.viewBlend > 0)
            Positioned.fill(
              child: Opacity(
                opacity: frame.viewBlend,
                child: _PerspectiveView(frame: frame),
              ),
            ),
          if (frame.surroundReveal > 0)
            Positioned(
              left: 1451 + 469 * (1 - frame.surroundReveal),
              top: 0,
              width: 469,
              height: 720,
              child: SurroundParkingView(progress: frame.reverseProgress),
            ),
        ],
      ),
    );
  }
}

class _TopView extends StatelessWidget {
  const _TopView({required this.frame});
  final ParkingMotionFrame frame;
  @override
  Widget build(BuildContext context) {
    final pose = frame.topPose;
    final follow = _smooth(_segment(frame.topProgress, 0, .28));
    final overviewAnchor = pose.position + const Offset(371.43, 50.256);
    final anchor = Offset.lerp(
      overviewAnchor,
      const Offset(1220, 540),
      follow,
    )!;
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

class _PerspectiveView extends StatelessWidget {
  const _PerspectiveView({required this.frame});
  final ParkingMotionFrame frame;
  @override
  Widget build(BuildContext context) {
    final reverse = frame.reverseProgress;
    final vehicle = frame.perspectivePose;
    final shift = frame.surroundReveal * -85;
    final camera = Matrix4.identity()..translateByDouble(shift, 0, 0, 1);
    // The original Figma sprites already contain the perspective and extrusion.
    // Keep their aspect ratio; translate and yaw the moving car independently.
    return Transform(
      transform: camera,
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform(
              alignment: const Alignment(.15, .4),
              transform: Matrix4.identity()
                ..setEntry(3, 2, .00035)
                ..rotateX((1 - frame.viewBlend) * .28)
                ..scaleByDouble(
                  _mix(1.08, 1, frame.viewBlend),
                  _mix(1.08, 1, frame.viewBlend),
                  1,
                  1,
                ),
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    for (final x in [140.0, 500.0, 1220.0, 1570.0])
                      for (int row = -1; row < 8; row++)
                        if (!(x == 500 && row == 4))
                          Positioned(
                            left: x + (3 - row) * 7,
                            top: row * 112.0,
                            width: 244,
                            height: 107.647,
                            child: SvgPicture.asset(
                              'assets/figma/${(row + (x / 360).round()) % 4 == 0 ? 'parking_car_blue' : 'parking_car'}.svg',
                            ),
                          ),
                    Positioned(
                      left: 500,
                      top: 310,
                      width: 244,
                      height: 199.2,
                      child: SvgPicture.asset(
                        'assets/figma/parking_target.svg',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (reverse < 1)
            Positioned.fill(
              child: CustomPaint(
                painter: _ManeuverGuide(
                  progress: reverse,
                  approach: frame.approachProgress,
                ),
              ),
            ),
          Positioned(
            left: vehicle.position.dx - 110,
            top: vehicle.position.dy - 49,
            width: 220,
            height: 98,
            child: Opacity(
              opacity: _segment(frame.approachProgress, 0, .25),
              child: Transform.rotate(
                angle: reverse > 0
                    ? -.52 * math.sin(math.pi * reverse)
                    : -.15 * (1 - frame.approachProgress),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: SvgPicture.asset('assets/figma/parking_car.svg'),
                    ),
                    if (reverse > 0 && reverse < .98)
                      for (final x in [52.0, 158.0])
                        Positioned(
                          left: x,
                          bottom: 13,
                          width: 12,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: .65),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManeuverGuide extends CustomPainter {
  _ManeuverGuide({required this.progress, required this.approach});
  final double progress, approach;
  @override
  void paint(Canvas canvas, Size size) {
    final path = progress > 0
        ? reverseManeuver
        : (Path()
            ..moveTo(1000, 650)
            ..lineTo(1000, 340));
    final metric = path.computeMetrics().first;
    final route = metric.extractPath(
      metric.length * _smooth(progress),
      metric.length,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xff01df20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ManeuverGuide oldDelegate) =>
      progress != oldDelegate.progress || approach != oldDelegate.approach;
}

class SurroundParkingView extends StatelessWidget {
  const SurroundParkingView({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '360 서라운드 뷰 · 후진 주차',
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xff92959c))),
          Positioned(
            left: 9,
            top: 0,
            width: 460,
            height: 720,
            child: Image.asset(
              'assets/figma/surround_view.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: 9,
            top: 0,
            width: 460,
            height: 720,
            child: CustomPaint(painter: _SurroundGuide(progress)),
          ),
          Positioned(
            left: 2,
            top: 317,
            width: 7,
            height: 96,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            left: 186,
            top: -1,
            width: 100,
            height: 42,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xff62656c),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  '360\n↔',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    height: .9,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SurroundGuide extends CustomPainter {
  _SurroundGuide(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final steering = math.sin(progress * math.pi) * 55;
    final opacity = progress > .95 ? (1 - progress) / .05 : 1.0;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final side in [-1, 1]) {
      final path = Path()
        ..moveTo(230 + side * 90, 580)
        ..quadraticBezierTo(
          230 + side * 100 + steering,
          630,
          230 + side * 105 + steering * 1.4,
          710,
        );
      canvas.drawPath(
        path,
        p..color = const Color(0xffe3dc9b).withValues(alpha: .8 * opacity),
      );
    }
    final pulse = .35 + .4 * math.pow(math.sin(progress * math.pi * 8), 2);
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: const Offset(230, 518),
          width: 205 + i * 22,
          height: 133 + i * 22,
        ),
        .15 * math.pi,
        .7 * math.pi,
        false,
        p
          ..strokeWidth = 4
          ..color = Color.lerp(
            const Color(0xffe6e0ad),
            const Color(0xffdf7266),
            progress,
          )!.withValues(alpha: pulse * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SurroundGuide oldDelegate) =>
      progress != oldDelegate.progress;
}
