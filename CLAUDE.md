# Syroda — invariantes

Reglas que aplican a todo el código. No son historia del proyecto: si una de
estas se rompe, el cambio está mal.

## Dónde está el proyecto

Fases 1, 2 y 3 cerradas, y **el formato de cable está congelado** (ver
"Formato de cable — congelado"): cambiarlo rompe la compatibilidad con
cualquier build publicado. **La Fase 4 (UI Android) está cerrada, a la
espera de validación en dispositivo** (ver "Orden de la sesión siguiente").

Hecho en la Fase 4: las 8 pantallas y el shell con la navegación inferior
(`lib/features/`), los controladores que conectan transporte y persistencia
(`lib/state/transfer_controllers.dart`), el manifiesto con sus permisos, el
servicio en primer plano atado a ambos sentidos, el proveedor de espacio libre
por canal nativo, la regla de disponibilidad por ciclo de vida,
`SystemPermissionService` conectado a Enviar y Recibir
(`lib/features/shared/discovery_permission.dart`): `nearbyDevices` bloquea la
pantalla completa mientras no esté concedido (`denied` pide de nuevo,
`permanentlyDenied` manda a Ajustes sin reintentar el diálogo del sistema), y
`notifications` se pide igual pero solo avisa sin bloquear — la transferencia
funciona sin ese permiso, nada más pierde su indicador; y el estado vacío de
Enviar tras `discoveryGracePeriod` sin pares
(`lib/features/send/send_screen.dart`), con su acción "Conectar manualmente"
(`lib/features/send/manual_connect.dart`) y su explicación honesta: si la red
tiene aislamiento de clientes, el manual tampoco va a funcionar, y el hotspot
del teléfono queda como última salida. Ninguno de los tres es un componente
nuevo del design system: se componen con los mismos patrones que cualquier
otro estado vacío.

**Bug real encontrado y corregido al escribir el primer test que renderiza
uno de estos diálogos:** `_CodeDialog` (`code_prompt.dart`), `_sheet`
(`profile_screen.dart`, usado por "Nombre del dispositivo") y el nuevo
`_ManualConnectDialog` construían su `showDialog` con un `TextField` (dentro
de `SyrodaInput`) sin ningún ancestro `Material` — `showDialog` no pone uno
solo, lo pone el `Scaffold` de la ruta que abre el diálogo, que vive en un
`OverlayEntry` distinto. Los tres habrían caído con "No Material widget
found" en cuanto alguien tocara esos campos en un dispositivo real. Arreglado
envolviendo cada uno en `Material(type: MaterialType.transparency)`. Nadie lo
había visto porque nada de esto se había renderizado nunca — ni en un
dispositivo, ni en un test — hasta ahora.

**Nada se ha ejecutado en un dispositivo real.** Todo el transporte está
verificado en loopback, que no tiene mDNS, ni firewall, ni Doze, ni cambios de
red. Las pantallas están verificadas por tests de widget con Riverpod
faseado, no en un dispositivo. El Kotlin de `StatFs` y el servicio en primer
plano no se han compilado nunca fuera de esta máquina.

Estas cuatro decisiones están **razonadas y sin validar**, y son las primeras
candidatas a estar mal:

- El `MulticastLock` sostenido con un descubrimiento de adorno.
- La regla de disponibilidad por ciclo de vida (qué emite Android y cuándo).
- El fallback de emparejamiento manual, incluido el diagnóstico de aislamiento
  de clientes.
- La regla de firewall de Windows y su diagnóstico de "0 pares".

**Orden de la sesión siguiente:**

1. **Prueba real con dos dispositivos en la misma red, antes de abrir la Fase
   5.** La Fase 4 ya está completa en código; esta prueba es lo único que
   falta. Abrir la UI de Windows sobre un transporte que nunca vio una red de
   verdad multiplica por dos el trabajo de cualquier corrección. Checklist
   abajo.

### Checklist de validación en dispositivo

**Validada el 31 de julio de 2026** entre un teléfono Android y un PC en la
misma red. Lo marcado se vio funcionar; lo que sigue sin marcar es lo que
**no** se comprobó, y la distinción es el valor de esta lista. No marcar nada
por inercia.

- [x] **Descubrimiento mutuo** entre el teléfono y el PC: cada uno ve al otro
      en su lista de Enviar. Cubre de una vez el `MulticastLock` sostenido
      por el descubrimiento de adorno y el propio workaround del anuncio
      (ver "Deuda con fase asignada") — si el anuncio no sostiene el lock
      como se espera, esta es la línea que lo va a mostrar.
- [x] **Handshake**: código correcto autoriza; código incorrecto rechaza sin
      matar la sesión de un intento; agotar los 3 intentos invalida el
      código vigente y genera uno nuevo.
- [x] **Caducidad del código** a los 5 minutos sin usarse
      (`pairingCodeLifetime`), y que un código ya caducado no gaste
      intentos al fallar.
