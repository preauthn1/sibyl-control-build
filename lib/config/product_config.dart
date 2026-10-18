/// Static-recovered product configuration only. Importing/constructing this
/// library performs no network or Bluetooth activity. See API.md for evidence.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _host = 'sibyl.linkcos.cn';
const _listPath = '/app/promodel/list';
const _panelPath = '/app/func/controlpanel';
const _maxBytes = 2 * 1024 * 1024;

/// No authentication, login, telemetry, OTA, image downloads or device I/O.
/// Each request owns a short-lived client, including on timeout/error.
class ProductConfigClient {
  final Duration timeout;
  ProductConfigClient({this.timeout = const Duration(seconds: 15)}) {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 60)) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Expected 0 < timeout <= 60s',
      );
    }
  }

  /// Only invoke from an explicit user action. Both requests are GETs.
  /// Unknown/ambiguous product IDs fail closed; no guessed fallback profile.
  Future<Map<String, dynamic>> loadProductConfiguration(
    int modelId, {
    String firmwareVersion = '0.0.0',
  }) async {
    _integer(modelId, 'modelId', 0, 65535);
    _firmware(firmwareVersion);
    final products = await allDeviceList();
    final matches = products.where((p) => p.modelId == modelId).toList();
    if (matches.length != 1) {
      throw FormatException('型号 $modelId 的产品匹配数为 ${matches.length}；需唯一原厂配置');
    }
    final panel = await requestFunControlPanel(
      matches.single,
      firmwareVersion: firmwareVersion,
    );
    return convertFactoryPanel(modelId, panel);
  }

  Future<List<FactoryProduct>> allDeviceList() async =>
      parseFactoryProductList(await _get(_listPath, const {}));

  Future<Map<String, dynamic>> requestFunControlPanel(
    FactoryProduct product, {
    String firmwareVersion = '0.0.0',
  }) async {
    _firmware(firmwareVersion);
    return parseFactoryPanel(
      await _get(_panelPath, {
        'vendorId': '${product.modelId}',
        'flageId': '${product.flageId}',
        'firmwareVersion': firmwareVersion,
        'appVersion': '1.26.38',
        'sys_': 'Android',
      }),
    );
  }

  Future<String> _get(String path, Map<String, String> query) async {
    final uri = Uri.https(_host, path, query.isEmpty ? null : query);
    // Defense in depth: neither server metadata nor callers select a URL.
    if (uri.scheme != 'https' ||
        uri.host != _host ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.path != _listPath && uri.path != _panelPath)) {
      throw ArgumentError('Configuration endpoint rejected');
    }
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout
      ..autoUncompress = false
      ..findProxy = (_) => 'DIRECT';
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        request.maxRedirects = 0;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Android-XT-Water-Phone',
        );
        request.headers.set('lang', 'zh');
        request.headers.set('language', 'zh');
        request.headers.set('country', 'CN');
        request.headers.set('appVerson', '1.26');
        // Authorization and cookies are deliberately absent.
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('配置服务 HTTP ${response.statusCode}');
        }
        final encoding = response.headers.value(
          HttpHeaders.contentEncodingHeader,
        );
        if (encoding != null && encoding.toLowerCase() != 'identity') {
          throw const FormatException('压缩响应被拒绝');
        }
        final mime = response.headers.contentType?.mimeType;
        if (mime != 'application/json' && !(mime?.endsWith('+json') ?? false)) {
          throw const FormatException('配置响应不是 JSON');
        }
        if (response.contentLength > _maxBytes) {
          throw const FormatException('配置响应超过 2 MiB');
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > _maxBytes) {
            throw const FormatException('配置响应超过 2 MiB');
          }
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes, allowMalformed: false);
      })().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}

