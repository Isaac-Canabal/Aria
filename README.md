# Syroda

Envía documentos, imágenes y archivos entre dispositivos cercanos, sin cables
ni cuentas en la nube.

Los archivos van directos de un dispositivo al otro por la red local. No pasan
por ningún servidor, no se suben a ninguna nube y no hace falta registrarse:
no hay cuentas. Cada transferencia la autoriza un código de 6 dígitos que
muestra quien recibe, y al terminar se comprueba con sha256 que el archivo
llegó completo; si la comprobación falla, no se guarda a medias.

Android y Windows. Interfaz en español (es-CO).

## Estado

**El flujo completo —descubrirse, emparejar y transferir con verificación— se
probó entre un teléfono Android y un PC en la misma red, y funcionó.** No está
terminada, y hay trabajo posterior a esa prueba que todavía no se ha ejecutado
en un dispositivo (ver la checklist de validación en `CLAUDE.md`):

| | |
|---|---|
| Transporte (Fases 1–3) | Cerrado. Descubrimiento mDNS, emparejamiento por código, transferencia con verificación |
| UI de Android (Fase 4) | Cerrada |
| UI de Windows (Fase 5) | **Pendiente.** El transporte corre en Windows; falta la interfaz propia del escritorio |
| Instalador y firma (Fase 6) | Pendiente |

**No hay cifrado en v1.** El canal (`SecureChannel`) es deliberadamente
pass-through: la arquitectura del handshake está hecha para que introducir
SPAKE2 sea sustituir la implementación del canal sin cambiar el formato de
cable, pero eso todavía no está. Por eso ninguna superficie de la app dice
"cifrado", "seguro" ni dibuja un candado — sería afirmar algo que hoy no es
cierto. Lo que sí es cierto y es lo que se dice: la transferencia ocurre en la
red local y no pasa por servidores.

Consecuencia práctica: el identificador de dispositivo que se usa para
reconocer pares ya emparejados es una afirmación **sin verificar** mientras el
canal sea plano. El filtro de "solo dispositivos emparejados" es comodidad —
menos ruido en la lista —, no un control de seguridad. **El código de 6 dígitos
es lo único que autoriza una sesión**, también entre dispositivos ya
emparejados.

Tampoco existen todavía: escanear código QR (el botón de la pantalla Recibir
abre "Conectar manualmente", que cubre el mismo caso) ni modo claro. Las dos
son decisiones diferidas, documentadas en `CLAUDE.md` con su razón.

## Compilar

Requisitos completos y sus porqués en [`docs/BUILD.md`](docs/BUILD.md) — hay
dos que no detecta `flutter doctor` y que rompen la compilación de forma poco
evidente: **JDK 17** para Gradle y **Developer Mode** de Windows.

```
flutter pub get
flutter analyze
flutter test

flutter build apk --release --split-per-abi
flutter build windows --release
```

## Cómo está organizado

```
lib/core/transfer/   el protocolo y el transporte. Dart puro, sin Flutter:
                     sus tests corren sin binding
lib/core/data/       SQLite (historial, emparejados) y preferencias
lib/core/platform/   lo que necesita código nativo: espacio libre, MediaStore,
                     abrir archivos, servicio en primer plano
lib/state/           los proveedores de Riverpod. La UI no habla con core/
lib/features/        las pantallas
lib/design/          el design system: tokens y componentes

index.html           los mockups. Son la fuente de verdad de la interfaz
css/nocturne.css     el design system Nocturne, verbatim del proyecto de
                     diseño. No se modifica aquí
css/syroda.css       lo propio de Syroda: andamiaje de la galería, marcos de
                     dispositivo y los patrones que las pantallas repiten
```

`index.html` no es documentación de apoyo: es la referencia contra la que se
verifica la interfaz. `flutter test test/gallery_snapshot_test.dart` deja en
`build/gallery.png` una captura de todos los componentes a tamaño real para
compararla contra los mockups sin abrir la app.

## Antes de tocar nada

[`CLAUDE.md`](CLAUDE.md) recoge las invariantes del proyecto: el formato de
cable congelado, el veto de copy sobre el cifrado, la regla de disponibilidad
por ciclo de vida, y las decisiones que ya se tomaron con su razón. No es
historia del proyecto — si una de esas reglas se rompe, el cambio está mal.
