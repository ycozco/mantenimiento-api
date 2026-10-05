import 'socio.dart';
import 'gasto.dart';

class ResumenSocio {
  final Socio socio;
  final double totalPagado;
  final double totalDeberiaPagar;

  double get saldoNeto => totalPagado - totalDeberiaPagar;
  bool get tieneSaldoAFavor => saldoNeto > 0.01;
  bool get tieneDeuda => saldoNeto < -0.01;
  bool get estaAlDia => saldoNeto.abs() <= 0.01;

  const ResumenSocio({
    required this.socio,
    required this.totalPagado,
    required this.totalDeberiaPagar,
  });
}

class DeudaPendiente {
  final Socio deudor;
  final Socio acreedor;
  final double monto;

  const DeudaPendiente({
    required this.deudor,
    required this.acreedor,
    required this.monto,
  });
}

class BalanceCalculator {
  static List<ResumenSocio> calcularResumenes({
    required List<Socio> socios,
    required List<Gasto> gastos,
  }) {
    final Map<String, double> pagadoPor = {for (var s in socios) s.id: 0.0};
    final Map<String, double> cuotaPor = {for (var s in socios) s.id: 0.0};

    for (final gasto in gastos) {
      if (pagadoPor.containsKey(gasto.pagadoPorSocioId)) {
        pagadoPor[gasto.pagadoPorSocioId] =
            (pagadoPor[gasto.pagadoPorSocioId] ?? 0.0) + gasto.montoTotal;
      }

      for (final socio in socios) {
        final cuota = gasto.cuotaDe(socio.id);
        cuotaPor[socio.id] = (cuotaPor[socio.id] ?? 0.0) + cuota;
      }
    }

    return socios.map((socio) {
      return ResumenSocio(
        socio: socio,
        totalPagado: pagadoPor[socio.id] ?? 0.0,
        totalDeberiaPagar: cuotaPor[socio.id] ?? 0.0,
      );
    }).toList();
  }

  /// Algoritmo de liquidación simplificada de deudas ("Quién debe a quién y cuánto")
  static List<DeudaPendiente> calcularDeudasSimplificadas({
    required List<Socio> socios,
    required List<Gasto> gastos,
  }) {
    final resumenes = calcularResumenes(socios: socios, gastos: gastos);
    final sociosMap = {for (var s in socios) s.id: s};

    // Separar en deudores (saldo < 0) y acreedores (saldo > 0)
    final List<MapEntry<String, double>> deudores = [];
    final List<MapEntry<String, double>> acreedores = [];

    for (final r in resumenes) {
      if (r.saldoNeto < -0.01) {
        deudores.add(
          MapEntry(r.socio.id, -r.saldoNeto),
        ); // guardar como positivo para restar
      } else if (r.saldoNeto > 0.01) {
        acreedores.add(MapEntry(r.socio.id, r.saldoNeto));
      }
    }

    final List<DeudaPendiente> resultado = [];

    int i = 0;
    int j = 0;

    while (i < deudores.length && j < acreedores.length) {
      final deudorId = deudores[i].key;
      final acreedorId = acreedores[j].key;
      final deuda = deudores[i].value;
      final credito = acreedores[j].value;

      final minimo = deuda < credito ? deuda : credito;

      if (minimo > 0.01) {
        resultado.add(
          DeudaPendiente(
            deudor: sociosMap[deudorId]!,
            acreedor: sociosMap[acreedorId]!,
            monto: minimo,
          ),
        );
      }

      deudores[i] = MapEntry(deudorId, deuda - minimo);
      acreedores[j] = MapEntry(acreedorId, credito - minimo);

      if (deudores[i].value <= 0.01) i++;
      if (acreedores[j].value <= 0.01) j++;
    }

    return resultado;
  }
}