class FactoryProduct {
  final int modelId;
  final int flageId;
  final String name;
  FactoryProduct({
    required this.modelId,
    required this.name,
    this.flageId = 0xc912,
  }) {
    _integer(modelId, 'vendorId', 0, 65535);
    _integer(flageId, 'flageId', 0, 65535);
    _text(name, 'productName');
    // Server sends 4809 (0x12C9, byte-swapped view of the 0xC912 marker).
    if (flageId != 0xc912 && flageId != 4809) {
      throw const FormatException('非 C912 产品配置不匹配当前广播识别器');
    }
  }
}

/// BaseResult<T>.getContent() reads the JSON field `data`, NOT `content`.
Object? _unwrap(String text) {
  final result = _object(decodeConfigurationJson(text), 'BaseResult');
  if (_integer(result['code'], 'code', 0, 999999) != 200) {
    throw const FormatException('配置服务业务状态不是 200');
  }
  if (result['success'] != null && result['success'] is! bool) {
    throw const FormatException('success 须为布尔值');
  }
  if (result['success'] == false) throw const FormatException('配置服务报告失败');
  if (result['msg'] != null) _text(result['msg'], 'msg', allowEmpty: true);
  if (!result.containsKey('data')) throw const FormatException('缺少 data');
  return result['data'];
}

List<FactoryProduct> parseFactoryProductList(String response) {
  final groups = _array(_unwrap(response), 'data', 512);
  final result = <FactoryProduct>[];
  for (final value in groups) {
    final group = _object(value, 'ProductTypeBean');
    if (group['proType'] != null)
      _integer(group['proType'], 'proType', 0, 65535);
    if (group['typeName'] != null) _text(group['typeName'], 'typeName');
    for (final value in _array(group['earbudsList'], 'earbudsList', 4096)) {
      final p = _object(value, 'DeviceBean');
      final name = p['productName'] ?? p['title'] ?? p['deviceName'];
      result.add(
        FactoryProduct(
          modelId: _integer(p['vendorId'], 'vendorId', 0, 65535),
          flageId: p['flageId'] == null
              ? 0xc912
              : _integer(p['flageId'], 'flageId', 0, 65535),
          name: _text(name, 'productName/title/deviceName'),
        ),
      );
      if (result.length > 4096) throw const FormatException('产品总数超过限制');
    }
  }
  return List.unmodifiable(result);
}

Map<String, dynamic> parseFactoryPanel(String response) {
  final data = _unwrap(response);
  // Retrofit declares BaseResult<String>; tolerate an already-decoded object
  // for offline exports, without treating arbitrary URLs as panel locations.
  return _object(
    data is String
        ? decodeConfigurationJson(data, allowDuplicateKeys: true)
        : data,
    'ControlFuncs',
  );
}