- [x] **Transferencia completa** de un archivo real, con verificación de
      checksum al terminar (el `file_hash` del trailer — confirmar que un
      archivo dañado a propósito se detecta y el `.part` se borra).
- [x] **Cancelación a mitad de transferencia, en ambos sentidos**: el emisor
      cancela y el receptor cancela, y ninguno de los dos deja un `.part`
      huérfano.
- [x] **Foreground service**: la notificación es visible durante la
      transferencia (con `POST_NOTIFICATIONS` concedido), y la transferencia
      sobrevive a cambiar de app y a bloquear la pantalla.
- [x] **Regla de ciclo de vida**: bajar la cortina de notificaciones **no**
      apaga el anuncio (`inactive` no apaga nada); ir a background **sí** lo
      apaga.
- [ ] **Rechazo por espacio insuficiente en Windows.** El de Android quedó
      validado con el `StatFs` real. El proveedor de Windows ya existe
      (`GetDiskFreeSpaceExW`) y compila, pero **no se ha ejecutado**: falta
      ver un rechazo real por espacio en el escritorio, y que la cifra sea la
      del volumen de la carpeta elegida cuando esa carpeta está en otra
      unidad.
- [x] **Destino en Android, que nunca ha corrido**: que el archivo aparece en
      `Descargas/Syroda` desde la app Archivos; que `IS_PENDING` hace su
      trabajo (un archivo a medias **no** se ve como terminado, y un checksum
      que no cuadra no deja nada); que la resolución de colisiones del sistema
      devuelve el nombre real y es el que se muestra; y que el `content://`
      que queda en `localPath` del historial es utilizable —abrirlo— y no una
      ruta que nadie puede usar.
- [x] **Rechazo por destino inválido** (`destinationUnavailable`): llega
      **antes** de empezar el primer archivo, con el lote entero, y el emisor
      muestra ese motivo y no otro.
- [ ] **Elegir la carpeta de recibidos** en Ajustes: que cambiar la colección
      o el nombre en Android manda los archivos siguientes a la carpeta nueva
      —y que la nueva se crea sola—, y que en Windows el diálogo del sistema
      devuelve una ruta en la que de verdad se puede escribir. **Sin marcar a
      propósito:** la función se terminó después de la sesión de validación,
      así que casi con seguridad no estaba en el APK que se probó.
- [x] **Estado vacío tras el grace period** en Enviar
      (`discoveryGracePeriod`), con "Conectar manualmente" funcionando de
      punta a punta contra el `code-card` del receptor.
- [x] **Firewall de Windows** en el primer `bind`: confirmar si Windows pide
      permiso o hace falta la regla manual, y que el diagnóstico de "0
      pares" distinga este caso de los demás.

### Capturar logs de Android durante la prueba

`flutter run` mezcla el log de la app con el de logcat entero — cualquier
otra app instalada también imprime ahí. Para aislar solo este proceso:

    adb logcat -c
    adb logcat --pid=$(adb shell pidof -s com.isaaccanabal.syroda)

`adb logcat -c` vacía el buffer antes de arrancar, para no arrastrar ruido de
antes de la prueba. El PID cambia en cada relanzamiento de la app (no en cada
hot reload, que reusa el proceso) — si se mata y se vuelve a abrir la app,
hay que volver a correr el segundo comando. Para guardar la sesión completa
en un archivo a la vez que se ve en pantalla:

    adb logcat --pid=$(adb shell pidof -s com.isaaccanabal.syroda) | tee syroda_device_test.log

Esto captura tanto lo que imprime Dart (`developer.log`, tag `flutter`) como
lo que loguean los plugins nativos (`nsd_android`, `flutter_foreground_task`,
excepciones de `MainActivity`) bajo sus propios tags — filtrar solo por tag
`flutter` se perdería justamente lo nativo, que es donde más probablemente
aparezca algo nuevo la primera vez que esto corre en un dispositivo real.

## Producto

- Sin backend, sin nube, sin cuentas. Ningún byte de contenido de usuario sale
  de la LAN. Ninguna dependencia puede hacer peticiones de red en runtime (por
  eso Inter va empaquetada en `assets/fonts/`, no por `google_fonts`).
- Toda la UI en español (es-CO), con los textos de `index.html`.
- Sin cuentas quiere decir sin sesión y sin contactos, también en el copy: no
  existe "cerrar sesión" ni la visibilidad "Contactos". La acción destructiva
  de Ajustes es "Olvidar dispositivos emparejados", y la visibilidad tiene
  tres valores: "Todos en la red local", "Solo dispositivos emparejados",
  "Nadie". Un cambio de copy se aplica a la vez en los widgets y en
  `index.html`.
- Sin emojis en código, comentarios ni UI.
- Las dependencias son las aprobadas en la Fase 0. Agregar una requiere
  aprobación explícita del usuario.

## Tokens de diseño

- `css/nocturne.css` es la fuente de verdad visual y no se modifica. Lo propio
  de Syroda vive en `css/syroda.css`.
