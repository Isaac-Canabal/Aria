# Compilar Aria

Este documento crece con el proyecto. Hoy cubre los requisitos y los comandos
que ya existen; los instaladores llegan en la Fase 6.

## Requisitos del entorno

| | |
|---|---|
| Flutter | 3.44.6 (canal stable) o superior, con Dart 3.12 |
| Android | SDK con API 36; **la ruta del SDK no puede llevar espacios** — las herramientas del NDK fallan |
| Windows | Visual Studio 2022 Build Tools con la carga "Desarrollo de escritorio con C++" |

### Mínimo de Windows en tiempo de ejecución: build 18362

La app registra su servicio mDNS con `nsd`, que en Windows usa la API
`DnsServiceRegister` de `dnsapi.dll`. Esa API existe desde **Windows 10 versión
1903 (build 18362, mayo de 2019)**.

Por debajo de esa build la app arranca, pero no puede anunciarse ni descubrir
pares: la pantalla se queda en cero dispositivos sin causa aparente. El
instalador de la Fase 6 declara ese mínimo, y el diagnóstico de "0 pares" tiene
que distinguir este caso del firewall.

## Comandos

    flutter pub get
    flutter analyze
    flutter test

    flutter build apk --release --split-per-abi
    flutter build windows --release

### Ver la galería de componentes sin abrir la app

    flutter test test/gallery_snapshot_test.dart

Deja un PNG de la galería completa en `build/gallery.png`, o donde apunte la
variable de entorno `ARIA_SNAPSHOT`. Es el mecanismo con el que se compara la
implementación contra `index.html`.

## Firma y empaquetado

Pendiente de la Fase 6:

- Android: keystore de release, `key.properties` fuera del repositorio.
- Windows: instalador con Inno Setup, `PrivilegesRequired=admin` para crear la
  regla de firewall, y la DLL de SQLite que `sqflite_common_ffi` carga en
  tiempo de ejecución.
- El `.exe` va sin firmar en v1: SmartScreen mostrará "editor desconocido".