/// Converts only evidenced fields. Unknown metadata is ignored, never executed.
/// Invalid supplied capability fields reject the conversion atomically.
Map<String, dynamic> convertFactoryPanel(
  int modelId,
  Map<String, dynamic> panel,
) {
  _integer(modelId, 'modelId', 0, 65535);
  final config = <String, dynamic>{
    'modelId': modelId,
    'ancModes': <dynamic>[],
    'game': false,
  };
  final warnings = <String>[];
  final anc = _optionalItem(panel, 'ancDeepMode', expectedCommand: 9);
  if (anc != null) {
    final ids = <int>{};
    final modes = <Map<String, dynamic>>[];
    for (final value in _array(anc['modes'], 'ancDeepMode.modes', 32)) {
      final mode = _object(value, 'ANC mode');
      final id = _integer(mode['cmdid'], 'ANC cmdid', 0, 255);
      if (!ids.add(id)) throw const FormatException('ANC cmdid 重复');
      final label = _text(mode['name'], 'ANC name');
      // Real panels omit defaultLevel/levelModels for simple on/off/pass modes.
      final initial = mode['defaultLevel'] == null
          ? 0
          : _integer(mode['defaultLevel'], 'defaultLevel', 0, 255);
      final levels = <int>[];
      final levelNames = <String, String>{};
      if (mode['levelModels'] != null) {
        for (final value in _array(mode['levelModels'], 'levelModels', 256)) {
          final level = _object(value, 'LevelModel');
          final number = _integer(level['level'], 'level', 0, 255);
          if (levels.contains(number))
            throw const FormatException('ANC level 重复');
          levels.add(number);
          levelNames['$number'] = _text(level['name'], 'level name');
        }
      }
      // A mode-button click sends its explicitly supplied defaultLevel even
      // without a level picker. Do not invent 0..maxDepth or ordinal levels.
      if (levels.isEmpty) levels.add(initial);
      if (!levels.contains(initial))
        throw const FormatException('defaultLevel 不在 levelModels 中');
      modes.add({
        'id': id,
        'label': label,
        'defaultLevel': initial,
        'levels': levels,
        if (levelNames.isNotEmpty) 'levelLabels': levelNames,
      });
    }
    config['ancModes'] = modes;
  }
  final game = _optionalItem(panel, 'gameMode', expectedCommand: 14);
  config['game'] = game != null;
  final toggles = <Map<String, dynamic>>[];
  // These are actual FunctionBeanTitleSwitch paths in HomeViewModel.
  for (final key in ['closeTouch', 'toneVolumeControl']) {
    final item = _optionalItem(panel, key);
    if (item != null) toggles.add({'id': item['cmdid'], 'label': item['name']});
  }
  if (toggles.map((x) => x['id']).toSet().length != toggles.length) {
    throw const FormatException('toggle cmdid 重复');
  }
  if (toggles.any((x) => [1, 2, 9, 14].contains(x['id']))) {
    throw const FormatException('toggle cmdid 与专用功能冲突');
  }
  if (toggles.isNotEmpty) config['toggles'] = toggles;

  final eq = _optionalItem(panel, 'equalizer', expectedCommand: 2);
  if (eq != null) {
    final presets = <Map<String, dynamic>>[];
    final ids = <int>{};
    if (eq['sys_eq'] != null) {
      for (final value in _array(eq['sys_eq'], 'sys_eq', 256)) {
        final preset = _object(value, 'EQSubItem');
        final id = _integer(preset['eqid'], 'eqid', 0, 255);
        if (!ids.add(id)) throw const FormatException('eqid 重复');
        final label = _text(preset['name'], 'EQ preset name');
        // The controller schema requires exactly ten signed gains. Missing
        // gains are NOT padded to zero, nor are unsigned values wrapped.
        if (preset['eqs'] == null) {
          warnings.add('EQ 预设 $id 缺少 eqs，未启用');
          continue;
        }
        final gains = _array(preset['eqs'], 'eqs', 10);
        if (gains.length != 10) throw const FormatException('eqs 必须为 10 项');
        presets.add({
          'id': id,
          'label': label,
          'gains': [for (final g in gains) _integer(g, 'gain', -128, 127)],
        });
      }
    }
    if (presets.isNotEmpty) config['eqPresets'] = presets;
    final hidden = eq['isHideCustomEQ'];
    if (hidden != null) _integer(hidden, 'isHideCustomEQ', 0, 1);
    if (eq['count'] != null) _integer(eq['count'], 'count', 1, 256);
    if (hidden == 1) {
      warnings.add('原厂隐藏自定义 EQ；仅保留明确预设');
    } else if (eq['freq'] == null ||
        eq['mindb'] == null ||
        eq['maxdb'] == null) {
      warnings.add('缺少 EQ freq/mindb/maxdb；不推测频段或增益范围');
    } else {
      final freq = _array(eq['freq'], 'freq', 10);
      if (freq.length != 10 || (eq['count'] != null && eq['count'] != 10)) {
        throw const FormatException('当前 controller 仅支持 10 频段 EQ');
      }
      final frequencies = [
        for (final f in freq) _integer(f, 'frequency', 1, 1000000),
      ];
      for (var i = 1; i < frequencies.length; i++) {
        if (frequencies[i] <= frequencies[i - 1])
          throw const FormatException('EQ 频率须严格递增');
      }
      final rawMin = _integer(eq['mindb'], 'mindb', -128, 127);
      final rawMax = _integer(eq['maxdb'], 'maxdb', -128, 127);
      // Real panels send magnitude bounds (mindb=8, maxdb=8 meaning ±8).
      // Accept both a real min<max range and equal/signed magnitudes.
      int min, max;
      if (rawMin < rawMax) {
        min = rawMin;
        max = rawMax;
      } else {
        final magnitude = rawMax.abs() >= rawMin.abs()
            ? rawMax.abs()
            : rawMin.abs();
        if (magnitude == 0) throw const FormatException('EQ 增益范围无效');
        min = -magnitude;
        max = magnitude;
      }
      config['eq'] = {
        'labels': [for (final f in frequencies) '$f Hz'],
        'min': min,
        'max': max,
      };
    }
  }
  final buttons = <Map<String, dynamic>>[];
  final events = <int>{};
  void addButton(Map<String, dynamic> side, String label) {
    final event = _integer(side['eventID'], 'eventID', 0, 255);
    if (!events.add(event))
      throw const FormatException('button eventID 重复/两种面板定义冲突');
    final functions = <Map<String, dynamic>>[];
    final ids = <int>{};
    for (final value in _array(side['list'], 'button list', 256)) {
      final f = _object(value, 'FuncItem');
      final id = _integer(f['cmd'], 'function cmd', 0, 255);
      if (!ids.add(id)) throw const FormatException('button function 重复');
      functions.add({'id': id, 'label': _text(f['name'], 'function name')});
    }
    if (functions.isEmpty) throw const FormatException('button functions 为空');
    if (side['defaultFun'] != null &&
        !ids.contains(_integer(side['defaultFun'], 'defaultFun', 0, 255))) {
      throw const FormatException('defaultFun 不在 functions 中');
    }
    buttons.add({'eventId': event, 'label': label, 'functions': functions});
  }

  final keys = _optionalItem(panel, 'earbudsKey', expectedCommand: 1);
  if (keys != null) {
    final music = _object(keys['music'], 'earbudsKey.music');
    for (final value in _array(music['event'], 'music.event', 128)) {
      final event = _object(value, 'EventItem');
      final label = _text(event['name'], 'event name');
      for (final side in ['left', 'right']) {
        if (event[side] == null) continue;
        final data = _object(event[side], side);
        // Real panels put per-side names on earbudsKey.leftName/rightName and
        // may omit them entirely; fall back to a stable label.
        final sideLabel = keys[side == 'left' ? 'leftName' : 'rightName'];
        final sideText = sideLabel is String && sideLabel.trim().isNotEmpty
            ? sideLabel
            : (side == 'left' ? '左耳' : '右耳');
        addButton(data, '$sideText · $label');
      }
    }
  }
  final single = _optionalItem(panel, 'singleEarbudsKey', expectedCommand: 1);
  if (single != null) {
    for (final value in _array(single['KeyList'], 'KeyList', 128)) {
      final set = _object(value, 'SetInfo');
      final label = _text(set['name'], 'key name');
      for (final value in _array(set['event'], 'key event', 256)) {
        final side = _object(value, 'SideInfo');
        addButton(side, '$label · ${_text(side['eventName'], 'eventName')}');
      }
    }
  }
  if (buttons.isNotEmpty) config['buttons'] = buttons;
  // ControlBaseItem has no numeric range fields for prompt volume/shutdown.
  // Their existence alone is not proof of a product's min/max; omit both.
  if (panel['toneVolumeControl'] != null)
    warnings.add('提示音仅有开关证据，未生成 promptVolume 范围');
  if (panel['timedShutdown'] != null) warnings.add('未确认定时关机范围，未生成 powerOff');
  if (panel['pairName'] != null) warnings.add('未确认改名能力参数，未生成 rename');
  if (warnings.isNotEmpty) config['configurationWarnings'] = warnings;
  return config;
}