- `lib/design/nocturne.dart` es el único archivo del proyecto Dart donde puede
  aparecer un color literal. Fuera de ahí: solo referencias a tokens.
- Espaciados, radios, sombras y tipografía salen de los tokens `--space-*`,
  `--radius-*`, `--shadow-*` y la escala de Inter, no de números sueltos.
- Las pantallas replican `index.html`: dimensiones, jerarquías y estados
  (éxito, error, vacío, en progreso) ya están definidos ahí.
- Todo componente nuevo entra a `lib/design/_gallery.dart` con sus variantes.
  El PNG que produce `test/gallery_snapshot_test.dart` es **el** mecanismo de
  verificación contra `index.html`, no un extra: un componente que no aparece
  ahí no está verificado y no se da por terminado.
- Ningún componente sin consumidor. Antes de agregar uno, hay que poder
  señalar la pantalla de `index.html` que lo usa.
- Los widget tests cargan Inter desde `assets/` con `test/fonts.dart`. Nunca
  la fuente de relleno: sus métricas producen desbordamientos falsos y ocultan
  los reales.
- **Un `TextEditingController` de un diálogo pertenece al `State` del diálogo,
  nunca a quien lo abre.** El future de `showDialog` completa cuando
  **empieza** el pop, no cuando el subárbol se desmonta: destruirlo justo
  después del `await` lo destruye mientras el `TextField` sigue montado
  durante la animación de salida. Rompió el renombrado en Ajustes y solo se
  vio en dispositivo. Los tres diálogos siguen ya este patrón
  (`code_prompt.dart`, `manual_connect.dart`, `_NameField`).
- **Los diálogos que llevan un `TextField` necesitan un ancestro `Material`**
  (`Material(type: MaterialType.transparency)`): `showDialog` no pone uno, y
  el `Scaffold` de la ruta que lo abre vive en otro `OverlayEntry`.

## Protocolo

- Descubrimiento: mDNS/DNS-SD, tipo de servicio `_syroda._tcp`, con nombre de
  dispositivo y plataforma en el TXT. Era `_aria._tcp`: cambió con el rename
  del producto a Syroda. Es un cambio al formato de cable congelado, pero con
  la misma justificación que el `device_id`: no hay build publicado todavía,
  y este es el último momento en que eso es cierto. Después de publicar, este
  mismo cambio significaría romper la compatibilidad de cualquier instalación
  existente — exactamente lo que esta sección existe para evitar.
- El puerto de transferencia no es constante: se hace `bind` con puerto 0 y el
  puerto asignado se publica en el registro TXT del anuncio, junto al nombre y
  la plataforma. Nada en el codigo puede asumir un numero de puerto fijo.
- **Un par tiene varias direcciones y la elección es de quien conecta.** Un
  equipo con adaptadores virtuales (WSL2, VPN, Docker) resuelve a varias, y
  desde fuera no hay forma de saber cuál es la alcanzable: quedarse con la
  primera dejaba al par **visible y no conectable**, que es peor que no verlo.
  `Peer.addresses` las guarda todas y `SendSession` las prueba **en serie**,
  ordenadas por `orderCandidates` (misma /24 que una interfaz local primero),
  con un timeout corto por candidata. En serie a propósito: en paralelo el
  receptor aceptaría varias conexiones y abriría varias sesiones para un solo
  envío. El orden es una preferencia, nunca un filtro — si la heurística del
  /24 falla, la dirección buena se prueba igual, solo que después. Esto no
  toca el formato de cable: las direcciones salen del `lookup` local, no del
  protocolo.
- Autorización: el código de 6 dígitos viaja en el header del handshake desde
  la Fase 2 y `TransferSession` rechaza la sesión si no coincide. Esto no se
  pospone ni se degrada a "confiar en la LAN".
- `SecureChannel` es pass-through en v1: difiere el cifrado, nunca la
  autenticación. El handshake se diseña para que introducir SPAKE2 sea
  sustituir la implementación del canal, sin cambiar la forma del header ni el
  orden de los mensajes.
- **Ninguna superficie de UI puede afirmar cifrado mientras `SecureChannel` sea
  pass-through**: sin candados, sin la palabra "cifrado", sin "conexión
  segura". El copy de privacidad se limita a lo cierto en v1: la transferencia
  ocurre en la red local y no pasa por servidores. Cuando exista cifrado real,
  el cambio de copy va en el mismo PR.
- Los errores se modelan como tipos, no como strings (`core/transfer/errors.dart`).

### Formato de cable — congelado

Cambiarlo rompe la compatibilidad con cualquier build publicado. `v` se valida
al recibir y una versión distinta cierra la sesión; v1 no tiene compatibilidad
hacia atrás.

- Frame: `[u8 tipo][u32 longitud big-endian][payload]`. El tipo va **antes** de
  la longitud: sin eso no se pueden intercalar mensajes de control a mitad de
  una transferencia (cancelación, y el handshake del canal cuando llegue
  SPAKE2). Tipos: `0x01` control (JSON UTF-8), `0x02` datos. `0x03`–`0x7F`
  reservados y `0x80`–`0xFF` sin asignar: ambos se rechazan.
