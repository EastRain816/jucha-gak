import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jucha_gak/main.dart';
import 'package:jucha_gak/navigation_motion.dart';

Future<void> ready(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> tap(WidgetTester tester, String label) async {
  final text = find.text(label).first;
  final ink = find.ancestor(of: text, matching: find.byType(InkWell));
  final gesture = find.ancestor(
    of: text,
    matching: find.byType(GestureDetector),
  );
  await tester.tap(ink.evaluate().isNotEmpty ? ink.first : gesture.first);
  await tester.pump();
  await ready(tester);
  expect(tester.takeException(), isNull, reason: label);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final (family, file) in [
      ('NotoSansKR', 'NotoSansKR.ttf'),
      ('Pretendard', 'PretendardVariable.ttf'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file'))).load();
    }
  });

  testWidgets('목적지부터 주차 완료까지 시안의 전체 흐름이 이어진다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1194, 834));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ParkingApp());
    await ready(tester);
    for (final label in ['검색', '포항역 주차장', '거리우선', '안내시작', '예', '가까운 거리']) {
      await tap(tester, label);
    }
    expect(find.text('주차 안내 계속'), findsNothing);
    expect(find.text('성곡교차로 방면'), findsOneWidget);
    expect(find.text('8:40'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('빠른 주차로\n바꾸면 12분 빨라요'), findsOneWidget);
    await tap(tester, '기준 바꾸기');
    expect(find.text('요금(1h)'), findsOneWidget);
    await tap(tester, '선택');
    expect(find.text('층별 빈자리'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    await ready(tester);
    expect(find.text('추천 구역으로 안내'), findsOneWidget);
    await tester.pump(const Duration(seconds: 18));
    await ready(tester);
    expect(find.text('주차각이 나왔어요'), findsOneWidget);
    expect(find.byType(ParkingJourney), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await ready(tester);
    expect(find.byType(ParkingCameraStill), findsOneWidget);
    expect(find.text('후진 주차 중'), findsNothing);
    expect(find.byType(SurroundParkingView), findsOneWidget);
    await tester.pump(const Duration(seconds: 14));
    await ready(tester);
    expect(find.text('주차 완료'), findsOneWidget);
    expect(find.byType(SurroundParkingView), findsNothing);
    await tester.tap(find.bySemanticsLabel('전시 다시 시작'));
    await ready(tester);
    expect(find.text('검색'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('게이지는 왼쪽에서 차오르고 완료 시 터치와 같은 동작을 수행한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ParkingApp(initialStage: ExhibitionStage.changeSuggestion),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox).first,
    );
    expect(fill.widthFactor, closeTo(.5, .01));
    expect(find.text('그대로 가기'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('250m · 3대 가는 중'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const ParkingApp(initialStage: ExhibitionStage.changeSuggestion),
    );
    await tester.pump();
    await tap(tester, '그대로 가기');
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('250m · 3대 가는 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('주차 이동은 구간 경계에서 이어지고 서라운드 뷰는 후진에 나타난다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1194, 834));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ParkingApp(initialStage: ExhibitionStage.entry),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    var frame = ParkingMotionFrame(
      tester.widget<ParkingJourney>(find.byType(ParkingJourney)).progress,
    );
    expect(frame.topPose.position.dx, greaterThan(190));
    expect(frame.viewBlend, 0);
    expect(find.byType(SurroundParkingView), findsNothing);
    await tester.pump(const Duration(seconds: 25));
    frame = ParkingMotionFrame(
      tester.widget<ParkingJourney>(find.byType(ParkingJourney)).progress,
    );
    expect(frame.viewBlend, inExclusiveRange(0, 1));
    await tester.pump(const Duration(seconds: 10));
    frame = ParkingMotionFrame(
      tester.widget<ParkingJourney>(find.byType(ParkingJourney)).progress,
    );
    expect(frame.viewBlend, 1);
    expect(frame.reverseProgress, greaterThan(0));
    expect(find.byType(SurroundParkingView), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('전시 다시 시작'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('검색'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('동선은 통로 중심의 직선 세 구간으로 이동하며 주차면을 가로지르지 않는다', () {
    // Independent geometry from the original parking-map outline and bay rows.
    final boundary = Path()
      ..addPolygon(const [
        Offset(155, 40),
        Offset(1045, 40),
        Offset(1445, 425),
        Offset(1465, 455),
        Offset(1465, 500),
        Offset(1430, 555),
        Offset(615, 555),
        Offset(326, 306),
        Offset(258, 371),
        Offset(200, 311),
        Offset(263, 249),
        Offset(144, 146),
        Offset(125, 110),
        Offset(130, 65),
      ], true);
    const bays = [
      Rect.fromLTWH(220, 50, 665, 35),
      Rect.fromLTWH(314, 136, 350, 75),
      Rect.fromLTWH(689, 136, 190, 75),
      Rect.fromLTWH(470, 258, 190, 75),
      Rect.fromLTWH(689, 258, 190, 75),
      Rect.fromLTWH(897, 258, 150, 75),
      Rect.fromLTWH(610, 377, 55, 75),
      Rect.fromLTWH(690, 377, 190, 75),
      Rect.fromLTWH(903, 377, 344, 75),
      Rect.fromLTWH(620, 505, 660, 40),
    ];
    final metric = parkingAisle.computeMetrics().first;
    final straightLength =
        (const Offset(333, 273) - const Offset(244, 351)).distance +
        (const Offset(580, 480) - const Offset(333, 273)).distance +
        486;
    expect(metric.length, closeTo(straightLength, .001));
    for (double d = metric.length - 486; d <= metric.length; d += 2) {
      expect(metric.getTangentForOffset(d)!.position.dy, closeTo(480, .001));
    }
    final start = sampleDrive(parkingAisle, 0).position;
    expect((start - const Offset(244, 351)).distance, lessThan(.01));
    // The first bend must travel up/right through the entrance, as annotated.
    final turn = sampleDrive(parkingAisle, .12).position;
    expect(turn.dy, lessThan(start.dy));
    for (double d = 0; d <= metric.length; d += 2) {
      final point = metric.getTangentForOffset(d)!.position;
      expect(boundary.contains(point), isTrue, reason: 'outside lot at $point');
      expect(
        bays.any((bay) => bay.contains(point)),
        isFalse,
        reason: 'crosses a parking bay at $point',
      );
    }
    final end = sampleDrive(parkingAisle, 1).position;
    expect(end.dx, inInclusiveRange(1000, 1100));
    expect(end.dy, inInclusiveRange(470, 495));
  });

  testWidgets('후진 화면은 피그마 원본 사진 두 장이며 시간에 따라 변하지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1194, 834));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ParkingApp(initialStage: ExhibitionStage.reversing),
    );
    await ready(tester);
    expect(find.byType(ParkingCameraStill), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image == const AssetImage('assets/figma/rear_camera.png'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image == const AssetImage('assets/figma/surround_view.png'),
      ),
      findsOneWidget,
    );
    Future<List<int>> pixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('exhibition-canvas')),
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: .5);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }))!;
    }

    final before = await pixels();
    await tester.pump(const Duration(seconds: 5));
    expect(await pixels(), orderedEquals(before));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('전 화면을 iPad 비율과 큰 시스템 글자에서 넘침 없이 그린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final stage in ExhibitionStage.values) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(ParkingApp(initialStage: stage));
      await ready(tester);
      if (stage == ExhibitionStage.approach) {
        await tester.pump(const Duration(seconds: 3));
      }
      expect(tester.takeException(), isNull, reason: stage.name);
      if (const bool.fromEnvironment('CAPTURE_EXHIBITION')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('exhibition-canvas')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/visual_qa/${stage.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
