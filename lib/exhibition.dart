import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'figma_graphics.dart';
import 'navigation_motion.dart';

const _white = Color(0xfff6f7fc);
const _secondary = Color(0xb3ececec);
const _lime = Color(0xff01df20);
const _canvas = Size(1920, 720);

/// Stages correspond to the original 1920 × 720 Figma frames.
enum ExhibitionStage {
  home,
  destinations,
  routes,
  routeSummary,
  parkingChoice,
  criterion,
  driving,
  changeSuggestion,
  nearParking,
  entry,
  zoneGuidance,
  approach,
  reversing,
  parked,
}

class Exhibition extends StatefulWidget {
  const Exhibition({super.key, this.initialStage = ExhibitionStage.home});
  final ExhibitionStage initialStage;
  @override
  State<Exhibition> createState() => _ExhibitionState();
}

class _ExhibitionState extends State<Exhibition> with TickerProviderStateMixin {
  late ExhibitionStage _stage;
  late final AnimationController _countdown;
  late final AnimationController _roadMotion;
  late final AnimationController _parkingMotion;
  late final AnimationController _parkingOutro;
  String _criterion = '가까운 거리';
  int _route = 0;
  int _floor = 1;
  bool _floorsExpanded = true;
  bool _parkingArtworkCached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_parkingArtworkCached) return;
    _parkingArtworkCached = true;
    // Decode before reaching J, so the first 3D frame has its full artwork.
    precacheImage(const AssetImage('assets/figma/approach_scene.png'), context);
  }

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage;
    _countdown =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed &&
                _stage == ExhibitionStage.changeSuggestion) {
              _continueSuggestion();
            }
          });
    _roadMotion =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed &&
                _stage == ExhibitionStage.driving) {
              _go(ExhibitionStage.changeSuggestion);
            }
          });
    _parkingOutro =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..addStatusListener((status) {
          if (mounted && status == AnimationStatus.completed) setState(() {});
        });
    _parkingMotion = AnimationController(
      vsync: this,
      duration: parkingDriveDuration,
    )..addListener(_syncParkingStage);
    _scheduleStage();
  }

  @override
  void dispose() {
    _roadMotion.stop();
    _parkingMotion.stop();
    _parkingOutro.stop();
    _countdown.dispose();
    _roadMotion.dispose();
    _parkingMotion.dispose();
    _parkingOutro.dispose();
    super.dispose();
  }

  void _go(ExhibitionStage stage) {
    _roadMotion.stop();
    _parkingMotion.stop();
    _parkingOutro.stop();
    _countdown.stop();
    if (!mounted) return;
    setState(() {
      _stage = stage;
      if (stage == ExhibitionStage.home) {
        _criterion = '가까운 거리';
        _route = 0;
        _floor = 1;
        _floorsExpanded = true;
      }
    });
    _parkingOutro.value = 0;
    _scheduleStage();
  }

  void _scheduleStage() {
    if (_stage == ExhibitionStage.changeSuggestion) {
      _countdown.forward(from: 0);
      return;
    }
    if (_stage == ExhibitionStage.driving) {
      _roadMotion.forward(from: 0);
    } else if (_stage.index >= ExhibitionStage.entry.index) {
      final start = switch (_stage) {
        ExhibitionStage.entry => 0.0,
        ExhibitionStage.zoneGuidance => parkingEntryEnd,
        ExhibitionStage.approach => parkingTopViewEnd,
        ExhibitionStage.reversing => parkingReverseStart,
        _ => 1.0,
      };
      _parkingMotion.value = start;
      if (start < 1) {
        _parkingMotion.forward();
      } else if (widget.initialStage == ExhibitionStage.parked) {
        _parkingOutro.value = 1;
      } else {
        _parkingOutro.forward(from: 0);
      }
    }
  }

  void _syncParkingStage() {
    if (!mounted || _stage.index < ExhibitionStage.entry.index) return;
    final p = _parkingMotion.value;
    final enteredJ = ParkingMotionFrame(p).hasEnteredJ;
    final next = p < parkingEntryEnd
        ? ExhibitionStage.entry
        : !enteredJ
        ? ExhibitionStage.zoneGuidance
        : p < parkingReverseStart
        ? ExhibitionStage.approach
        : p < 1
        ? ExhibitionStage.reversing
        : ExhibitionStage.parked;
    if (next != _stage) {
      setState(() => _stage = next);
      if (next == ExhibitionStage.parked) _parkingOutro.forward(from: 0);
    }
  }

  void _continueSuggestion() => _go(ExhibitionStage.nearParking);

  void _advanceMap() {
    switch (_stage) {
      case ExhibitionStage.driving:
        _go(ExhibitionStage.changeSuggestion);
      case ExhibitionStage.entry:
        _go(ExhibitionStage.zoneGuidance);
      case ExhibitionStage.zoneGuidance:
        _go(ExhibitionStage.approach);
      case ExhibitionStage.approach:
        _go(ExhibitionStage.reversing);
      case ExhibitionStage.reversing:
        _go(ExhibitionStage.parked);
      case ExhibitionStage.parked:
        _go(ExhibitionStage.home);
      default:
        break;
    }
  }

  String get _clock => switch (_stage) {
    ExhibitionStage.driving => '8:18',
    ExhibitionStage.changeSuggestion => '8:30',
    ExhibitionStage.nearParking => '8:37',
    ExhibitionStage.entry => '8:42',
    ExhibitionStage.zoneGuidance || ExhibitionStage.approach => '8:45',
    ExhibitionStage.reversing => '8:46',
    ExhibitionStage.parked => '8:47',
    _ => '8:10',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: AspectRatio(
        aspectRatio: _canvas.aspectRatio,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.fromSize(
            size: _canvas,
            child: MediaQuery.withNoTextScaling(
              child: RepaintBoundary(
                key: const ValueKey('exhibition-canvas'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Semantics(
                          label: '지도에서 다음 장면으로',
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _advanceMap,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 800),
                              child: SizedBox.fromSize(
                                key: ValueKey(
                                  _stage.index >= ExhibitionStage.entry.index
                                      ? 'parking-journey'
                                      : _stage.name,
                                ),
                                size: _canvas,
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _roadMotion,
                                    _parkingMotion,
                                    _parkingOutro,
                                  ]),
                                  builder: (context, _) =>
                                      Stack(children: _mapLayers()),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position:
                                Tween(
                                  begin: const Offset(-.012, 0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                            child: child,
                          ),
                        ),
                        child: SizedBox.fromSize(
                          key: ValueKey(_stage),
                          size: _canvas,
                          child: Stack(children: _overlays()),
                        ),
                      ),
                      // Outside the screen transition: the CarPlay tray never moves.
                      _sidebar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _mapLayers() {
    final background = Positioned.fill(
      child: ColoredBox(
        color: _stage.index >= ExhibitionStage.entry.index
            ? const Color(0xffe4e2dc)
            : Colors.white,
      ),
    );
    return [
      background,
      ...switch (_stage) {
        ExhibitionStage.home => [
          _image(
            'assets/map.png',
            const Rect.fromLTWH(102.97, -237.72, 2018.869, 1078.402),
          ),
        ],
        ExhibitionStage.destinations => [
          _image(
            'assets/map.png',
            const Rect.fromLTWH(118.4, -151.352, 2018.869, 1078.402),
          ),
        ],
        ExhibitionStage.routes => [
          // This export is already clipped to the Figma viewport. Do not reapply
          // the source rectangle's off-screen scale or stretch the 1807 × 720 PNG.
          _image(
            'assets/route_list.png',
            const Rect.fromLTWH(113.1, 0, 1806.9, 720),
          ),
        ],
        ExhibitionStage.routeSummary ||
        ExhibitionStage.parkingChoice ||
        ExhibitionStage.criterion => [
          _image(
            'assets/route.png',
            const Rect.fromLTWH(129.742, -305.302, 2241.249, 1197.189),
          ),
        ],
        ExhibitionStage.driving => [
          Positioned.fill(
            child: RoadNavigationMotion(progress: _roadMotion.value),
          ),
        ],
        ExhibitionStage.changeSuggestion => [
          const FigmaGraphic('change_map'),
          _image(
            'assets/figma/blue_position.svg',
            const Rect.fromLTWH(1101.2, 544.05, 84.814, 77.67),
          ),
        ],
        ExhibitionStage.nearParking => [
          const FigmaGraphic('near_map'),
          const FigmaGraphic('green_position'),
        ],
        ExhibitionStage.entry ||
        ExhibitionStage.zoneGuidance ||
        ExhibitionStage.approach ||
        ExhibitionStage.reversing ||
        ExhibitionStage.parked => [
          Positioned.fill(
            child: ParkingJourney(
              progress: _parkingMotion.value,
              completionProgress: _parkingOutro.value,
            ),
          ),
        ],
      },
    ];
  }

  Widget _sidebar() => Positioned(
    left: 0,
    top: 0,
    width: 133.841,
    height: 720,
    child: ColoredBox(
      color: const Color(0xff636262),
      child: Stack(
        children: [
          Positioned(
            left: 15,
            top: 18.767,
            width: 103.4,
            height: 93.8,
            child: Semantics(
              label: '$_clock LTE',
              child: SvgPicture.asset(
                'assets/figma/status_${_clock.replaceAll(':', '').padLeft(4, '0')}.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          for (final (file, y) in [
            ('nav_icon.png', 191.614),
            ('map_icon.png', 301.48),
            ('phone_icon.png', 411.347),
          ])
            Positioned(
              left: 20.3,
              top: y,
              width: 92.8,
              height: 92.8,
              child: Semantics(
                label: '처음 화면으로',
                button: true,
                child: GestureDetector(
                  onTap: () => _go(ExhibitionStage.home),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/$file'),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 18.7,
            top: 635.414,
            width: 96,
            height: 46.934,
            child: Semantics(
              label: '전시 다시 시작',
              button: true,
              child: GestureDetector(
                onTap: () => _go(ExhibitionStage.home),
                child: SvgPicture.asset('assets/figma/grid.svg'),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _overlays() => switch (_stage) {
    ExhibitionStage.home => [
      Positioned(
        left: 162.27,
        top: 592.42,
        width: 520,
        height: 100,
        child: _button(
          '검색',
          () => _go(ExhibitionStage.destinations),
          dark: true,
          size: 50,
          icon: Icons.search,
          alignment: Alignment.centerLeft,
        ),
      ),
    ],
    ExhibitionStage.destinations => [_destinationList()],
    ExhibitionStage.routes => [_routeList()],
    ExhibitionStage.routeSummary => [_summary()],
    ExhibitionStage.parkingChoice => [_parkingChoice()],
    ExhibitionStage.criterion => [_criterionChoice()],
    ExhibitionStage.driving => [_navigation(), _arrival()],
    ExhibitionStage.changeSuggestion => [_changeCard()],
    ExhibitionStage.nearParking => [_nearCard()],
    ExhibitionStage.entry => [
      _floorPanel(),
      ..._parkingControls(),
      const FigmaGraphic('legend'),
    ],
    ExhibitionStage.zoneGuidance => [
      _banner('추천 구역으로 안내', 'J구역까지 150m'),
      ..._parkingControls(),
      const FigmaGraphic('legend'),
    ],
    ExhibitionStage.approach => [
      _banner('주차각이 나왔어요', 'J구역까지 100m'),
      ..._parkingControls(),
    ],
    ExhibitionStage.reversing => [],
    ExhibitionStage.parked => [
      _banner('J-05', '주차 완료'),
      ..._parkingControls(),
      if (_parkingOutro.isCompleted) const FigmaGraphic('legend'),
    ],
  };

  Widget _destinationList() => _list(
    '포항역',
    const [
      ('포항역 주차장', '8.3km | 포항역 KTX', '포항시 북구 흥해읍 포항역로 1'),
      ('영일대 해수욕장', '11.5km | 해변 산책로', '포항시 북구 영일대해변길 200'),
      ('죽도시장', '7.7km | 신선한 해산물', '포항시 북구 중앙로 147'),
    ],
    onBack: () => _go(ExhibitionStage.home),
    onSelect: (_) => _go(ExhibitionStage.routes),
  );

  Widget _routeList() => _list(
    '포항역 주차장',
    const [
      ('실시간 추천', '8.3km | 14분', '통행료 무료'),
      ('큰길우선', '11km | 14분', '통행료 무료'),
      ('거리우선', '8.2km | 14분', '통행료 무료'),
    ],
    selected: _route,
    onBack: () => _go(ExhibitionStage.destinations),
    onSelect: (i) {
      _route = i;
      _go(ExhibitionStage.routeSummary);
    },
  );

  Widget _list(
    String heading,
    List<(String, String, String)> rows, {
    required VoidCallback onBack,
    required ValueChanged<int> onSelect,
    int? selected,
  }) => Positioned(
    left: 162.32,
    top: 30.423,
    width: 520,
    height: 668.333,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xbf252626),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 26,
            top: 24,
            width: 468,
            height: 95,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back,
                    size: 48,
                    color: Color(0xffededed),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        heading,
                        style: _style(48, color: const Color(0xffededed)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (int i = 0; i < rows.length; i++)
            Positioned(
              left: 50,
              top: 139 + i * 176,
              width: 418,
              height: 167,
              child: Semantics(
                button: true,
                selected: selected == i,
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: selected == null || selected == i ? 1 : .42,
                    child: Stack(
                      children: [
                        _text(
                          rows[i].$1,
                          const Rect.fromLTWH(0, 0, 418, 60),
                          size: 38,
                        ),
                        _text(
                          rows[i].$2,
                          const Rect.fromLTWH(0, 58, 418, 48),
                          size: 29,
                          color: Colors.white54,
                        ),
                        _text(
                          rows[i].$3,
                          const Rect.fromLTWH(0, 106, 418, 48),
                          size: 29,
                          color: Colors.white54,
                        ),
                        if (i < 2)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Divider(color: Colors.white12, height: 1),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _summary() => _grayPanel([
    _text(
      '포항역(고속철도)',
      const Rect.fromLTWH(40, 40, 715, 90),
      size: 60,
      weight: 500,
    ),
    _text('통행료 0원', const Rect.fromLTWH(40, 131, 715, 64), size: 40),
    for (final (i, value, unit) in [
      (0, '8:40', '도착'),
      (1, '30', '분'),
      (2, '8.3', 'km'),
    ])
      _metric(value, unit, Rect.fromLTWH(40 + i * 238, 274.58, 238, 118), 50),
    Positioned(
      left: 40,
      top: 434,
      width: 714,
      height: 86,
      child: _button('다른 경로', () => _go(ExhibitionStage.routes), size: 50),
    ),
    Positioned(
      left: 40,
      top: 535,
      width: 714,
      height: 86,
      child: _button(
        '안내시작',
        () => _go(ExhibitionStage.parkingChoice),
        size: 50,
      ),
    ),
  ]);

  Widget _parkingChoice() => _greenCard([
    ..._cardHeader('주차장도\n잡아드릴까요?'),
    _text(
      '목적지 근처 주차를 하실\n예정인가요?',
      const Rect.fromLTWH(205.46, 221, 550, 116),
      size: 40,
      color: _secondary,
    ),
    ..._twoButtons(
      '예',
      () => _go(ExhibitionStage.criterion),
      '아니오',
      () => _go(ExhibitionStage.driving),
    ),
  ]);

  Widget _criterionChoice() => _greenCard([
    ..._cardHeader('어떤 기준으로\n설정해드릴까요?'),
    for (final (i, label) in [(0, '빠른 주차'), (1, '가까운 거리'), (2, '저렴한 요금')])
      Positioned(
        left: 40,
        top: 330 + i * 100.6,
        width: 714,
        height: 85.86,
        child: _button(label, () {
          _criterion = label;
          _go(ExhibitionStage.driving);
        }),
      ),
  ]);

  Widget _changeCard() => _greenCard([
    ..._cardHeader('빠른 주차로\n바꾸면 12분 빨라요'),
    _text(
      '가까운 주차장이 지금 만차예요',
      const Rect.fromLTWH(205.46, 236.91, 550, 58),
      size: 40,
      color: _secondary,
    ),
    _metric(
      _criterion,
      '지금·대기 15분',
      const Rect.fromLTWH(65, 335.62, 270, 129),
      50,
      unitSize: 36,
    ),
    _text(
      '→',
      const Rect.fromLTWH(367, 354, 61, 90),
      size: 60,
      align: Alignment.center,
    ),
    _metric(
      '빠른 주차',
      '추천·대기 3분',
      const Rect.fromLTWH(480, 335.62, 240, 129),
      50,
      unitSize: 36,
      valueColor: _lime,
    ),
    Positioned(
      left: 39.9,
      top: 530.32,
      width: 260,
      height: 85.86,
      child: _button('기준 바꾸기', () {
        _criterion = '빠른 주차';
        _go(ExhibitionStage.nearParking);
      }),
    ),
    Positioned(
      left: 314.62,
      top: 530.32,
      width: 439.14,
      height: 85.86,
      child: AnimatedBuilder(
        animation: _countdown,
        builder: (context, _) => _button(
          '그대로 가기',
          _continueSuggestion,
          progress: _countdown.value,
          key: const ValueKey('continue-gauge'),
        ),
      ),
    ),
  ]);

  Widget _nearCard() => _greenCard([
    ..._cardHeader('포항역\n부설 주차장'),
    _text(
      '250m · 3대 가는 중',
      const Rect.fromLTWH(205.46, 221.14, 550, 58),
      size: 40,
      color: _secondary,
    ),
    // Fixed, independent columns preserve the gaps in the source design.
    _metric('3면', '빈자리', const Rect.fromLTWH(40, 324.15, 178, 129), 50),
    _metric('1,500', '요금(1h)', const Rect.fromLTWH(281, 324.15, 200, 129), 50),
    _metric('3분마다', '출차간격', const Rect.fromLTWH(552, 324.15, 200, 129), 50),
    ..._twoButtons(
      '다른 곳',
      () => _go(ExhibitionStage.changeSuggestion),
      '선택',
      () => _go(ExhibitionStage.entry),
    ),
  ]);

  Widget _greenCard(List<Widget> children) => Positioned(
    left: 162.32,
    top: 31.03,
    width: 795,
    height: 661,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -1.76,
          top: -.588,
          width: 798.523,
          height: 662.176,
          child: IgnorePointer(child: _cardGraphic('card_background')),
        ),
        ...children,
      ],
    ),
  );

  List<Widget> _cardHeader(String title) => [
    _logo(40.26, 68.61),
    _text(
      title,
      const Rect.fromLTWH(205.46, 56.205, 550, 140),
      size: 60,
      weight: 500,
      lineHeight: 70,
      spacing: -1.2,
    ),
  ];

  Widget _logo(double x, double y) => Positioned(
    left: x,
    top: y,
    width: 115.194,
    height: 115.194,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xff1b1b1b),
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 23.34,
            top: 36.58,
            width: 69.102,
            height: 43.588,
            child: SvgPicture.asset(
              'assets/figma/logo.svg',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _twoButtons(
    String a,
    VoidCallback onA,
    String b,
    VoidCallback onB,
  ) => [
    Positioned(
      left: 39.9,
      top: 530.32,
      width: 349.57,
      height: 85.86,
      child: _button(a, onA),
    ),
    Positioned(
      left: 404.19,
      top: 530.32,
      width: 349.57,
      height: 85.86,
      child: _button(b, onB),
    ),
  ];

  Widget _grayPanel(List<Widget> children) => Positioned(
    left: 162,
    top: 31,
    width: 795,
    height: 661,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xbf252626),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xffd0d0d0), width: 1),
      ),
      child: Stack(children: children),
    ),
  );

  Widget _navigation() => Positioned(
    left: 161.93,
    top: 28.978,
    width: 430.375,
    height: 313.022,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            width: 430.375,
            height: 227.9,
            child: ColoredBox(color: Color(0xff0157f3)),
          ),
          const Positioned(
            left: 0,
            top: 227.9,
            width: 430.375,
            height: 85.122,
            child: ColoredBox(color: Color(0xff003abf)),
          ),
          _image(
            'assets/figma/turn_right.svg',
            const Rect.fromLTWH(62.6, 32.822, 99.223, 93.694),
          ),
          _text(
            '3.2km',
            const Rect.fromLTWH(205.15, 46.732, 208, 81),
            size: 56,
            weight: 700,
            family: 'Pretendard',
          ),
          _text(
            '성곡교차로 방면',
            const Rect.fromLTWH(43.21, 159.16, 362, 64),
            size: 44,
            weight: 700,
            family: 'Pretendard',
          ),
          _image(
            'assets/figma/turn_left.svg',
            const Rect.fromLTWH(45.39, 252.291, 22, 27.866),
          ),
          _text(
            '308m',
            const Rect.fromLTWH(113.57, 248.532, 260, 53),
            size: 36,
            family: 'Pretendard',
            spacing: .72,
          ),
        ],
      ),
    ),
  );

  Widget _arrival() => Positioned(
    left: 162,
    top: 587.359,
    width: 431,
    height: 136,
    child: GestureDetector(
      onTap: _advanceMap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xd91b1b1b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Stack(
          children: [
            _metric(
              '8:40',
              '도착',
              const Rect.fromLTWH(26, 20, 90, 96),
              36,
              unitSize: 30,
            ),
            _metric(
              '30',
              '분',
              const Rect.fromLTWH(187, 20, 60, 96),
              36,
              unitSize: 30,
            ),
            _metric(
              '9.1',
              'km',
              const Rect.fromLTWH(335, 20, 70, 96),
              36,
              unitSize: 30,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _banner(String title, String subtitle) => Positioned(
    left: 162,
    top: 31,
    width: 795,
    height: 201,
    child: GestureDetector(
      onTap: _advanceMap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -1.762,
            top: -.588,
            width: 798.523,
            height: 202.176,
            child: IgnorePointer(child: _cardGraphic('arrival_banner')),
          ),
          _logo(39.9, 42.9),
          _text(
            title,
            const Rect.fromLTWH(205.1, 30.5, 550, 70),
            size: 60,
            weight: 500,
            spacing: -1.2,
            lineHeight: 70,
          ),
          _text(
            subtitle,
            const Rect.fromLTWH(205.1, 105.5, 550, 65),
            size: 40,
            color: _secondary,
          ),
        ],
      ),
    ),
  );

  Widget _floorPanel() => Positioned(
    left: 162.22,
    top: 30.609,
    width: 400,
    height: _floorsExpanded ? 481 : 84,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xbf252626),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 19.1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 16,
            width: 368,
            height: 52,
            child: GestureDetector(
              onTap: () => setState(() => _floorsExpanded = !_floorsExpanded),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  _text(
                    '층별 빈자리',
                    const Rect.fromLTWH(12, 8, 260, 38),
                    size: 24,
                    color: const Color(0xffbec0c8),
                  ),
                  Positioned(
                    right: 12,
                    top: 8,
                    width: 36,
                    height: 36,
                    child: Icon(
                      _floorsExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: _secondary,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_floorsExpanded) ...[
            for (int i = 0; i < 3; i++)
              Positioned(
                left: 16,
                top: [80.0, 157.0, 400.0][i],
                width: 368,
                height: i == 1 ? 74 : 65,
                child: GestureDetector(
                  onTap: () => setState(() => _floor = i),
                  behavior: HitTestBehavior.opaque,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _floor == i
                          ? const Color(0x8c67df43)
                          : Colors.transparent,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(_floor == i ? 20 : 0),
                      ),
                    ),
                    child: Stack(
                      children: [
                        _text(
                          ['2F', '1F', 'BF1'][i],
                          const Rect.fromLTWH(16, 10, 90, 49),
                          size: _floor == i ? 36 : 28,
                          weight: _floor == i ? 700 : 500,
                        ),
                        _text(
                          ['0/253', '0/271', '0/180'][i],
                          const Rect.fromLTWH(230, 10, 122, 49),
                          size: _floor == i ? 36 : 28,
                          weight: _floor == i ? 700 : 400,
                          align: Alignment.centerRight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _text(
              '빈자리 0',
              const Rect.fromLTWH(48, 249, 320, 38),
              size: 28,
              weight: 700,
            ),
            const Positioned(
              left: 48,
              top: 298,
              width: 2,
              height: 74,
              child: ColoredBox(color: Color(0xff62a64d)),
            ),
            _text(
              '대기 추천',
              const Rect.fromLTWH(64, 292, 304, 35),
              size: 24,
              color: _secondary,
            ),
            _text(
              'J구역에서 대기하세요',
              const Rect.fromLTWH(64, 327, 304, 46),
              size: 30,
              weight: 700,
            ),
          ],
        ],
      ),
    ),
  );

  List<Widget> _parkingControls() => [
    FigmaGraphic('microphone', onTap: _advanceMap, semanticLabel: '안내 계속'),
    FigmaGraphic('recenter', onTap: _advanceMap, semanticLabel: '현재 위치로'),
  ];

  Widget _button(
    String label,
    VoidCallback onTap, {
    Key? key,
    bool dark = false,
    double size = 40,
    IconData? icon,
    Alignment alignment = Alignment.center,
    double? progress,
  }) => Semantics(
    button: true,
    label: label,
    child: Material(
      key: key,
      color: dark ? const Color(0xbf252626) : const Color(0x809c9c9e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.53),
        side: BorderSide(
          color: dark ? const Color(0xff666666) : const Color(0x400042ff),
          width: dark ? 2 : 2.453,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (progress != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0, 1),
                  heightFactor: 1,
                  child: const ColoredBox(color: _lime),
                ),
              ),
            ),
          Positioned.fill(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: dark ? 40 : 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: alignment,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: alignment,
                          child: Text(
                            label,
                            style: _style(size, weight: dark ? 400 : 500),
                          ),
                        ),
                      ),
                    ),
                    if (icon != null)
                      Icon(icon, size: 57.088, color: const Color(0xffdee3eb)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Each text slot has the dimensions of the original Figma layer. Only an
/// oversized label scales down; no text can overflow the design canvas.
Widget _text(
  String text,
  Rect rect, {
  double size = 40,
  int weight = 400,
  Color color = _white,
  Alignment align = Alignment.centerLeft,
  String family = 'NotoSansKR',
  double? lineHeight,
  double spacing = 0,
}) => Positioned.fromRect(
  rect: rect,
  child: IgnorePointer(
    child: Align(
      alignment: align,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: align,
        child: Text(
          text,
          softWrap: false,
          style: _style(
            size,
            weight: weight,
            color: color,
            family: family,
            spacing: spacing,
            lineHeight: lineHeight,
          ),
        ),
      ),
    ),
  ),
);

TextStyle _style(
  double size, {
  int weight = 400,
  Color color = _white,
  String family = 'NotoSansKR',
  double spacing = 0,
  double? lineHeight,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  color: color,
  fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  height: (lineHeight ?? size * 1.45) / size,
  letterSpacing: spacing,
  decoration: TextDecoration.none,
);

Widget _metric(
  String value,
  String unit,
  Rect rect,
  double size, {
  double? unitSize,
  Color valueColor = _white,
}) => Positioned.fromRect(
  rect: rect,
  child: Stack(
    children: [
      _text(
        value,
        Rect.fromLTWH(0, 0, rect.width, rect.height * .52),
        size: size,
        weight: 500,
        color: valueColor,
        align: Alignment.center,
      ),
      _text(
        unit,
        Rect.fromLTWH(0, rect.height * .54, rect.width, rect.height * .46),
        size: unitSize ?? size,
        weight: 300,
        align: Alignment.center,
      ),
    ],
  ),
);

Widget _image(String path, Rect rect) => Positioned.fromRect(
  rect: rect,
  child: IgnorePointer(
    child: path.endsWith('.svg')
        ? SvgPicture.asset(path, fit: BoxFit.contain)
        : Image.asset(
            path,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
  ),
);

// Figma exports this artwork with mix-blend-mode:luminosity. Flutter's SVG
// renderer applies that blend against the map differently from Figma. Preserve
// the original silhouette and alpha, and apply its original gradient in Flutter.
Widget _cardGraphic(String name) => ShaderMask(
  shaderCallback: (bounds) => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xff001f02), Color(0xff007311)],
  ).createShader(bounds),
  blendMode: BlendMode.srcIn,
  child: SvgPicture.asset(
    'assets/figma/$name.svg',
    fit: BoxFit.contain,
    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  ),
);