- La longitud se valida **antes** de reservar memoria, contra el techo del tipo
  (`protocol/limits.dart`): un `u32` permite anunciar 4 GB. Lo mismo con el
  nombre de archivo, el conteo del manifiesto y `total_bytes`.
- Orden de mensajes, fijo:

      → auth_init {device_id, device, platform, channel, payload}
      ← auth_response {device_id, device, platform, payload}
      → auth_confirm {payload}
      ← auth_result {ok | failure}
      → manifest {files:[{name,size}], total_bytes}
      ← manifest_result {ok | rejected, reason}
      por archivo:
        → file_header {name, size, sha256: null}
        ← ready {ok | rejected, reason}
        → [chunks]
        → file_hash {sha256}
        ← file_done {name, ok | failure}
      → session_end

- Los cuatro mensajes de autorización son fijos aunque el canal plano no
  necesite dos idas y vueltas. SPAKE2 llenará esos mismos `payload` con su
  elemento público y sus MAC: se sustituye la implementación del canal, no la
  secuencia.
- `ready` puede rechazar un archivo sin matar la sesión; el siguiente sigue.
  `manifest_result` rechaza el lote completo, que es donde se valida el espacio
  libre **y el destino**: nunca se falla en el archivo 3 de 5. Que eso se
  cumpla no es disciplina, es la forma del tipo: `reviewManifest` devuelve un
  `ManifestDecision` sellado y el destino ya abierto viene **dentro** de
  `AcceptManifest`, así que no existe la forma de aceptar un lote sin tener
  dónde escribirlo.
- **`RejectionReason.destinationUnavailable` se añadió al cable** cuando el
  destino pasó a ser una carpeta propia. Es un cambio al formato congelado,
  con la misma justificación que `device_id` y `_syroda._tcp`: no hay build
  publicado y este era el último momento en que salía gratis. No se degradó a
  reutilizar `insufficientSpace` ni `unacceptableFile` porque eso haría que el
  emisor mostrara un motivo falso, y el proyecto veta el copy que afirma lo
  que no es cierto. **Ojo:** `requiredEnum` cierra la sesión ante un valor que
  no conoce, así que añadir motivos después de publicar rompe compatibilidad.
- `cancel` va en cualquier dirección y en cualquier momento tras el handshake,
  incluso entre chunks.
- El sha256 es por archivo y va **en el trailer** (`file_hash`), no en el
  header: las dos puntas lo acumulan sobre los bytes que ya están moviendo.
  Pedirlo por adelantado costaba una lectura completa extra en cada punta sin
  habilitar nada, porque la verificación ocurre igual al terminar.
  `file_header.sha256` existe pero **v1 siempre manda null**; queda reservado
  para deduplicación futura, que sí justificaría esa lectura.
- No hay checksum global: la suma de los individuales no aporta.
- El receptor escribe en `<nombre>.part` y solo renombra **tras comparar el
  trailer**. Un checksum que no cuadra borra el parcial.
- El nombre de archivo se sanea **del lado que escribe** (`sanitizeFileName`):
  llega de un par no confiable. Sin separadores de ruta, sin componentes
  relativos, sin nombres reservados de Windows.
- Máximo 3 intentos por código; al agotarlos se invalida y se genera otro. La
  comparación del código es en tiempo constante.

## Fallback de descubrimiento

- Tras N segundos sin pares, el estado vacío gana una acción secundaria
  "Conectar manualmente" más una explicación accionable.
- El emparejamiento manual se compone con patrones existentes: `code-card`
  para IP + código en el receptor, `.input` con `.btn-primary` en el emisor.
  Sin componentes nuevos.
- Si el intento manual también falla por timeout, ese es el diagnóstico de
  aislamiento de clientes: decirlo explícitamente y sugerir el hotspot del
  teléfono.
- Nada de broadcast UDP: se bloquea en los mismos escenarios que el multicast.

## Plataforma

- Android: `NEARBY_WIFI_DEVICES` con `neverForLocation` en API 33+;
  `ACCESS_FINE_LOCATION` en 24–32. El descubrimiento exige `MulticastLock`
  adquirido, y toda transferencia corre bajo foreground service `dataSync`.
- Windows: la app nunca asume que existe la regla de firewall. El diagnóstico
  de "0 pares" cubre el caso de puerto bloqueado con la guía `netsh`.
- `nsd` registra servicios en Windows con `DnsServiceRegister`, que exige
  Windows 10 build 18362 (1903). Ese es el mínimo real en escritorio.
- La ventana sin barra nativa usa `window_manager`, no `bitsdojo_window`.

## Identidad de dispositivo y emparejamiento

- El identificador estable de un dispositivo es el **id de instalación**: 16
  bytes de `Random.secure()` en hexadecimal, creados la primera vez que
  arranca la app y guardados en `shared_preferences`
  (`core/data/installation_id.dart`).