Map<String, dynamic>? _optionalItem(
  Map<String, dynamic> panel,
  String key, {
  int? expectedCommand,
}) {
  if (panel[key] == null) return null;
  final item = _object(panel[key], key);
  final command = _integer(item['cmdid'], '$key.cmdid', 0, 255);
  _text(item['name'], '$key.name');
  if (expectedCommand != null && command != expectedCommand) {
    throw FormatException('$key.cmdid=$command 与已恢复指令 $expectedCommand 不符');
  }
  return item;
}

Map<String, dynamic> _object(Object? value, String name) {
  if (value is! Map<String, dynamic>) throw FormatException('$name 须为 JSON 对象');
  return value;
}

List<dynamic> _array(Object? value, String name, int limit) {
  if (value is! List || value.length > limit)
    throw FormatException('$name 须为最多 $limit 项数组');
  return value;
}

int _integer(Object? value, String name, int min, int max) {
  // Server returns ids as JSON strings ("16017"); accept int or numeric string.
  int? parsed;
  if (value is int)
    parsed = value;
  else if (value is String)
    parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < min || parsed > max) {
    throw FormatException('$name 须为 $min..$max 整数');
  }
  return parsed;
}

String _text(Object? value, String name, {bool allowEmpty = false}) {
  if (value is! String ||
      value.length > 4096 ||
      (!allowEmpty && value.trim().isEmpty) ||
      value.runes.any((r) => r < 32 || r == 127)) {
    throw FormatException('$name 须为非控制字符文本（最多 4096 字符）');
  }
  return value;
}

