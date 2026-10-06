import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/local_storage_service.dart';
import 'package:mantenimiento_app/core/navigation/app_destination.dart';
import 'package:mantenimiento_app/core/navigation/app_navigation_shell.dart';
import 'package:mantenimiento_app/core/theme/app_theme.dart';
import 'package:mantenimiento_app/features/home/home_screen.dart';

void main() {
  testWidgets(
    'dashboard actions select a destination through the home intent',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: HomeScreen(storage: LocalStorageService()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver Obras'));
      await tester.pumpAndSettle();
      expect(find.text('Obras y Proyectos'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AppDestination.projects.index,
      );
    },
  );

  testWidgets('tab and breakpoint changes preserve an unfinished form', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const _Harness());
    await tester.enterText(find.byType(TextField), 'Obra sin guardar');
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    expect(find.text('Otra pantalla'), findsOneWidget);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Obra sin guardar'), findsOneWidget);

    tester.view.physicalSize = const Size(1024, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Obra sin guardar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short landscape and large text use an accessible bottom bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 640), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const _Harness(textScale: 2));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final destination in AppDestination.values) {
        final target = find.widgetWithText(
          NavigationDestination,
          destination.compactLabel,
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'reduced motion keeps the navigation usable without transitions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const _Harness(reduceMotion: true));
      await tester.tap(find.text('Más'));
      await tester.pump();
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero,
      );
      for (final scale in tester.widgetList<AnimatedScale>(
        find.byType(AnimatedScale),
      )) {
        expect(scale.duration, Duration.zero);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness extends StatefulWidget {
  const _Harness({this.textScale = 1, this.reduceMotion = false});
  final double textScale;
  final bool reduceMotion;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  AppDestination selected = AppDestination.home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(widget.textScale),
        disableAnimations: widget.reduceMotion,
      ),
      child: child!,
    ),
    home: AppNavigationShell(
      selected: selected,
      onSelected: (destination) => setState(() => selected = destination),
      child: IndexedStack(
        index: selected == AppDestination.home ? 0 : 1,
        children: const [
          Scaffold(body: TextField()),
          Scaffold(body: Center(child: Text('Otra pantalla'))),
        ],
      ),
    ),
  );
}