- **No es el nombre** (la persona lo cambia en Ajustes) ni **la IP** (cambia al
  reconectar). Emparejar contra cualquiera de los dos significaría perder el
  par al renombrarlo, o confiar en quien herede su IP.
- **Se obtiene igual en Android y en Windows**: lo genera la app. No hay código
  nativo ni deuda de plataforma. Se descartaron `ANDROID_ID` y `MachineGuid`
  porque exigen código nativo por plataforma, identifican el aparato más allá
  de esta app, y no aportan nada: lo que el emparejamiento necesita es
  continuidad de esta instalación. Reinstalar pierde los emparejamientos, y ese
  es el comportamiento correcto.
- Viaja en `auth_init.device_id` y `auth_response.device_id`, y en la clave
  `id` del TXT del anuncio. `Peer.serviceName` (mDNS, efímero) y
  `Peer.deviceId` (estable) son cosas distintas y no se mezclan.
- **El descubrimiento agrupa y se excluye a sí mismo por `device_id`, nunca
  por nombre de instancia** (`core/transfer/peer_table.dart`). El nombre lo
  renombra el sistema por conflicto ("Nombre" → "Nombre (2)") cuando un
  registro anterior sigue vivo, así que el mismo aparato puede estar en la red
  bajo varios nombres a la vez: indexado por nombre salía repetido, y el
  filtro de sí mismo —que comparaba nombres— no lo reconocía. El
  identificador propio se declara con `excludeSelf` **antes** de anunciar y
  también al empezar a descubrir sin anunciar, porque puede quedar un registro
  zombi de un arranque anterior de esta misma instalación. Y expulsa lo ya
  insertado: bloquear la inserción no basta.
- Emparejar es completar el handshake: cuando una sesión queda autorizada, el
  par se guarda. Renombrarlo actualiza el nombre, no duplica la entrada.
- Un par que no publica identificador **nunca** cuenta como emparejado.

### El `device_id` no está autenticado

Mientras `SecureChannel` sea pass-through, el `device_id` es una **afirmación
sin verificar**: cualquiera en la LAN puede anunciar el de otro y pasar el
filtro de "Solo dispositivos emparejados". Solo se convierte en algo
comprobable cuando SPAKE2 pruebe conocimiento del código.

De ahí, y bajo el veto de copy que ya existe:

- El filtro es **conveniencia** — menos ruido en la lista, menos solicitudes no
  deseadas —, **no un control de seguridad**. No se describe como protección,
  bloqueo ni confianza verificada. Sin candados, sin "seguro".
- La pantalla de emparejados no muestra estados tipo "verificado".
- **El código de 6 dígitos es lo único que autoriza, también para pares ya
  emparejados.** Emparejar no salta el código en v1. Esto es comportamiento,
  no texto: `lib/core/transfer/` no conoce la tabla de emparejados, y el único
  camino a `AuthResult.accepted()` pasa por `PairingService.verify()`. Una
  rama que consulte los emparejados para saltarse el código rompe esta
  invariante.

## Destino de lo recibido

- **La carpeta la elige la persona en Ajustes**, y por defecto es
  `Descargas/Syroda` en las dos plataformas.
- **Lo que se puede elegir no es lo mismo en cada plataforma, y fingir que sí
  lo sería peor.** En escritorio se elige una carpeta cualquiera con el
  diálogo del sistema (`FilePicker.getDirectoryPath`) y se guarda la ruta. En
  Android el almacenamiento por ámbitos **no deja escribir en una ruta
  arbitraria**: se elige la colección (`Descargas` o `Documentos`) y el nombre
  de la carpeta, y MediaStore resuelve el `RELATIVE_PATH`.
- **`file_picker` no sirve para elegir carpeta en Android**, aunque lo
  parezca: lanza `ACTION_OPEN_DOCUMENT_TREE` pero convierte el árbol a una
  ruta de texto (`FileUtils.kt`, `getFullPathFromTreeUri`) y **nunca llama a
  `takePersistableUriPermission`**. Devuelve una ruta que no se puede escribir
  con `dart:io` y un permiso que muere con el proceso. Elegir una carpeta
  arbitraria en Android exigiría SAF propio en Kotlin — no una dependencia
  nueva, porque el canal `syroda/platform` ya existe, pero sí una tercera
  implementación de `ReceiveDestination` que escriba por `DocumentsContract`.
  Está descartado por coste, no por imposibilidad.
- **Se fueron dos interruptores que no hacían nada**: "Guardar fotos en
  Galería" y "Guardar en Descargas" se persistían y se podían cambiar, pero
  **nadie los leía** en el camino de transferencia. Eran una promesa falsa en
  la interfaz; los reemplaza la carpeta, que sí decide algo. Vivían en
  `shared_preferences`, no en SQLite, así que no hubo migración: las claves
  huérfanas se quedan sin molestar.
