/// Donde escribe el receptor.
///
/// Existe porque no todas las plataformas tienen una ruta que abrir con
/// `dart:io`: en Android los archivos visibles para la persona se escriben
/// por MediaStore, contra un `ContentResolver`, y ahi no hay `File`. El
/// receptor no puede saber cual de las dos cosas tiene delante, asi que se le
/// inyecta esta abstraccion, igual que `freeBytes`.
///
/// `core/transfer/` sigue siendo Dart puro: la implementacion de MediaStore
/// vive en la capa de plataforma, que si conoce Flutter.
library;

import 'dart:async';

/// El destino de una sesion. Ya validado: existe y se puede escribir en el.
abstract interface class ReceiveDestination {
  /// Reserva un hueco para [name], resolviendo colisiones.
  ///
  /// Lo que devuelve **todavia no es un archivo terminado** para nadie: es el
  /// equivalente del `.part`.
  Future<IncomingFileSink> create(String name, {required int size});

  /// Donde esta, para poder ensenarlo. Una ruta en escritorio; en Android
  /// puede ser una etiqueta, no algo que se pueda abrir con `dart:io`.
  String get label;
}

/// Un archivo a medio escribir.
///
/// Hasta [commit] no existe como archivo terminado. Es lo que sostiene el
/// invariante de que un checksum que no cuadra nunca deja un archivo con el
/// nombre definitivo y el contenido a medias.
abstract interface class IncomingFileSink {
  /// El nombre definitivo, ya saneado y sin colisiones. Puede no ser el que
  /// pidio el par: la sesion reporta **este**.
  String get name;

  /// Escribe un trozo.
  ///
  /// Es asincrono a proposito: esperarlo es lo unico que impide que el
  /// receptor lea de la red mas rapido de lo que el disco traga y acumule sin
  /// techo. Con esto, lo que puede estar en vuelo es un chunk, que ya tiene
  /// limite validado (`maxChunkFrameBytes`).
  Future<void> add(List<int> data);

  Future<void> flush();

  /// Publica el archivo. **Solo se llama tras comparar el trailer.** Devuelve
  /// donde quedo —ruta o URI— o `null` si la plataforma no expone ninguna.
  ///
  /// Cierra el sink: no existe la forma de dejarlo abierto.
  Future<String?> commit();

  /// Descarta lo escrito y cierra el sink. Idempotente: se llama tanto en el
  /// camino de error como cuando el checksum no cuadra.
  Future<void> discard();
}
