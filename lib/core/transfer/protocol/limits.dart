/// Limites del protocolo. Todos se validan **antes** de reservar memoria: un
/// par malicioso o con un bug puede anunciar cualquier tamano, y un `u32`
/// llega hasta 4 GB.
library;

/// Version del protocolo. Se valida al recibir; una version distinta cierra
/// la sesion con un error tipado. v1 no tiene compatibilidad hacia atras.
const int protocolVersion = 1;

/// Un frame de control nunca es grande: son objetos JSON pequenos.
const int maxControlFrameBytes = 64 * 1024;

/// Lo que el emisor mete en cada frame de datos.
const int chunkBytes = 64 * 1024;

/// El techo que acepta el receptor para un frame de datos. Deja aire sobre
/// [chunkBytes] para cuando el canal cifre y el sellado crezca respecto al
/// texto plano.
const int maxChunkFrameBytes = 1024 * 1024;

/// Nombre de archivo, ya saneado, en bytes UTF-8.
const int maxFileNameBytes = 255;

/// Archivos por sesion.
const int maxManifestEntries = 1000;

/// Tamano total anunciado en el manifiesto, y de un archivo suelto.
const int maxTotalBytes = 1 << 40; // 1 TiB

/// Intentos de codigo antes de invalidarlo y generar uno nuevo.
const int maxPairingAttempts = 3;
