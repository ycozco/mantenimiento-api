// Manual visual review of the real menu and navigation, without business data.
// flutter test tool/render_ui_preview.dart --update-goldens
// Set FLUTTER_ROOT to the SDK path so typography matches the application.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/local_storage_service.dart';
import 'package:mantenimiento_app/core/navigation/app_destination.dart';
import 'package:mantenimiento_app/core/navigation/app_navigation_shell.dart';
import 'package:mantenimiento_app/core/theme/app_theme.dart';
import 'package:mantenimiento_app/features/mas/mas_menu_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) throw StateError('Set FLUTTER_ROOT to your Flutter SDK.');
    final fonts = '$sdk/bin/cache/artifacts/material_fonts';
    for (final family in ['Roboto']) {
      final loader = FontLoader(family);
      for (final weight in ['regular', 'medium', 'bold']) {
        loader.addFont(
          File(
            '$fonts/roboto-$weight.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List<dynamic>) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  final cases = [
    ('mobile', const Size(390, 844), 1.0),
    ('small-large-text', const Size(320, 740), 1.6),
    ('tablet', const Size(1024, 800), 1.0),
    ('landscape', const Size(844, 390), 1.0),
  ];
  final theme = AppTheme.darkTheme;
  // Explicitly model Android's font fallback for styles without a fontFamily;
  // the test engine otherwise renders those styles with the square Ahem font.
  final previewTheme = theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle!.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
    navigationRailTheme: theme.navigationRailTheme.copyWith(
      selectedLabelTextStyle: theme.navigationRailTheme.selectedLabelTextStyle!
          .copyWith(fontFamily: 'Roboto'),
      unselectedLabelTextStyle: theme
          .navigationRailTheme
          .unselectedLabelTextStyle!
          .copyWith(fontFamily: 'Roboto'),
    ),
  );
  for (final (name, size, scale) in cases) {
    testWidgets('menu $name', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp(
            theme: previewTheme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AppNavigationShell(
              selected: AppDestination.more,
              onSelected: (_) {},
              child: MasMenuScreen(storage: LocalStorageService()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile('../build/ui-review/$name.png'),
      );
    });
  }
}
