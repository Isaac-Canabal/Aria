# Compilar Syroda

Este documento crece con el proyecto. Hoy cubre los requisitos y los comandos
que ya existen; los instaladores llegan en la Fase 6.

## Requisitos del entorno

| | |
|---|---|
| Flutter | 3.44.6 (canal stable) o superior, con Dart 3.12 — verificar con `flutter doctor` |
| Android | SDK con API 36; **la ruta del SDK no puede llevar espacios** — las herramientas del NDK fallan sin distinguir el motivo en el error |
| Android | JDK 17 para Gradle (ver "JDK para Android" abajo) |
| Windows (desarrollo) | Developer Mode activo — sin él falla el paso de symlinks de plugins, y con eso cualquier `flutter run` en Windows |
| Windows (compilación) | Visual Studio 2022 Build Tools con la carga "Desarrollo de escritorio con C++" — sin ella `flutter build windows` falla |

`flutter doctor` valida Flutter, Android SDK y Visual Studio. No valida el JDK
de Gradle ni el Developer Mode: revisar esos dos a mano con los comandos de
abajo.

### JDK para Android: por qué 17, no el que detecte el sistema

`android/build.gradle.kts` fuerza el plugin clásico de Kotlin sobre el
subproyecto `file_picker` (ver el comentario ahí: `file_picker` se salta ese
plugin en AGP 9+ asumiendo el soporte nativo de Kotlin de AGP, pero
`android.builtInKotlin=false` en `android/gradle.properties` lo desactiva,
porque `flutter_foreground_task` y `nsd_android` todavía aplican el plugin
clásico sin condición). Ese Kotlin forzado no fija su propio `jvmTarget`, así
que compila con el JDK que use Gradle. Si Gradle corre con JDK 21 (lo más
común: `flutter` sigue `JAVA_HOME` o el JDK de Android Studio), ese Kotlin
queda en target 21 mientras el resto del módulo sigue en `sourceCompatibility
17`, y la build falla con "Inconsistent JVM Target Compatibility".

La app necesita un JDK 17 instalado y apuntado explícitamente:

    flutter config --jdk-dir="<ruta al JDK 17>"

Por ejemplo, con Eclipse Temurin 17 en Windows:

    flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-17.0.7.7-hotspot"

Verificar qué JDKs hay instalados y cuál detecta el sistema:

    cd android && ./gradlew -q javaToolchains

Este ajuste es de máquina, no del repositorio: `flutter config` lo guarda
fuera del proyecto (no en `android/gradle.properties`, que si llevara una ruta
de JDK ahí rompería la build de cualquier otra máquina).

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
variable de entorno `SYRODA_SNAPSHOT`. Es el mecanismo con el que se compara la
implementación contra `index.html`.

## Rename Aria -> Syroda: pasos manuales pendientes

El repositorio ya quedó renombrado (`applicationId`, namespace, paquete Dart,
tipo de servicio mDNS, nombres de archivo, texto visible — ver `CLAUDE.md`).
Dos cosas quedan fuera del repositorio y las hace quien tenga acceso a la
máquina y a GitHub, no un cambio de código:

- **Carpeta local `C:\Aria` → `C:\Syroda`** (o el nombre que prefieras): un
  proceso no puede renombrar el directorio en el que está corriendo. Cerrar
  cualquier editor/terminal abierto en la carpeta primero.
- **Repositorio de GitHub**: Settings → General → Repository name. GitHub
  redirige la URL vieja automáticamente durante un tiempo, pero conviene
  actualizar el remoto local después:

      git remote set-url origin <URL nueva del repositorio>
      git remote -v

Tras mover la carpeta, `flutter clean` antes del primer build ahí: las rutas
absolutas dentro de `build/` y `.dart_tool/` quedan apuntando a `C:\Aria`.

## Firma y empaquetado

Pendiente de la Fase 6:

- Android: keystore de release, `key.properties` fuera del repositorio.
- Windows: instalador con Inno Setup, `PrivilegesRequired=admin` para crear la
  regla de firewall, y la DLL de SQLite que `sqflite_common_ffi` carga en
  tiempo de ejecución.
- El `.exe` va sin firmar en v1: SmartScreen mostrará "editor desconocido".
