import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_app/core/theme/app_responsive.dart';
import 'package:mantenimiento_app/core/theme/app_theme.dart';
import 'package:mantenimiento_app/core/widgets/state_views.dart';
import 'package:mantenimiento_app/features/mas/mas_menu_screen.dart';
import 'package:mantenimiento_app/features/home/home_screen.dart';
import 'package:mantenimiento_app/features/finanzas/finanzas_hub_screen.dart';
import 'package:mantenimiento_app/core/database/local_storage_service.dart';

void main() {
  group('T-17 Responsive Helper & Breakpoints', () {
    testWidgets('Detects compact breakpoint on narrow screen (< 600px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late ScreenBreakpoint bp;
      late bool isComp;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              bp = AppResponsive.getBreakpoint(context);
              isComp = AppResponsive.isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(bp, ScreenBreakpoint.compact);
      expect(isComp, isTrue);
    });

    testWidgets('Detects medium breakpoint on tablet screen (600px - 1023px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late ScreenBreakpoint bp;
      late bool isMed;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              bp = AppResponsive.getBreakpoint(context);
              isMed = AppResponsive.isMedium(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(bp, ScreenBreakpoint.medium);
      expect(isMed, isTrue);
    });

    testWidgets('Detects expanded breakpoint on desktop screen (>= 1024px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late ScreenBreakpoint bp;
      late bool isExp;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              bp = AppResponsive.getBreakpoint(context);
              isExp = AppResponsive.isExpanded(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(bp, ScreenBreakpoint.expanded);
      expect(isExp, isTrue);
    });

    testWidgets('ConstrainedContent limits max width on 1920px display', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConstrainedContent(
              child: SizedBox(
                key: Key('inner_child'),
                height: 100,
                width: double.infinity,
              ),
            ),
          ),
        ),
      );

      final boxFinder = find.byType(ConstrainedBox);
      expect(boxFinder, findsWidgets);

      final size = tester.getSize(find.byKey(const Key('inner_child')));
      expect(size.width, lessThanOrEqualTo(AppResponsive.maxContentWidth));
    });
  });

  group('T-17 UI States Views', () {
    testWidgets('EmptyStateView renders title, message and action button', (
      tester,
    ) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.inbox,
              title: 'No hay elementos',
              message: 'Cree un nuevo registro para comenzar.',
              actionLabel: 'Crear nuevo',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No hay elementos'), findsOneWidget);
      expect(
        find.text('Cree un nuevo registro para comenzar.'),
        findsOneWidget,
      );
      expect(find.text('Crear nuevo'), findsOneWidget);

      await tester.tap(find.text('Crear nuevo'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('ErrorStateView renders error and retry button', (
      tester,
    ) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ErrorStateView(
              error: 'Error de conexión a la base local',
              onRetry: () => retryTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Ocurrió un inconveniente'), findsOneWidget);
      expect(find.text('Error de conexión a la base local'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(retryTapped, isTrue);
    });

    testWidgets('LoadingStateView renders progress indicator and message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: LoadingStateView(message: 'Cargando datos operacionales...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cargando datos operacionales...'), findsOneWidget);
    });
  });

  group('T-17 MasMenuScreen Organization', () {
    testWidgets('MasMenuScreen renders all secondary modules in categories', (
      tester,
    ) async {
      final storage = LocalStorageService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MasMenuScreen(storage: storage),
        ),
      );

      // Section headers
      expect(find.text('OPERACIONES Y RECURSOS'), findsOneWidget);
      expect(find.text('DIRECTORIO Y CONTACTOS'), findsOneWidget);
      expect(find.text('SISTEMA Y CONFIGURACIÓN'), findsOneWidget);

      // Operational modules
      expect(find.text('Inventario (Kardex)'), findsOneWidget);
      expect(find.text('Herramientas'), findsOneWidget);
      expect(find.text('Trabajadores (Personal)'), findsOneWidget);
      expect(find.text('Calendario Operacional'), findsOneWidget);

      // Directory modules
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Proveedores'), findsOneWidget);
      expect(find.text('Socios'), findsOneWidget);

      // System modules
      expect(find.text('Ajustes del Sistema'), findsOneWidget);
    });

    testWidgets('MasMenuScreen renders without overflow on 320px mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = LocalStorageService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MasMenuScreen(storage: storage),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Inventario (Kardex)'), findsOneWidget);
    });
  });

  group('T-17 HomeScreen Responsive Navigation', () {
    testWidgets(
      'HomeScreen renders NavigationBar with 5 destinations on compact mobile (360px)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final storage = LocalStorageService();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: HomeScreen(storage: storage),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);

        // 5 destinations
        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Obras'), findsOneWidget);
        expect(find.text('Mantto.'), findsOneWidget);
        expect(find.text('Finanzas'), findsOneWidget);
        expect(find.text('Más'), findsOneWidget);
      },
    );

    testWidgets(
      'HomeScreen switches to NavigationRail on tablet/desktop (1024px)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final storage = LocalStorageService();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: HomeScreen(storage: storage),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        // Branding in NavigationRail
        expect(find.text('DECOLUMAX'), findsOneWidget);
      },
    );
  });

  group('T-17 FinanzasHubScreen Hub', () {
    testWidgets('FinanzasHubScreen renders all 5 financial tabs', (
      tester,
    ) async {
      final storage = LocalStorageService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: FinanzasHubScreen(storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rentabilidad'), findsOneWidget);
      expect(find.text('Cobros a Clientes'), findsOneWidget);
      expect(find.text('Pagos Trabajadores'), findsOneWidget);
      expect(find.text('Compras Insumos'), findsOneWidget);
      expect(find.text('Gastos y Socios'), findsOneWidget);
    });
  });
}
