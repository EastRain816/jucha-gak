import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'exhibition.dart';
export 'exhibition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key, this.initialStage = ExhibitionStage.home});
  final ExhibitionStage initialStage;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'NotoSansKR',
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
    ),
    home: Exhibition(initialStage: initialStage),
  );
}
