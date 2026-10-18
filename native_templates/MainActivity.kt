package dev.sibyl.control

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Copy to android/app/src/main/kotlin/dev/sibyl/control/MainActivity.kt.
 * Change package if the generated application uses a different namespace.
 * Requests no permissions itself: the app's BLE permission flow must request
 * BLUETOOTH_CONNECT on API 31+, and legacy Bluetooth permissions on older APIs.
 * No discovery is performed; this is Classic Bluetooth, not GATT.
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newFixedThreadPool(3)
    private val reader = Executors.newSingleThreadExecutor()
    private val deadlines = Executors.newScheduledThreadPool(2)
    private val lock = Any()
    private var socket: BluetoothSocket? = null
    private var generation = 0L
    private var connecting = false
    private var connected = false
    private var writing = false
    private var destroyed = false
    private var sink: EventChannel.EventSink? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private val uuids = listOf(
        UUID.fromString("6A24EEAB-4B65-4693-986B-3C26C352264F"),
        UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methods = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.sibyl.control/rfcomm")
        events = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.sibyl.control/rfcomm_rx")
        events!!.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                sink = eventSink
            }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        methods!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> connect(call, Reply(result))
                "write" -> write(call, Reply(result))
                "disconnect" -> disconnect(Reply(result))
                else -> result.notImplemented()
            }
        }
    }

    // Result objects are completed once, and always on Flutter's platform thread.
    private inner class Reply(private val result: MethodChannel.Result) {
        private val done = AtomicBoolean(false)
        fun ok() {
            if (done.compareAndSet(false, true)) main.post { result.success(null) }
        }
        fun error(code: String, message: String) {
            if (done.compareAndSet(false, true)) main.post { result.error(code, message, null) }
        }
    }

    private fun emit(value: Any, epoch: Long? = null) {
        main.post {
            if (!destroyed && (epoch == null || synchronized(lock) { generation == epoch })) {
                sink?.success(value)
            }
        }
    }

    private fun checkBluetooth() {
        val permission = if (Build.VERSION.SDK_INT >= 31) Manifest.permission.BLUETOOTH_CONNECT
            else Manifest.permission.BLUETOOTH
        if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            throw SecurityException("$permission not granted; request permissions through the app Bluetooth permission flow first")
        }
        val adapter = getSystemService(BluetoothManager::class.java)?.adapter
            ?: throw IOException("This device has no Bluetooth adapter")
        if (!adapter.isEnabled) throw IOException("Bluetooth is disabled; enable it before connecting")
    }

    private fun connect(call: MethodCall, reply: Reply) {
        val address = call.argument<String>("address")
        if (address == null || !Regex("^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$").matches(address)) {
            reply.error("INVALID_ADDRESS", "Expected AA:BB:CC:DD:EE:FF")
            return
        }
        if (call.argument<Any>("channel") != null) {
            reply.error("UNSUPPORTED_CHANNEL", "Android public RFCOMM supports UUID SDP only; omit channel")
            return
        }
        val epoch: Long
        synchronized(lock) {
            if (destroyed || connecting || connected) {
                reply.error("INVALID_STATE", "Already connecting, connected, or destroyed")
                return
            }
            epoch = ++generation
            connecting = true
        }
        io.execute {
            val failures = mutableListOf<String>()
            try {
                checkBluetooth()
                val adapter = getSystemService(BluetoothManager::class.java)!!.adapter!!
                val device = adapter.getRemoteDevice(address)
                for (uuid in uuids) {
                    synchronized(lock) {
                        if (epoch != generation || destroyed) throw IOException("Connection cancelled")
                    }
                    // Both attempts are secure RFCOMM; no hidden APIs, guessed
                    // channels or insecure sockets. The second UUID is standard SPP.
                    val candidate = device.createRfcommSocketToServiceRecord(uuid)
                    synchronized(lock) {
                        if (epoch != generation || destroyed) {
                            candidate.close()
                            throw IOException("Connection cancelled")
                        }
                        socket = candidate
                    }
                    val attemptDone = AtomicBoolean(false)
                    val timer = deadlines.schedule({
                        if (attemptDone.compareAndSet(false, true)) {
                            try { candidate.close() } catch (_: IOException) { }
                        }
                    }, 12, TimeUnit.SECONDS)
                    try {
                        candidate.connect()
                        if (!attemptDone.compareAndSet(false, true)) {
                            throw IOException("RFCOMM connect timed out after 12 seconds")
                        }
                        timer.cancel(false)
                        synchronized(lock) {
                            if (epoch != generation || destroyed) {
                                throw IOException("Connection cancelled or timed out")
                            }
                            if (!candidate.isConnected) throw IOException("RFCOMM socket did not connect")
                            connected = true
                            connecting = false
                        }
                        reply.ok()
                        startReader(candidate, epoch)
                        return@execute
                    } catch (e: Exception) {
                        timer.cancel(false)
                        try { candidate.close() } catch (_: IOException) { }
                        synchronized(lock) { if (socket === candidate) socket = null }
                        failures.add("$uuid: ${e.message ?: e.javaClass.simpleName}")
                    }
                }
                throw IOException("RTK UUID and SPP connection attempts failed: ${failures.joinToString("; ")}")
            } catch (e: Exception) {
                fail(epoch, "RFCOMM connect: ${e.message}")
                reply.error(if (e is SecurityException) "BLUETOOTH_PERMISSION" else "CONNECT_FAILED", e.message ?: "RFCOMM connect failed")
            } finally {
                synchronized(lock) { if (generation == epoch) connecting = false }
            }
        }
    }

    private fun startReader(active: BluetoothSocket, epoch: Long) {
        reader.execute {
            try {
                val input = active.inputStream
                val buffer = ByteArray(4096)
                while (synchronized(lock) { epoch == generation && connected && socket === active }) {
                    val count = input.read(buffer) // Blocking only on dedicated reader.
                    if (count < 0) throw IOException("Remote RFCOMM endpoint disconnected (EOF)")
                    if (count > 0) emit(buffer.copyOf(count), epoch)
                }
            } catch (e: Exception) {
                fail(epoch, "RFCOMM receive: ${e.message}")
            }
        }
    }

    private fun write(call: MethodCall, reply: Reply) {
        val bytes = call.arguments as? ByteArray
        if (bytes == null || bytes.size > 1024 * 1024) {
            reply.error("INVALID_DATA", "Expected Uint8List of at most 1 MiB")
            return
        }
        val active: BluetoothSocket
        val epoch: Long
        synchronized(lock) {
            if (!connected || socket == null || destroyed || writing) {
                reply.error("INVALID_STATE", "Not connected or another write is pending; await writes sequentially")
                return
            }
            active = socket!!
            epoch = generation
            writing = true
        }
        io.execute {
            val writeDone = AtomicBoolean(false)
            val timer = deadlines.schedule({
                if (writeDone.compareAndSet(false, true)) {
                    fail(epoch, "RFCOMM write timed out after 10 seconds")
                    reply.error("WRITE_TIMEOUT", "RFCOMM write timed out after 10 seconds")
                }
            }, 10, TimeUnit.SECONDS)
            try {
                checkBluetooth()
                val output = active.outputStream
                output.write(bytes)
                output.flush()
                if (!writeDone.compareAndSet(false, true)) throw IOException("RFCOMM write timed out")
                timer.cancel(false)
                synchronized(lock) {
                    if (generation != epoch || !connected) throw IOException("Disconnected during write")
                }
                reply.ok()
            } catch (e: Exception) {
                fail(epoch, "RFCOMM write: ${e.message}")
                reply.error("WRITE_FAILED", e.message ?: "RFCOMM write failed")
            } finally {
                timer.cancel(false)
                synchronized(lock) { if (generation == epoch) writing = false }
            }
        }
    }

    private fun fail(epoch: Long, message: String) {
        val old: BluetoothSocket?
        synchronized(lock) {
            if (generation != epoch) return
            ++generation
            old = socket
            socket = null
            connecting = false
            connected = false
            writing = false
        }
        try { old?.close() } catch (_: IOException) { }
        emit(mapOf("type" to "error", "message" to message), epoch + 1)
        emit(mapOf("type" to "disconnected"), epoch + 1)
    }

    private fun disconnect(reply: Reply) {
        val old: BluetoothSocket?
        val epoch: Long
        synchronized(lock) {
            epoch = ++generation
            old = socket
            socket = null
            connecting = false
            connected = false
            writing = false
        }
        // close() interrupts BluetoothSocket.connect/read/write; never queue it
        // behind the blocked reader or connector, and never close on UI thread.
        io.execute {
            try {
                old?.close()
                emit(mapOf("type" to "disconnected"), epoch)
                reply.ok()
            } catch (e: Exception) {
                reply.error("DISCONNECT_FAILED", e.message ?: "RFCOMM close failed")
            }
        }
    }

    override fun onDestroy() {
        val old: BluetoothSocket?
        synchronized(lock) {
            destroyed = true
            ++generation
            old = socket
            socket = null
            connecting = false
            connected = false
            writing = false
        }
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        sink = null
        // Enqueue closing before shutting down; shutdown permits queued cleanup.
        io.execute { try { old?.close() } catch (_: IOException) { } }
        io.shutdown()
        reader.shutdown()
        deadlines.shutdown()
        super.onDestroy()
    }
}
