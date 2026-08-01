package com.isaaccanabal.syroda

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import java.io.File
import java.io.OutputStream

/**
 * Escribe en Descargas/Syroda por MediaStore.
 *
 * `path_provider` no da Descargas publico en Android: resuelve la carpeta
 * privada de la app, que en Android 11+ la persona no puede abrir desde
 * Archivos. MediaStore si, y sin permiso en tiempo de ejecucion desde
 * Android 10.
 *
 * `IS_PENDING` es el equivalente del `.part`: la fila existe pero no se ve
 * como archivo terminado hasta que se baja el flag, y eso solo ocurre tras
 * comparar el sha256 del trailer. Un checksum que no cuadra borra la fila.
 *
 * Por debajo de Android 10 no hay `IS_PENDING` ni almacenamiento por ambitos:
 * ahi se escribe con `File` sobre Descargas, con la misma disciplina de
 * `.part` y renombrado al final.
 */
class MediaStoreDownloads(private val context: Context) {

    private val open = HashMap<String, OutputStream>()

    /** Las filas creadas en el modo antiguo, para el renombrado final. */
    private val legacy = HashMap<String, File>()

    private val resolver: ContentResolver
        get() = context.contentResolver

    private val scoped: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /**
     * Comprueba que hay donde escribir antes de aceptar un lote. Se responde
     * al validar el manifiesto, nunca a mitad del archivo 3 de 5.
     */
    fun ready(collection: String, folder: String): Boolean = try {
        if (scoped) {
            Environment.getExternalStorageState() == Environment.MEDIA_MOUNTED
        } else {
            legacyFolder(collection, folder).let { it.exists() || it.mkdirs() }
        }
    } catch (e: Exception) {
        false
    }

    /**
     * El espacio libre del volumen al que se escribe de verdad.
     *
     * `VOLUME_EXTERNAL_PRIMARY` **es** `Environment.getExternalStorageDirectory()`,
     * asi que este es el volumen del destino y no una aproximacion: medir sobre
     * el almacenamiento interno de la app seria otra cosa cuando no coinciden.
     */
    fun freeBytes(): Long = StatFs(
        Environment.getExternalStorageDirectory().absolutePath
    ).availableBytes

    /**
     * Reserva la fila y abre el flujo. Devuelve el uri y el nombre que quedo:
     * MediaStore resuelve las colisiones por su cuenta y puede no ser el que
     * se pidio, asi que la sesion reporta el que vuelve de aqui.
     */
    fun create(name: String, collection: String, folder: String): Map<String, String> {
        if (!scoped) return createLegacy(name, collection, folder)

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${directoryOf(collection)}/$folder"
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        // `VOLUME_EXTERNAL_PRIMARY`, no `EXTERNAL_CONTENT_URI`: esa constante
        // apunta a `VOLUME_EXTERNAL`, que es una vista sintetica que fusiona
        // todos los volumenes y **no admite inserciones**. Insertar ahi lanza
        // IllegalArgumentException en tiempo de ejecucion.
        val uri = resolver.insert(collectionUri(collection), values)
            ?: throw IllegalStateException("MediaStore no acepto la fila para $name")

        open[uri.toString()] = resolver.openOutputStream(uri, "w")
            ?: throw IllegalStateException("sin flujo de escritura para $name")

        return mapOf("uri" to uri.toString(), "name" to displayNameOf(uri, name))
    }

    fun write(uri: String, bytes: ByteArray) {
        val stream = open[uri] ?: throw IllegalStateException("flujo cerrado: $uri")
        stream.write(bytes)
    }

    fun flush(uri: String) {
        open[uri]?.flush()
    }

    /** Baja `IS_PENDING`: hasta aqui el archivo no existe como terminado. */
    fun publish(uri: String) {
        close(uri)
        legacy.remove(uri)?.let { partial ->
            val target = File(partial.parentFile, partial.name.removeSuffix(PART))
            if (!partial.renameTo(target)) {
                throw IllegalStateException("no se pudo renombrar ${partial.name}")
            }
            return
        }
        val values = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
        resolver.update(Uri.parse(uri), values, null, null)
    }

    /** Descarta lo escrito. El parcial nunca sobrevive a un checksum malo. */
    fun discard(uri: String) {
        close(uri)
        legacy.remove(uri)?.let { partial ->
            partial.delete()
            return
        }
        try {
            resolver.delete(Uri.parse(uri), null, null)
        } catch (e: Exception) {
            // Borrar la fila pendiente es lo ultimo que se intenta.
        }
    }

    private fun close(uri: String) {
        open.remove(uri)?.let {
            try {
                it.flush()
                it.close()
            } catch (e: Exception) {
                // Ya estaba cerrado o el volumen desaparecio.
            }
        }
    }

    private fun displayNameOf(uri: Uri, fallback: String): String {
        resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getString(0)
            }
        return fallback
    }

    /**
     * La coleccion de MediaStore que corresponde. `Downloads` solo admite
     * rutas bajo `Download/`; cualquier otra va por `Files`.
     */
    private fun collectionUri(collection: String): Uri =
        if (collection == DOCUMENTS) {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

    private fun directoryOf(collection: String): String =
        if (collection == DOCUMENTS) {
            Environment.DIRECTORY_DOCUMENTS
        } else {
            Environment.DIRECTORY_DOWNLOADS
        }

    // ── Android 9 y anteriores ────────────────────────────────────────────

    private fun legacyFolder(collection: String, folder: String): File =
        File(
            Environment.getExternalStoragePublicDirectory(directoryOf(collection)),
            folder
        )

    private fun createLegacy(
        name: String,
        collection: String,
        folderName: String
    ): Map<String, String> {
        val folder = legacyFolder(collection, folderName)
        if (!folder.exists() && !folder.mkdirs()) {
            throw IllegalStateException("no se pudo crear $folder")
        }

        var candidate = name
        var index = 2
        while (File(folder, candidate).exists() || File(folder, candidate + PART).exists()) {
            val dot = name.lastIndexOf('.')
            candidate = if (dot <= 0) "$name ($index)"
            else "${name.substring(0, dot)} ($index)${name.substring(dot)}"
            index++
        }

        val partial = File(folder, candidate + PART)
        val key = Uri.fromFile(File(folder, candidate)).toString()
        open[key] = partial.outputStream()
        legacy[key] = partial
        return mapOf("uri" to key, "name" to candidate)
    }

    private companion object {
        /// El mismo valor que `DestinationCollection.documents.wire` en Dart.
        const val DOCUMENTS = "documents"
        const val PART = ".part"
    }
}
