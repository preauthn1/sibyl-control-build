import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

const _rtkUuid = '6a24eeab-4b65-4693-986b-3c26c352264f';
const _sppUuid = '00001101-0000-1000-8000-00805f9b34fb';
const _connectLimit = Duration(seconds: 25);
const _writeLimit = Duration(seconds: 10);

/// Classic Bluetooth RFCOMM, not BLE/GATT. One connection per instance.
///
/// Linux requires BlueZ's sdptool when [connect] is called without a channel.
/// Android permissions must already have been requested by the application's
/// Bluetooth permission flow. Android's public API uses UUID SDP, not channels.
/// Desktop native handles and all native calls live in a dedicated isolate.
class RfcommTransport {
  static const _methods = MethodChannel('dev.sibyl.control/rfcomm');
  static const _events = EventChannel('dev.sibyl.control/rfcomm_rx');
  final _received = StreamController<Uint8List>.broadcast();
  final _errors = StreamController<String>.broadcast();
  Stream<Uint8List> get received => _received.stream;
  Stream<String> get errors => _errors.stream;

  StreamSubscription<dynamic>? _androidEvents;
  ReceivePort? _inbox;
  Isolate? _worker;
  SendPort? _commands;
  Future<void>? _starting;
  final _pending = <int, Completer<void>>{};
  int _sequence = 0;
  bool _connected = false;
  bool _connecting = false;
  bool _disposed = false;
  int _epoch = 0;

