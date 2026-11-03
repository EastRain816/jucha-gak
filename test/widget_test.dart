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
    expect(find.text('후진 주차 중'), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 26));
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

  test('전진에서 후진으로 바뀌어도 차량 위치가 튀지 않는다', () {
    final before = ParkingMotionFrame(parkingReverseStart - .000001)
        .perspectivePose;
    final after = ParkingMotionFrame(parkingReverseStart).perspectivePose;
    expect((before.position - after.position).distance, lessThan(.1));
    final finalPose = ParkingMotionFrame(1).perspectivePose;
    expect(
      (finalPose.position - const Offset(620, 470)).distance,
      lessThan(.01),
    );
    final nearEnd = ParkingMotionFrame(.999).perspectivePose;
    expect((nearEnd.position - finalPose.position).distance, lessThan(1));
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