- **El receptor no escribe contra `dart:io`, escribe contra
  `ReceiveDestination` / `IncomingFileSink`** (`core/transfer/destination.dart`),
  inyectado desde la capa de plataforma igual que `freeBytes`. `core/transfer/`
  sigue siendo Dart puro sin Flutter, que es lo que permite correr sus tests
  sin binding. La lógica de `.part` y checksum se expresa sobre esa
  abstracción: **hasta `commit()` lo escrito no es un archivo terminado para
  nadie**, y `commit()` solo se llama tras comparar el trailer.
- **Android escribe por MediaStore**, no por ruta. `path_provider` no da
  Descargas público: resuelve `getExternalFilesDirs(DIRECTORY_DOWNLOADS)`, que
  es privado de la app e inaccesible desde Archivos en Android 11+ — el
  archivo llegaba donde la persona no podía entrar. MediaStore no necesita
  permiso en tiempo de ejecución en Android 10+ ni dependencia nueva: el lado
  nativo va en el canal `syroda/platform` que ya existía. **`IS_PENDING` es el
  equivalente exacto del `.part`**: la fila existe pero no se ve como archivo
  terminado hasta que se baja el flag. Por debajo de Android 10 no hay
  almacenamiento por ámbitos y se escribe con `File`, con la misma disciplina.
- **Se escribe a `VOLUME_EXTERNAL_PRIMARY`, nunca a `EXTERNAL_CONTENT_URI`.**
  Esa constante apunta a `VOLUME_EXTERNAL`, que es una **vista sintética** que
  fusiona todos los volúmenes y **no admite inserciones**: insertar ahí lanza
  `IllegalArgumentException` en tiempo de ejecución. De paso, esto responde a
  qué volumen se escribe: `VOLUME_EXTERNAL_PRIMARY` **es**
  `Environment.getExternalStorageDirectory()`, así que el destino es siempre
  el almacenamiento primario. Una SD portátil es un volumen secundario al que
  no se escribe nunca; una SD adoptada **pasa a ser** el primario, y los datos
  de la app se mudan con ella. En los dos casos destino y app comparten
  volumen.
- **El espacio libre se mide sobre el volumen del destino**, no sobre el
  almacenamiento interno de la app. En Android MediaStore no expone una ruta,
  así que lo mide el lado nativo con `StatFs` sobre
  `Environment.getExternalStorageDirectory()`, que es exactamente donde
  escribe. Medirlo sobre la carpeta de la app era una aproximación que sobra.
- **Abrir lo recibido va por el canal nativo, sin dependencia nueva.** En
  Windows `ShellExecuteW` y `SHOpenFolderAndSelectItems` (que abre el
  Explorador con el archivo ya seleccionado); en Android un `ACTION_VIEW`
  sobre el `content://` con `FLAG_GRANT_READ_URI_PERMISSION` — como el URI
  viene de MediaStore **no hace falta un FileProvider**. Se descartó
  `url_launcher` (no maneja bien `content://` con concesión de permisos) y
  `open_filex` (una dependencia por ~25 líneas de código nativo).
- **Fallar al abrir no es un fallo de transferencia y no se presenta como
  tal**: aviso corto, la fila se queda donde está. Y **`missing` y
  `noHandler` se distinguen**, porque son problemas distintos y lo que puede
  hacer la persona también: el historial guarda la ruta o el URI, **no el
  archivo**, así que borrarlo desde Archivos o el Explorador es alcanzable y
  no es lo mismo que no tener con qué abrirlo.
- **`IncomingFileSink.add` es asíncrono a propósito.** Esperarlo es lo único
  que impide que el receptor lea de la red más rápido de lo que el destino
  traga y acumule sin techo — con `IOSink.add`, que es síncrono, el buffer
  crecía sin límite. Esperándolo, lo que puede estar en vuelo es un chunk, que
  ya tiene límite validado (`maxChunkFrameBytes`). Importa de verdad en
  Android, donde MediaStore escribe por FUSE y es más lento que la red.

## Estado y persistencia

- Riverpod. La UI no habla con `core/` directamente: consume los proveedores de
  `lib/state/`.
- SQLite guarda **solo estados terminales**. Lo que está en curso vive en
  memoria, en la cola; el historial es lo que ya terminó, bien o mal. Un
  archivo que el par declinó no se registra: no llegó a transferirse.
- `sqflite` no notifica cambios. `HistoryRepository.changes` lo hace explícito
  y `HistoryController` vuelve a consultar. No inventar otro mecanismo.
- En escritorio hay que llamar a `initDatabaseFactory()` antes de abrir nada:
  sin eso `sqflite` no tiene implementación nativa y falla al arrancar.
- **El esquema se cambia agregando una migración al final de la escalera de
  `app_database.dart`, nunca editando una ya publicada** ni borrando la base
  del usuario: eso le costaría su historial. Una base nueva no es un caso
  aparte, se le corre la escalera entera. Hay un test que abre una base en v1 y
  verifica que sobrevive.
- Las fechas se guardan en UTC (`millisecondsSinceEpoch`). La zona la aplica
  quien las muestra.
