import 'dart:async';
import 'dart:typed_data';
import 'package:universal_ble/universal_ble.dart';

class BleTransport {
  static const service = '000000fe-0000-1000-8000-00805f9b34fb';
  static const writeCharacteristic = '000000f1-0000-1000-8000-00805f9b34fb';
  String? _deviceId;
  final _received = StreamController<Uint8List>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _values = <StreamSubscription<Uint8List>>[];
  StreamSubscription<bool>? _connections;
  int _maximumWrite = 20;
  int _epoch = 0;
  void _checkEpoch(int epoch) {
    if (epoch != _epoch) throw StateError('BLE 连接已取消');
  }

  Stream<Uint8List> get received => _received.stream;
  Stream<String> get errors => _errors.stream;

  Future<void> connect(String id) async {
    await disconnect();
    final epoch = ++_epoch;
    await UniversalBle.requestPermissions();
    _checkEpoch(epoch);
    _deviceId = id;
    try {
      await UniversalBle.connect(id, timeout: const Duration(seconds: 20));
      _checkEpoch(epoch);
      final services = await UniversalBle.discoverServices(id);
      _checkEpoch(epoch);
      final matches = services.where((s) => s.uuid.toLowerCase() == service);
      if (matches.isEmpty) throw StateError('设备没有 FE 控制服务，请检查协议或型号');
      final characteristics = matches.first.characteristics;
      final writers = characteristics.where(
        (c) => c.uuid.toLowerCase() == writeCharacteristic,
      );
      if (writers.isEmpty ||
          !writers.first.properties.contains(CharacteristicProperty.write)) {
        throw StateError('设备没有支持响应写入的 F1 特征');
      }
      _connections = UniversalBle.connectionStream(id).listen((connected) {
        if (!connected) _errors.add('蓝牙连接已断开');
      });
      var subscribed = 0;
      for (final characteristic in characteristics) {
        if (characteristic.properties.contains(CharacteristicProperty.notify)) {
          _values.add(
            UniversalBle.characteristicValueStream(
              id,
              characteristic.uuid,
            ).listen(
              _received.add,
              onError: (Object error) => _errors.add('$error'),
            ),
          );
          await UniversalBle.subscribeNotifications(
            id,
            service,
            characteristic.uuid,
          );
          _checkEpoch(epoch);
          subscribed++;
        }
      }
      if (subscribed == 0) throw StateError('FE 服务没有可订阅的通知特征');
      try {
        final mtu = await UniversalBle.requestMtu(id, 128);
        _maximumWrite = mtu > 23 ? mtu - 3 : 20;
      } catch (_) {
        _maximumWrite = 20;
      }
    } catch (_) {
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
      if (epoch == _epoch) await disconnect();
      rethrow;
    }
  }

  Future<void> write(Uint8List data) async {
    final id = _deviceId;
    if (id == null) throw StateError('尚未连接');
    if (data.length > _maximumWrite) {
      throw StateError(
        '当前 MTU 仅允许 $_maximumWrite 字节，命令有 ${data.length} 字节；不猜测设备分包规则',
      );
    }
    await UniversalBle.write(
      id,
      service,
      writeCharacteristic,
      data,
      timeout: const Duration(seconds: 4),
    );
  }

  Future<void> disconnect() async {
    _epoch++;
    final id = _deviceId;
    _deviceId = null;
    for (final subscription in _values) {
      await subscription.cancel();
    }
    _values.clear();
    await _connections?.cancel();
    _connections = null;
    if (id != null) {
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
    }
  }
}