  Future<void> connect(String address, {int? channel}) async {
    _checkAlive();
    if (!RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(address)) {
      throw ArgumentError.value(
        address,
        'address',
        'Expected AA:BB:CC:DD:EE:FF',
      );
    }
    if (channel != null && (channel < 1 || channel > 30)) {
      throw RangeError.range(channel, 1, 30, 'channel');
    }
    if (_connecting || _connected) {
      throw StateError(
        'RFCOMM is already connecting or connected; disconnect first',
      );
    }
    if (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux) {
      throw UnsupportedError('RFCOMM supports Android, Windows and Linux only');
    }
    if (Platform.isAndroid && channel != null) {
      throw UnsupportedError(
        'Android public RFCOMM API supports UUID SDP only; omit channel',
      );
    }
    _connecting = true;
    final epoch = ++_epoch;
    try {
      if (Platform.isAndroid) {
        _androidEvents ??= _events.receiveBroadcastStream().listen(
          (dynamic e) {
            if (e is Uint8List) {
              _received.add(e);
            } else if (e is Map && e['type'] == 'error') {
              _connected = false;
              _errors.add('${e['message']}');
            } else if (e is Map && e['type'] == 'disconnected') {
              _connected = false;
            }
          },
          onError: (Object error) {
            _connected = false;
            _errors.add('Android RFCOMM event stream: $error');
          },
        );
        await _methods.invokeMethod<void>('connect', {'address': address});
      } else {
        await _startWorker();
        if (epoch != _epoch) throw StateError('RFCOMM connect cancelled');
        await _request('connect', {'address': address, 'channel': channel});
      }
      if (epoch != _epoch) throw StateError('RFCOMM connect cancelled');
      _connected = true;
    } catch (error) {
      _errors.add('RFCOMM connect: $error');
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  Future<void> write(Uint8List bytes) async {
    _checkAlive();
    if (!_connected) throw StateError('RFCOMM is not connected');
    if (bytes.length > 1024 * 1024) {
      throw ArgumentError('RFCOMM write exceeds the 1 MiB queue limit');
    }
    if (bytes.isEmpty) return;
    try {
      if (Platform.isAndroid) {
        await _methods.invokeMethod<void>('write', Uint8List.fromList(bytes));
      } else {
        await _request('write', {'bytes': Uint8List.fromList(bytes)});
      }
    } catch (error) {
      _errors.add('RFCOMM write: $error');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    ++_epoch;
    _connected = false;
    if (Platform.isAndroid) {
      await _methods.invokeMethod<void>('disconnect');
    } else {
      await _starting;
      if (_commands != null) await _request('disconnect', const {});
    }
  }

  /// Closes native resources, worker ports and broadcast streams permanently.
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    await _androidEvents?.cancel();
    if (_commands != null) await _request('dispose', const {});
    _worker?.kill(priority: Isolate.immediate);
    _inbox?.close();
    await _received.close();
    await _errors.close();
  }

  void _checkAlive() {
    if (_disposed) throw StateError('RFCOMM transport has been disposed');
  }

  Future<void> _startWorker() => _starting ??= _spawnWorker();

  Future<void> _spawnWorker() async {
    final ready = Completer<void>();
    final inbox = ReceivePort();
    _inbox = inbox;
    inbox.listen((dynamic message) {
      if (message is SendPort) {
        _commands = message;
        ready.complete();
      } else if (message is Map) {
        if (message['type'] == 'data') {
          _received.add(message['bytes'] as Uint8List);
        } else if (message['type'] == 'error') {
          _connected = false;
          _errors.add('${message['error']}');
        } else if (message['type'] == 'reply') {
          final pending = _pending.remove(message['id']);
          if (message['error'] != null) {
            pending?.completeError(StateError('${message['error']}'));
          } else {
            pending?.complete();
          }
        }
      } else {
        final error = StateError('RFCOMM native worker terminated: $message');
        _connected = false;
        if (!ready.isCompleted) ready.completeError(error);
        for (final pending in _pending.values) {
          pending.completeError(error);
        }
        _pending.clear();
        if (!_disposed) _errors.add('$error');
      }
    });
    _worker = await Isolate.spawn(
      _desktopMain,
      inbox.sendPort,
      onError: inbox.sendPort,
      onExit: inbox.sendPort,
      errorsAreFatal: true,
    );
    await ready.future;
  }

  Future<void> _request(String op, Map<String, Object?> args) {
    final id = ++_sequence;
    final done = Completer<void>();
    _pending[id] = done;
    _commands!.send({'id': id, 'op': op, ...args});
    return done.future;
  }
}

void _desktopMain(SendPort out) {
  final inbox = ReceivePort();
  final session = _DesktopSession(out);
  out.send(inbox.sendPort);
  inbox.listen((dynamic raw) async {
    final m = raw as Map;
    String? error;
    try {
      switch (m['op']) {
        case 'connect':
          await session.connect(m['address'] as String, m['channel'] as int?);
          break;
        case 'write':
          await session.write(m['bytes'] as Uint8List);
          break;
        case 'disconnect':
        case 'dispose':
          session.disconnect();
          break;
        default:
          throw ArgumentError('Unknown RFCOMM operation ${m['op']}');
      }
    } catch (e) {
      error = '$e';
    }
    out.send({'type': 'reply', 'id': m['id'], 'error': error});
    if (m['op'] == 'dispose') inbox.close();
  });
}

class _DesktopSession {
  _DesktopSession(this.out);
  final SendPort out;
  _NativeSocket? _socket;
  Timer? _reader;
  int _generation = 0;
  bool _connecting = false;
  bool _writing = false;
  Process? _sdp;

  Future<void> connect(String address, int? channel) async {
    if (_connecting || _socket != null) throw StateError('Already open');
    _connecting = true;
    final generation = ++_generation;
    final deadline = DateTime.now().add(_connectLimit);
    try {
      final List<Map<String, Object?>> candidates;
      if (Platform.isLinux && channel == null) {
        final channels = await _discoverChannels(address, deadline);
        candidates = channels
            .map((c) => <String, Object?>{'channel': c, 'uuid': null})
            .toList();
      } else if (channel != null) {
        candidates = [
          {'channel': channel, 'uuid': null},
        ];
      } else {
        candidates = [
          {'channel': null, 'uuid': _rtkUuid},
          {'channel': null, 'uuid': _sppUuid},
        ];
      }
      Object? lastError;
      for (final candidate in candidates) {
        if (generation != _generation) throw StateError('Connect cancelled');
        if (DateTime.now().isAfter(deadline))
          throw TimeoutException('RFCOMM connect deadline');
        final socket = _NativeSocket();
        _socket = socket;
        try {
          final remainingMs = deadline
              .difference(DateTime.now())
              .inMilliseconds;
          final perAttemptMs = remainingMs ~/ candidates.length;
          final attemptDeadline = DateTime.now().add(
            Duration(milliseconds: perAttemptMs < 12000 ? perAttemptMs : 12000),
          );
          await socket.connect(
            address,
            candidate['channel'] as int?,
            candidate['uuid'] as String?,
            attemptDeadline.isBefore(deadline) ? attemptDeadline : deadline,
          );
          if (generation != _generation) throw StateError('Connect cancelled');
          _reader = Timer.periodic(const Duration(milliseconds: 15), (_) {
            try {
              // Bound each tick so control commands cannot starve under load.
              for (var i = 0; i < 8; i++) {
                final bytes = socket.read();
                if (bytes == null) break;
                out.send({'type': 'data', 'bytes': bytes});
              }
            } catch (error) {
              disconnect();
              out.send({'type': 'error', 'error': 'RFCOMM receive: $error'});
            }
          });
          return;
        } catch (error) {
          lastError = error;
          socket.close();
          if (identical(_socket, socket)) _socket = null;
        }
      }
      throw StateError('RFCOMM connect failed (RTK UUID then SPP): $lastError');
    } finally {
      _connecting = false;
    }
  }

  Future<List<int>> _discoverChannels(String address, DateTime deadline) async {
    final generation = _generation;
    final Process process;
    try {
      process = await Process.start('sdptool', ['browse', '--xml', address]);
    } on ProcessException catch (e) {
      throw StateError(
        'Install BlueZ sdptool or provide an explicit RFCOMM channel: $e',
      );
    }
    if (generation != _generation) {
      process.kill(ProcessSignal.sigkill);
      throw StateError('SDP discovery cancelled');
    }
    _sdp = process;
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    var size = 0;
    final output = StringBuffer();
    final stderr = StringBuffer();
    final subscriptions = <StreamSubscription<List<int>>>[
      process.stdout.listen(
        (bytes) {
          size += bytes.length;
          if (size <= 1024 * 1024) {
            output.write(utf8.decode(bytes, allowMalformed: true));
          } else {
            process.kill(ProcessSignal.sigkill);
          }
        },
        onDone: stdoutDone.complete,
        onError: (Object e) {
          if (!stdoutDone.isCompleted) stdoutDone.completeError(e);
        },
      ),
      process.stderr.listen(
        (bytes) {
          if (stderr.length < 8192)
            stderr.write(utf8.decode(bytes, allowMalformed: true));
        },
        onDone: stderrDone.complete,
        onError: (Object e) {
          if (!stderrDone.isCompleted) stderrDone.completeError(e);
        },
      ),
    ];
    try {
      final remaining = deadline.difference(DateTime.now());
      final limit = remaining < const Duration(seconds: 10)
          ? remaining
          : const Duration(seconds: 10);
      final exit = await process.exitCode.timeout(limit);
      // exitCode does not guarantee that stdout has delivered all buffered data.
      await Future.wait([
        stdoutDone.future,
        stderrDone.future,
      ]).timeout(const Duration(seconds: 1));
      if (exit != 0 || size > 1024 * 1024) {
        throw StateError('sdptool browse failed ($exit): $stderr');
      }
      final records = RegExp(
        r'<record\b[^>]*>([\s\S]*?)</record>',
        caseSensitive: false,
      ).allMatches(output.toString()).map((m) => m.group(1)!).toList();
      final channels = <int>[];
      for (final uuid in [_rtkUuid, _sppUuid]) {
        for (final record in records) {
          final classes =
              RegExp(
                r'<attribute\s+id="0x0001"[^>]*>([\s\S]*?)</attribute>',
                caseSensitive: false,
              ).firstMatch(record)?.group(1)?.toLowerCase() ??
              '';
          final matches =
              classes.contains(uuid) ||
              (uuid == _sppUuid &&
                  RegExp(r'value="(?:0x)?1101"').hasMatch(classes));
          if (!matches) continue;
          final protocols =
              RegExp(
                r'<attribute\s+id="0x0004"[^>]*>([\s\S]*?)</attribute>',
                caseSensitive: false,
              ).firstMatch(record)?.group(1) ??
              '';
          // RFCOMM UUID must precede its uint8 channel in the same sequence.
          final match = RegExp(
            r'<uuid\s+value="(?:0x0003|0x3|00000003-0000-1000-8000-00805f9b34fb)"\s*/>\s*<uint8\s+value="(0x[0-9a-f]+|[0-9]+)"',
            caseSensitive: false,
          ).firstMatch(protocols);
          final value = match?.group(1);
          final found = value == null ? null : int.tryParse(value);
          if (found != null &&
              found >= 1 &&
              found <= 30 &&
              !channels.contains(found)) {
            channels.add(found);
          }
        }
      }
      if (channels.isNotEmpty) return channels;
      throw StateError(
        'No RTK/SPP RFCOMM channel in SDP; provide channel explicitly (1..30)',
      );
    } on ProcessException catch (e) {
      throw StateError(
        'Install BlueZ sdptool or provide an explicit RFCOMM channel: $e',
      );
    } finally {
      process.kill(ProcessSignal.sigkill);
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      if (identical(_sdp, process)) _sdp = null;
    }
  }

  Future<void> write(Uint8List bytes) async {
    if (_writing)
      throw StateError('A RFCOMM write is already pending; await it first');
    final socket = _socket;
    if (socket == null || _connecting)
      throw StateError('RFCOMM is not connected');
    _writing = true;
    final deadline = DateTime.now().add(_writeLimit);
    try {
      var offset = 0;
      while (offset < bytes.length) {
        if (!identical(socket, _socket))
          throw StateError('Disconnected during write');
        if (DateTime.now().isAfter(deadline))
          throw TimeoutException('RFCOMM write deadline');
        offset += socket.send(bytes, offset);
        if (offset < bytes.length)
          await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    } catch (_) {
      disconnect();
      rethrow;
    } finally {
      _writing = false;
    }
  }

  void disconnect() {
    ++_generation;
    _sdp?.kill(ProcessSignal.sigkill);
    _reader?.cancel();
    _reader = null;
    _socket?.close();
    _socket = null;
  }
}

// Windows headers ws2bth.h include pshpack1.h: SOCKADDR_BTH is PACKED,
// size 30 on both x86/x64: family@0, BTH_ADDR@2, GUID@10, ULONG port@26.
// Do not model this as a naturally aligned FFI Struct (which would be 40 bytes).
// Linux sockaddr_rc is 10 bytes: family@0, reversed bdaddr@2, channel@8.
class _NativeSocket {
  _NativeSocket() {
    if (_windows) {
      final data = calloc<Uint8>(512);
      try {
        final startup = _lib
            .lookupFunction<
              Int32 Function(Uint16, Pointer<Uint8>),
              int Function(int, Pointer<Uint8>)
            >('WSAStartup')(0x0202, data);
        if (startup != 0) throw StateError('WSAStartup error $startup');
        _wsa = true;
      } finally {
        calloc.free(data);
      }
    }
    try {
      _fd = _windows
          ? _lib.lookupFunction<
              UintPtr Function(Int32, Int32, Int32),
              int Function(int, int, int)
            >('socket')(32, 1, 3)
          : _lib.lookupFunction<
              Int32 Function(Int32, Int32, Int32),
              int Function(int, int, int)
            >('socket')(31, 1, 3);
      if (_fd == -1 ||
          (_windows &&
              _fd ==
                  (sizeOf<IntPtr>() == 8 ? 0xffffffffffffffff : 0xffffffff))) {
        _fd = -1;
        throw StateError('RFCOMM socket creation error ${_errno()}');
      }
      if (_windows) {
        final mode = calloc<Uint32>()..value = 1;
        try {
          final result = _lib
              .lookupFunction<
                Int32 Function(UintPtr, Int32, Pointer<Uint32>),
                int Function(int, int, Pointer<Uint32>)
              >('ioctlsocket')(_fd, 0x8004667e, mode);
          if (result != 0) throw StateError('FIONBIO error ${_errno()}');
        } finally {
          calloc.free(mode);
        }
      } else {
        // ioctl(FIONBIO) avoids variadic fcntl ABI differences.
        final mode = calloc<Int32>()..value = 1;
        try {
          final result = _lib
              .lookupFunction<
                Int32 Function(Int32, UintPtr, Pointer<Int32>),
                int Function(int, int, Pointer<Int32>)
              >('ioctl')(_fd, 0x5421, mode);
          if (result != 0) throw StateError('FIONBIO error ${_errno()}');
        } finally {
          calloc.free(mode);
        }
      }
    } catch (_) {
      close();
      rethrow;
    }
  }

  static final bool _windows = Platform.isWindows;
  static final DynamicLibrary _lib = DynamicLibrary.open(
    _windows ? 'ws2_32.dll' : 'libc.so.6',
  );
  int _fd = -1;
  bool _wsa = false;
  bool _closed = false;

  int _errno() => _windows
      ? _lib.lookupFunction<Int32 Function(), int Function()>(
          'WSAGetLastError',
        )()
      : _lib
            .lookupFunction<
              Pointer<Int32> Function(),
              Pointer<Int32> Function()
            >('__errno_location')()
            .value;
  bool _wouldBlock(int e) => _windows ? e == 10035 : e == 11 || e == 4;

  Future<void> connect(
    String address,
    int? channel,
    String? uuid,
    DateTime deadline,
  ) async {
    final length = _windows ? 30 : 10;
    final addr = calloc<Uint8>(length);
    try {
      final bytes = addr.asTypedList(length);
      final data = ByteData.sublistView(bytes);
      data.setUint16(0, _windows ? 32 : 31, Endian.host);
      final parts = address
          .split(':')
          .map((v) => int.parse(v, radix: 16))
          .toList();
      if (_windows) {
        data.setUint64(
          2,
          int.parse(
            parts.map((v) => v.toRadixString(16).padLeft(2, '0')).join(),
            radix: 16,
          ),
          Endian.little,
        );
        if (uuid != null) {
          final hex = uuid.replaceAll('-', '');
          data.setUint32(
            10,
            int.parse(hex.substring(0, 8), radix: 16),
            Endian.little,
          );
          data.setUint16(
            14,
            int.parse(hex.substring(8, 12), radix: 16),
            Endian.little,
          );
          data.setUint16(
            16,
            int.parse(hex.substring(12, 16), radix: 16),
            Endian.little,
          );
          for (var i = 0; i < 8; i++) {
            bytes[18 + i] = int.parse(
              hex.substring(16 + i * 2, 18 + i * 2),
              radix: 16,
            );
          }
        }
        // 0 lets Winsock resolve serviceClassId via SDP; never guess channel 1.
        data.setUint32(26, channel ?? 0, Endian.little);
      } else {
        if (channel == null)
          throw StateError(
            'Linux requires an SDP-resolved or explicit channel',
          );
        bytes.setRange(2, 8, parts.reversed);
        bytes[8] = channel;
      }
      final result = _windows
          ? _lib.lookupFunction<
              Int32 Function(UintPtr, Pointer<Uint8>, Int32),
              int Function(int, Pointer<Uint8>, int)
            >('connect')(_fd, addr, length)
          : _lib.lookupFunction<
              Int32 Function(Int32, Pointer<Uint8>, Uint32),
              int Function(int, Pointer<Uint8>, int)
            >('connect')(_fd, addr, length);
      if (result == 0) return;
      final error = _errno();
      if (!(_windows
          ? error == 10035 || error == 10036 || error == 10037
          : error == 115 || error == 114 || error == 4)) {
        throw StateError('connect native error $error');
      }
      while (!_closed && DateTime.now().isBefore(deadline)) {
        if (_isWritable()) {
          final value = calloc<Int32>();
          final size = calloc<Int32>()..value = 4;
          try {
            final rc = _windows
                ? _lib.lookupFunction<
                    Int32 Function(
                      UintPtr,
                      Int32,
                      Int32,
                      Pointer<Int32>,
                      Pointer<Int32>,
                    ),
                    int Function(int, int, int, Pointer<Int32>, Pointer<Int32>)
                  >('getsockopt')(_fd, 0xffff, 0x1007, value, size)
                : _lib.lookupFunction<
                    Int32 Function(
                      Int32,
                      Int32,
                      Int32,
                      Pointer<Int32>,
                      Pointer<Int32>,
                    ),
                    int Function(int, int, int, Pointer<Int32>, Pointer<Int32>)
                  >('getsockopt')(_fd, 1, 4, value, size);
            if (rc != 0 || value.value != 0)
              throw StateError(
                'connect SO_ERROR ${rc != 0 ? _errno() : value.value}',
              );
            return;
          } finally {
            calloc.free(value);
            calloc.free(size);
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      if (_closed) throw StateError('Connect cancelled');
      throw TimeoutException('RFCOMM connect deadline');
    } finally {
      calloc.free(addr);
    }
  }

  bool _isWritable() {
    // WSAPOLLFD: SOCKET@0, SHORT events@pointerSize, SHORT revents@+2.
    // Linux pollfd: int fd@0, short events@4, short revents@6.
    final offset = _windows ? sizeOf<IntPtr>() : 4;
    final memory = calloc<Uint8>(_windows && offset == 8 ? 16 : 8);
    try {
      final data = ByteData.sublistView(
        memory.asTypedList(_windows && offset == 8 ? 16 : 8),
      );
      if (offset == 8) {
        data.setUint64(0, _fd, Endian.host);
      } else {
        data.setInt32(0, _fd, Endian.host);
      }
      data.setInt16(offset, _windows ? 0x10 : 0x4, Endian.host);
      final result = _windows
          ? _lib.lookupFunction<
              Int32 Function(Pointer<Uint8>, Uint32, Int32),
              int Function(Pointer<Uint8>, int, int)
            >('WSAPoll')(memory, 1, 0)
          : _lib.lookupFunction<
              Int32 Function(Pointer<Uint8>, UintPtr, Int32),
              int Function(Pointer<Uint8>, int, int)
            >('poll')(memory, 1, 0);
      if (result < 0) throw StateError('RFCOMM poll error ${_errno()}');
      return result > 0 && data.getInt16(offset + 2, Endian.host) != 0;
    } finally {
      calloc.free(memory);
    }
  }

  Uint8List? read() {
    if (_closed) throw StateError('Socket closed');
    final buffer = calloc<Uint8>(4096);
    try {
      final n = _windows
          ? _lib.lookupFunction<
              Int32 Function(UintPtr, Pointer<Uint8>, Int32, Int32),
              int Function(int, Pointer<Uint8>, int, int)
            >('recv')(_fd, buffer, 4096, 0)
          : _lib.lookupFunction<
              IntPtr Function(Int32, Pointer<Uint8>, UintPtr, Int32),
              int Function(int, Pointer<Uint8>, int, int)
            >('recv')(_fd, buffer, 4096, 0);
      if (n == 0) throw StateError('Remote RFCOMM endpoint disconnected (EOF)');
      if (n < 0) {
        final error = _errno();
        if (_wouldBlock(error)) return null;
        throw StateError('recv native error $error');
      }
      return Uint8List.fromList(buffer.asTypedList(n));
    } finally {
      calloc.free(buffer);
    }
  }

  int send(Uint8List bytes, int offset) {
    if (_closed) throw StateError('Socket closed');
    final remaining = bytes.length - offset;
    final length = remaining < 16384 ? remaining : 16384;
    final buffer = calloc<Uint8>(length);
    try {
      buffer.asTypedList(length).setRange(0, length, bytes, offset);
      final n = _windows
          ? _lib.lookupFunction<
              Int32 Function(UintPtr, Pointer<Uint8>, Int32, Int32),
              int Function(int, Pointer<Uint8>, int, int)
            >('send')(_fd, buffer, length, 0)
          : _lib.lookupFunction<
              IntPtr Function(Int32, Pointer<Uint8>, UintPtr, Int32),
              int Function(int, Pointer<Uint8>, int, int)
            >('send')(_fd, buffer, length, 0x4000); // MSG_NOSIGNAL
      if (n < 0) {
        final error = _errno();
        if (_wouldBlock(error)) return 0;
        throw StateError('send native error $error');
      }
      if (n == 0) throw StateError('RFCOMM send returned zero');
      return n;
    } finally {
      calloc.free(buffer);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_fd != -1) {
      if (_windows) {
        _lib.lookupFunction<Int32 Function(UintPtr), int Function(int)>(
          'closesocket',
        )(_fd);
      } else {
        _lib.lookupFunction<Int32 Function(Int32), int Function(int)>('close')(
          _fd,
        );
      }
      _fd = -1;
    }
    if (_wsa) {
      _lib.lookupFunction<Int32 Function(), int Function()>('WSACleanup')();
      _wsa = false;
    }
  }
}