void _firmware(String value) {
  if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(value)) {
    throw const FormatException('firmwareVersion 格式无效');
  }
}

/// Bounded strict JSON including duplicate-key rejection before jsonDecode.
Object? decodeConfigurationJson(
  String text, {
  bool allowDuplicateKeys = false,
}) {
  if (text.length > _maxBytes || utf8.encode(text).length > _maxBytes) {
    throw const FormatException('JSON 超过 2 MiB');
  }
  _JsonGuard(text, allowDuplicateKeys: allowDuplicateKeys).check();
  return jsonDecode(text);
}

class _JsonGuard {
  final String text;
  final bool allowDuplicateKeys;
  int i = 0, nodes = 0;
  _JsonGuard(this.text, {this.allowDuplicateKeys = false});
  Never bad() => throw FormatException('JSON 结构/重复键无效', null, i);
  void space() {
    while (i < text.length && ' \r\n\t'.contains(text[i])) {
      i++;
    }
  }

  void check() {
    value(0);
    space();
    if (i != text.length) bad();
  }

  String string() {
    final start = i++;
    while (i < text.length) {
      final c = text[i++];
      if (c == '\\') {
        if (i >= text.length) bad();
        i++;
      } else if (c == '"') {
        return jsonDecode(text.substring(start, i)) as String;
      }
    }
    return bad();
  }

  void value(int depth) {
    space();
    if (depth > 32 || ++nodes > 100000 || i >= text.length) bad();
    final c = text[i];
    if (c == '"') {
      string();
      return;
    }
    if (c == '{' || c == '[') {
      i++;
      final close = c == '{' ? '}' : ']';
      final keys = <String>{};
      space();
      if (i < text.length && text[i] == close) {
        i++;
        return;
      }
      while (true) {
        space();
        if (c == '{') {
          if (i >= text.length || text[i] != '"') bad();
          final key = string();
          if (!allowDuplicateKeys && !keys.add(key)) bad();
          space();
          if (i >= text.length || text[i++] != ':') bad();
        }
        value(depth + 1);
        space();
        if (i >= text.length) bad();
        final delimiter = text[i++];
        if (delimiter == close) return;
        if (delimiter != ',') bad();
      }
    }
    final start = i;
    while (i < text.length && !' \r\n\t,]}'.contains(text[i])) {
      i++;
    }
    if (start == i) bad();
    final primitive = jsonDecode(text.substring(start, i));
    if (primitive is Map || primitive is List || primitive is String) bad();
  }
}
