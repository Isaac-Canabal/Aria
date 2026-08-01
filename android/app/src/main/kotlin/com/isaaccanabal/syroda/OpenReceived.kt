package com.isaaccanabal.syroda

import android.app.DownloadManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.FileNotFoundException

/**
 * Abre lo recibido con la aplicacion que le corresponda.
 *
 * El historial guarda el `content://`, no el archivo: la persona puede
 * haberlo borrado desde Archivos y el uri seguir ahi. Por eso "ya no esta" y
 * "no hay con que abrirlo" se distinguen — son problemas distintos y lo que
 * puede hacer la persona tambien.
 */
class OpenReceived(private val context: Context) {

    /** Los mismos codigos que espera `OpenOutcome` en Dart. */
    private companion object {
        const val OPENED = "opened"
        const val MISSING = "missing"
        const val NO_HANDLER = "noHandler"
        const val FAILED = "failed"
    }

    fun open(target: String): String {
        val uri = Uri.parse(target)
        if (!exists(uri)) return MISSING

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, context.contentResolver.getType(uri) ?: "*/*")
            // El uri viene de MediaStore, asi que se puede conceder lectura
            // sin FileProvider: quien lo abra lo lee mientras dure la tarea.
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            context.startActivity(intent)
            OPENED
        } catch (e: ActivityNotFoundException) {
            NO_HANDLER
        } catch (e: SecurityException) {
            FAILED
        }
    }

    /**
     * Abre la pantalla de Descargas del sistema.
     *
     * No se pasa un `file://` de la subcarpeta: meter uno en un Intent lanza
     * `FileUriExposedException` desde API 24, y esta app arranca en la 24.
     * Android tampoco tiene forma fiable de abrir una subcarpeta concreta, asi
     * que se abre Descargas, que es donde esta, en vez de fingir una precision
     * que no existe.
     */
    fun openFolder(): String {
        val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            OPENED
        } catch (e: ActivityNotFoundException) {
            // Sin app de archivos no hay nada que abrir. No es un fallo de la
            // transferencia y no se presenta como tal.
            NO_HANDLER
        }
    }

    /**
     * Que el uri siga resolviendo a algo. Un `query` vacio significa que la
     * fila se borro; `FileNotFoundException` al abrirlo, que la fila esta
     * pero el archivo no.
     */
    private fun exists(uri: Uri): Boolean = try {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            cursor.count > 0
        } ?: fileStillThere(uri)
    } catch (e: Exception) {
        false
    }

    private fun fileStillThere(uri: Uri): Boolean = try {
        context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { true } ?: false
    } catch (e: FileNotFoundException) {
        false
    } catch (e: SecurityException) {
        false
    }
}
