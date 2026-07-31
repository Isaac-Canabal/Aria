/// El codigo de 6 digitos que el receptor muestra y el emisor teclea.
library;

import 'dart:async';
import 'dart:math';

import 'protocol/limits.dart';

/// Un codigo vigente. [display] es la forma de los mockups: "482 913".
class PairingCode {
  const PairingCode(this.digits);

  /// Seis digitos, con ceros a la izquierda si hacen falta.
  final String digits;

  String get display => '${digits.substring(0, 3)} ${digits.substring(3)}';

  @override
  bool operator ==(Object other) =>
      other is PairingCode && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}

enum PairingOutcome {
  accepted,

  /// No coincide, pero quedan intentos.
  invalidCode,

  /// Se agotaron los intentos. El codigo quedo invalidado y ya hay uno nuevo.
  tooManyAttempts,

  /// Estuvo visible demasiado tiempo sin usarse.
  expired,
}

/// Cuanto vive un codigo sin usarse. Cubre el que quedo a la vista mucho rato
/// —una pantalla olvidada sobre la mesa— sin rotar por debajo de quien lo
/// acaba de dictar en voz alta.
const Duration pairingCodeLifetime = Duration(minutes: 5);

/// Genera el codigo, cuenta los intentos y lo invalida.
///
/// Seis digitos son un millon de combinaciones y el atacante esta en la misma
/// LAN con TCP directo: sin limite de intentos, adivinarlo es cuestion de
/// minutos. Tras [maxPairingAttempts] fallos el codigo se invalida y se emite
/// uno nuevo por [codes].
class PairingService {
  PairingService({
    Random? random,
    this.maxAttempts = maxPairingAttempts,
    this.lifetime = pairingCodeLifetime,
    DateTime Function()? clock,
  }) : _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now {
    _current = _generate();
  }

  final Random _random;
  final int maxAttempts;
  final Duration lifetime;
  final DateTime Function() _clock;

  late DateTime _issuedAt;

  final StreamController<PairingCode> _codes =
      StreamController<PairingCode>.broadcast();

  late PairingCode _current;
  int _failures = 0;

  PairingCode get current => _current;

  /// Intentos que quedan antes de invalidar el codigo.
  int get remainingAttempts => maxAttempts - _failures;

  /// Emite cada codigo nuevo, para que la pantalla Recibir repinte el suyo.
  Stream<PairingCode> get codes => _codes.stream;

  /// Compara en tiempo constante: una comparacion que corta en el primer
  /// digito distinto convierte un millon de intentos en sesenta.
  /// Si el codigo vigente ya caduco. La pantalla lo usa para ofrecer generar
  /// uno nuevo en vez de dejar a la persona dictando algo que no sirve.
  bool get isExpired => _clock().difference(_issuedAt) >= lifetime;

  PairingOutcome verify(String candidate) {
    if (isExpired) return PairingOutcome.expired;

    if (_constantTimeEquals(candidate.codeUnits, _current.digits.codeUnits)) {
      _failures = 0;
      return PairingOutcome.accepted;
    }

    _failures++;
    if (_failures >= maxAttempts) {
      regenerate();
      return PairingOutcome.tooManyAttempts;
    }
    return PairingOutcome.invalidCode;
  }

  /// Invalida el codigo vigente y emite uno nuevo.
  PairingCode regenerate() {
    _failures = 0;
    _current = _generate();
    _issuedAt = _clock();
    if (!_codes.isClosed) _codes.add(_current);
    return _current;
  }

  Future<void> dispose() => _codes.close();

  PairingCode _generate() {
    _issuedAt = _clock();
    return PairingCode(_random.nextInt(1000000).toString().padLeft(6, '0'));
  }
}

/// Compara sin cortocircuito. La diferencia de longitud si se filtra, pero el
/// codigo tiene longitud fija y publica.
bool _constantTimeEquals(List<int> a, List<int> b) {
  int diff = a.length ^ b.length;
  final int length = a.length < b.length ? a.length : b.length;
  for (int i = 0; i < length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
