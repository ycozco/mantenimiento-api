import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/models/socio.dart';
import 'package:mantenimiento_app/core/models/gasto.dart';
import 'package:mantenimiento_app/core/models/balance_calculator.dart';
import 'package:mantenimiento_app/core/models/mantenimiento.dart';

void main() {
  group('Pruebas de Cálculo de Fechas y Frecuencias de Mantenimiento', () {
    test('Calcula ciclos correctamente para 1m, 1.5m, 2m y custom', () {
      final base = DateTime(2026, 1, 1);

      final m1 = Mantenimiento(
        id: '1',
        clienteId: 'c1',
        clienteNombre: 'Cliente 1',
        titulo: 'Mantenimiento Mensual',
        tipoFrecuencia: TipoFrecuencia.unMes,
        fechaProximo: base,
      );
      expect(m1.diasIntervalo, 30);
      expect(m1.calcularProximoCiclo(base), DateTime(2026, 1, 31));

      final m2 = Mantenimiento(
        id: '2',
        clienteId: 'c1',
        clienteNombre: 'Cliente 1',
        titulo: 'Mantenimiento 1.5 Meses',
        tipoFrecuencia: TipoFrecuencia.unMesYMedio,
        fechaProximo: base,
      );
      expect(m2.diasIntervalo, 45);
      expect(m2.calcularProximoCiclo(base), DateTime(2026, 2, 15));

      final m3 = Mantenimiento(
        id: '3',
        clienteId: 'c1',
        clienteNombre: 'Cliente 1',
        titulo: 'Mantenimiento 2 Meses',
        tipoFrecuencia: TipoFrecuencia.dosMeses,
        fechaProximo: base,
      );
      expect(m3.diasIntervalo, 60);

      final mCustom = Mantenimiento(
        id: '4',
        clienteId: 'c1',
        clienteNombre: 'Cliente 1',
        titulo: 'Mantenimiento Custom',
        tipoFrecuencia: TipoFrecuencia.personalizado,
        diasPersonalizados: 20,
        fechaProximo: base,
      );
      expect(mCustom.diasIntervalo, 20);
      expect(mCustom.calcularProximoCiclo(base), DateTime(2026, 1, 21));
    });
  });

  group('Pruebas de Reparto de Gastos e Inversión y Balance de Socios', () {
    const s1 = Socio(id: 's1', nombre: 'Socio 1');
    const s2 = Socio(id: 's2', nombre: 'Socio 2');

    test('Reparto equitativo 50/50 de gasolina y materiales', () {
      final gastos = [
        Gasto(
          id: 'g1',
          concepto: 'Gasolina',
          categoria: CategoriaGasto.gasolina,
          montoTotal: 1000.0,
          fecha: DateTime.now(),
          pagadoPorSocioId: 's1', // Socio 1 pagó 1000
          tipoReparto: TipoReparto.equitativo,
          participaciones: {'s1': 1.0, 's2': 1.0},
        ),
      ];

      final resumenes = BalanceCalculator.calcularResumenes(
        socios: [s1, s2],
        gastos: gastos,
      );
      final r1 = resumenes.firstWhere((r) => r.socio.id == 's1');
      final r2 = resumenes.firstWhere((r) => r.socio.id == 's2');

      expect(r1.totalPagado, 1000.0);
      expect(r1.totalDeberiaPagar, 500.0);
      expect(r1.saldoNeto, 500.0); // Le deben 500

      expect(r2.totalPagado, 0.0);
      expect(r2.totalDeberiaPagar, 500.0);
      expect(r2.saldoNeto, -500.0); // Debe 500

      final deudas = BalanceCalculator.calcularDeudasSimplificadas(
        socios: [s1, s2],
        gastos: gastos,
      );
      expect(deudas.length, 1);
      expect(deudas.first.deudor.id, 's2');
      expect(deudas.first.acreedor.id, 's1');
      expect(deudas.first.monto, 500.0);
    });

    test('Reparto por porcentaje (70% - 30%) para una obra', () {
      final gastos = [
        Gasto(
          id: 'g2',
          concepto: 'Materiales Obra',
          categoria: CategoriaGasto.materialesObra,
          montoTotal: 1000.0,
          fecha: DateTime.now(),
          pagadoPorSocioId: 's2', // Socio 2 pagó los 1000
          tipoReparto: TipoReparto.porPartes,
          participaciones: {'s1': 70.0, 's2': 30.0},
        ),
      ];

      final resumenes = BalanceCalculator.calcularResumenes(
        socios: [s1, s2],
        gastos: gastos,
      );
      final r1 = resumenes.firstWhere((r) => r.socio.id == 's1');
      final r2 = resumenes.firstWhere((r) => r.socio.id == 's2');

      expect(r1.totalDeberiaPagar, 700.0);
      expect(r2.totalDeberiaPagar, 300.0);

      final deudas = BalanceCalculator.calcularDeudasSimplificadas(
        socios: [s1, s2],
        gastos: gastos,
      );
      expect(deudas.first.deudor.id, 's1');
      expect(deudas.first.acreedor.id, 's2');
      expect(deudas.first.monto, 700.0);
    });
  });
}
