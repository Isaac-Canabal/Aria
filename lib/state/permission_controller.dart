/// Conecta `PermissionService` con las pantallas de envio y recepcion: ambas
/// necesitan ver dispositivos cercanos, y ambas corren bajo el servicio en
/// primer plano que necesita notificaciones para mostrar su aviso.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/permissions.dart';

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const SystemPermissionService());

/// Pide [permission] al entrar a una pantalla que lo necesita.
///
/// `autoDispose`: salir de la pantalla no deja nada pendiente, y volver a
/// entrar vuelve a pedirlo, por si la persona lo cambio en Ajustes mientras
/// tanto. `permission_handler` no reabre el dialogo del sistema una vez que
/// el permiso queda denegado para siempre: volver a pedirlo aqui es seguro,
/// nunca un dialogo que insiste sin efecto.
final AutoDisposeFutureProviderFamily<PermissionOutcome, SyrodaPermission>
requestPermissionProvider = FutureProvider.autoDispose
    .family<PermissionOutcome, SyrodaPermission>((
      Ref ref,
      SyrodaPermission permission,
    ) {
      final PermissionService service = ref.watch(permissionServiceProvider);
      return service.request(permission);
    });