- `PeerVisibility.nobody` no es un filtro de presentación: se deja de publicar
  el servicio mDNS (`announcingProvider`).
- **`TransferRecord.localPath` no es siempre una ruta de sistema de archivos.**
  En Android, con MediaStore como destino, es un `content://` URI. **Nada
  puede asumir `File(localPath)`** — ni para abrirlo, ni para comprobar que
  existe, ni para borrarlo. Es consecuencia directa de que el archivo tenga
  que ser visible para la persona (ver "No hay forma de ver los archivos
  recibidos" en la deuda con fase asignada), y se olvida fácil porque en
  Windows sí es una ruta y ahí todo funciona. La UI de la Fase 5 abre por
  plataforma, no por `dart:io`.

## Decisiones diferidas

- **Cómo se traduce a Windows "salir de Recibir apaga el anuncio".** En
  Android el invariante se sostiene sobre `announcementProvider`, que es
  `autoDispose`: deja de anunciarse cuando ninguna pantalla lo observa, y la
  pestaña Recibir es lo que lo observa. **La ventana de Windows no tiene
  pestañas**, así que no hay un "salir de Recibir" equivalente y la regla no
  se traduce sola. Las opciones no son equivalentes: anunciarse mientras la
  ventana esté abierta convierte el anuncio en un servicio permanente, que es
  justo lo que el invariante rechaza; atarlo a una zona de la ventana obliga a
  decidir cuál. **Se decide explícitamente al implementar la Fase 5, no por
  omisión.** El riesgo de dejarlo resolverse solo es que el escritorio acabe
  anunciándose siempre sin que nadie lo haya decidido.

- **`.btn-primary` con relleno sólido.** El botón primario es contorno y
  texto; el acento solo rellena en hover/active, al 12% y 22%. Un relleno
  sólido sería el siguiente escalón real de presencia visual, después de haber
  subido `.row-icon` y `.badge` a `accent-800`. **No se hace aquí por la misma
  razón que el modo claro:** `.btn-primary` está en `css/nocturne.css`, que es
  fuente de verdad y no se modifica en este repositorio. Tendría que salir del
  proyecto de diseño y re-sincronizarse. Lo que sí es nuestro —y donde sí se
  actuó— es `css/syroda.css`.
- **Modo claro. Decidido que no, y no por pereza.** Nocturne no es "un tema
  con colores oscuros": está construido **sobre** la oscuridad. Los tokens
  base son cinco, pero casi todo lo demás se deriva de `text` por
  transparencia — `divider` es `text` al 16%, `label` al 70%, `hoverNeutral`
  al 7%. Eso funciona porque un blanco translúcido sobre fondo oscuro aclara
  de forma predecible; invertido, los mismos porcentajes **no** dan el mismo
  contraste percibido, así que habría que rehacer y recalibrar toda la escala
  de derivados, no cambiar cinco colores. Las rampas `neutral*` y `accent*`
  están ordenadas para oscuro (`neutral100` es casi blanco y se usa como
  tinta), y `NocturneShadow` asume fondo oscuro: en claro la elevación se
  resuelve con bordes, que es otra decisión de diseño. **Y sobre todo: la
  paleta clara no existe**, así que hacerlo aquí sería improvisarla, y
  `css/nocturne.css` es fuente de verdad.
  **Si alguna vez se retoma, el orden correcto es:** paleta clara en el
  proyecto de diseño → re-sync de `css/nocturne.css` → `nocturne.dart` deja
  de ser constantes y pasa a un tema resuelto en runtime. Cualquier otro
  camino es una bifurcación que se desincroniza en la primera semana.

- **Escanear código QR.** Los mockups traen el botón en la pantalla Recibir
  (`index.html:234-237`). No está implementado: hace falta `qr_flutter` para
  dibujar el código en el receptor y `mobile_scanner` para leerlo en el
  emisor, más el permiso `CAMERA` en Android. Ninguna de las dos está en las
  dependencias aprobadas en la Fase 0. En su lugar, ese botón abre "Conectar
  manualmente" (dirección + código), que cubre el mismo caso sin dependencias
  nuevas. Es una decisión diferida, no un olvido: retomarla exige aprobar esas
  dos dependencias.

## Disponibilidad y ciclo de vida

**Aceptar una sesión que el proceso no puede sostener es peor que no estar
disponible.** En Android 12+ arrancar un servicio en primer plano desde
background lanza `ForegroundServiceStartNotAllowedException`, y para entonces
la sesión ya estaría autorizada y el archivo empezado: el resultado es un
archivo a medias en vez de un rechazo limpio. De ahí la regla:

- **En background no se anuncia y no se aceptan conexiones nuevas.** El par ni
  siquiera ve el dispositivo, en vez de verlo y que no le acepte nada.
- **`inactive` no apaga nada.** Android lo emite al bajar la cortina de
  notificaciones, al mostrar un diálogo de permisos y al entrar una llamada;
  apagarse ahí hace parpadear el dispositivo en la lista del emisor sin causa
  visible. Solo `paused`, `hidden` y `detached` apagan (`isForeground`, con
  test).
- **Una sesión en vuelo no se interrumpe.** `ReceiveServer.setAccepting(false)`
  deja de aceptar **sin cerrar** el `ServerSocket`: la transferencia en curso
  sigue con su servicio en primer plano hasta terminar, que es exactamente
  para lo que ese servicio existe. Cerrar el socket la mataría.
- **Salir de la pantalla Recibir apaga el anuncio** igual que irse a
  background: `announcementProvider` es `autoDispose`. "Esperando conexión…" es
  el estado de una pantalla abierta, no un servicio permanente.
  **`autoDispose` por sí solo no basta, y esto se descubrió en dispositivo:**
  el shell usa un `IndexedStack`, que **construye las cuatro pestañas** aunque
  solo pinte una, así que `ReceiveScreen.build` corría siempre y el proveedor
  nunca se quedaba sin observadores — el dispositivo se anunciaba de forma
  permanente. Por eso `ReceiveScreen` recibe `active` y solo observa el
  anuncio cuando es la pestaña visible. El `IndexedStack` se mantiene a
  propósito: preserva el estado de las otras pestañas (los archivos ya
  elegidos en Enviar, su cuenta atrás de `discoveryGracePeriod`), y cambiarlo
  por un `switch` arreglaría el anuncio rompiendo eso. Hay test de regresión
  (`test/features/shell/announcement_lifecycle_test.dart`).
- **Al volver a primer plano se reanuncia y se vuelve a aceptar.** El código
  **no** rota por ciclo de vida: quien lo dicta en voz alta y mira otra app
  volvería a un código distinto sin que nada lo explique. Se renueva tras
  agotar los intentos, y **caduca a los 5 minutos** sin usarse
  (`pairingCodeLifetime`), que sí se puede explicar en pantalla: "Código
  caducado, generar uno nuevo". Un código caducado no gasta intentos.

## Deuda con fase asignada

- **MulticastLock sostenido con un descubrimiento de adorno.**
  `announcementProvider` mantiene vivo el descubrimiento mientras el
  dispositivo se anuncia, solo para sostener el `WifiManager.MulticastLock`.
  Es un defecto de `nsd_android`, no nuestro: adquiere el lock en
  `startDiscovery` (`NsdAndroidPlugin.kt:96`) y lo libera en `stopDiscovery`
  (`:131`), sin atarlo nunca al registro — pero responder una consulta mDNS
  también exige recibir multicast. Cuesta radio por resultados que no se usan.
  **Sustituible en cuanto el plugin ate el lock también al registro**; vale la
  pena abrir el issue upstream con esas dos líneas.

- **No hay forma de ver los archivos recibidos.** Falta la superficie de UI
  para listarlos y abrirlos, que es **Fase 5**. El destino ya está resuelto
  (ver "Destino de lo recibido"): los archivos llegan a `Descargas/Syroda` en
  las dos plataformas y el checksum cuadra.

- ~~**Proveedor nativo de espacio libre.**~~ **Cerrado.** Android mide con
  `StatFs` sobre `VOLUME_EXTERNAL_PRIMARY` y Windows con
  `GetDiskFreeSpaceExW` sobre la carpeta de destino, los dos por el canal
  `syroda/platform`. Se usa `lpFreeBytesAvailableToCaller` y no
  `lpTotalNumberOfFreeBytes`: el primero respeta las cuotas de disco del
  usuario, que es lo que de verdad se puede escribir.
  **Lo que había en Windows no era `withoutSpaceCheck`, era algo peor:**
  `receiveServerProvider` sí construía la política con `freeBytes`, pero el
  canal no implementaba `freeSpace`, así que `NativeFreeSpaceProvider`
  devolvía `null` ante el `MissingPluginException` y `reviewManifest` se
  saltaba la comprobación **sin dejar rastro**. La advertencia de
  `withoutSpaceCheck` existe justamente para que eso no pase, y el camino de
  Windows la esquivaba. Por eso el lado nativo ahora devuelve un error en vez
  de un valor vacío cuando no puede medir.

## Build

    flutter analyze
    flutter test
    flutter build apk --release --split-per-abi
    flutter build windows --release

Para comparar la galeria contra los mockups sin abrir la app:
`flutter test test/gallery_snapshot_test.dart` deja el PNG en
`build/gallery.png` (o donde apunte `SYRODA_SNAPSHOT`).

El instalador de Windows empaqueta la DLL de SQLite que `sqflite_common_ffi`
carga en runtime: sin ella la app arranca y falla al abrir el historial, y
solo se nota en una maquina limpia.

El instalador de Windows es Inno Setup con `PrivilegesRequired=admin` (crea la
regla de firewall). El `.exe` va sin firmar en v1: SmartScreen mostrará
"editor desconocido"; es deuda conocida documentada en `docs/BUILD.md`.
El `key.properties` de Android está en `.gitignore` y su procedimiento se
documenta, nunca se generan claves reales en el repo.
