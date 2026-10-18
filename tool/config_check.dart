// Offline synthetic checks only; never opens HttpClient or Bluetooth.
// Added for the parent agent's serial validation. Not run by this subagent.
import 'dart:convert';
import '../lib/config/product_config.dart';

int checks = 0;
void expect(bool ok, String label) {
  checks++;
  if (!ok) throw StateError(label);
}
void rejects(void Function() f, String label) {
  try { f(); } on FormatException { checks++; return; }
  throw StateError('Expected FormatException: $label');
}
String envelope(Object? data) => jsonEncode({'code': 200, 'success': true, 'data': data});
Map<String, dynamic> item(int command, String name) => {'cmdid': command, 'name': name};
Map<String, dynamic> fixture() => {
  'ancDeepMode': {...item(9, '降噪'), 'modes': [
    {'cmdid': 7, 'name': '原厂模式', 'defaultLevel': 4,
      'maxDepth': 255, 'levelModels': [
        {'level': 4, 'name': '低'}, {'level': 9, 'name': '高'},
      ]},
    {'cmdid': 2, 'name': '关闭', 'defaultLevel': 3},
  ]},
  'gameMode': item(14, '游戏'),
  'closeTouch': item(15, '触控开关'),
  'equalizer': {...item(2, '均衡器'), 'count': 10, 'mindb': -6,
    'maxdb': 6, 'freq': [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
    'sys_eq': [{'eqid': 3, 'name': '原厂预设', 'eqs': [-1, 0, 1, 2, 3, 4, 3, 2, 1, 0]}]},
  'singleEarbudsKey': {...item(1, '按键'), 'KeyList': [
    {'name': '左耳', 'event': [{'eventID': 17, 'eventName': '双击',
      'defaultFun': 4, 'list': [{'cmd': 4, 'name': '下一曲'}]}]},
  ]},
  'timedShutdown': item(30, '定时关机'),
  'pairName': item(31, '改名'),
};

void main() {
  final products = parseFactoryProductList(envelope([
    {'typeName': '耳机', 'proType': 1, 'earbudsList': [
      {'vendorId': 14369, 'flageId': 51474, 'productName': 'synthetic'}
    ]}
  ]));
  expect(products.single.modelId == 14369, 'vendorId is broadcast model');
  expect(products.single.flageId == 0xc912, 'flageId retained');
  final panel = parseFactoryPanel(envelope(jsonEncode(fixture())));
  final config = convertFactoryPanel(14369, panel);
  expect(config['modelId'] == 14369 && config['game'] == true, 'model/game');
  final modes = config['ancModes'] as List;
  expect(modes[0]['id'] == 7, 'ANC ID not index');
  expect(jsonEncode(modes[0]['levels']) == '[4,9]', 'no invented 0..maxDepth levels');
  expect(jsonEncode(modes[1]['levels']) == '[3]', 'explicit mode default retained');
  expect(config['eq']['min'] == -6 && config['eq']['max'] == 6, 'factory gain bounds');
  expect(config['eq']['labels'][0] == '32 Hz', 'factory frequencies');
  expect(config['eqPresets'][0]['gains'][0] == -1, 'signed gains');
  expect(config['buttons'][0]['eventId'] == 17, 'button wire eventID');
  expect(config['buttons'][0]['functions'][0]['id'] == 4, 'button function cmd');
  expect(config['toggles'][0]['id'] == 15, 'toggle cmd from panel');
  expect(!config.containsKey('powerOff') && !config.containsKey('rename') &&
      !config.containsKey('promptVolume'), 'no speculative ranges/rename');
  final empty = convertFactoryPanel(1, {});
  expect(empty['game'] == false && (empty['ancModes'] as List).isEmpty &&
      !empty.containsKey('eq'), 'unknown capabilities stay locked');
  var p = fixture();
  p['equalizer'].remove('mindb');
  expect(!convertFactoryPanel(1, p).containsKey('eq'), 'missing gain bound locks editor');
  p = fixture();
  p['equalizer']['isHideCustomEQ'] = 1;
  final hidden = convertFactoryPanel(1, p);
  expect(!hidden.containsKey('eq') && hidden.containsKey('eqPresets'), 'hidden custom EQ keeps presets');
  p = fixture();
  p['equalizer']['sys_eq'][0].remove('eqs');
  expect(!convertFactoryPanel(1, p).containsKey('eqPresets'), 'no gain zero-padding');

  rejects(() => decodeConfigurationJson('{"x":1,"x":2}'), 'duplicate keys');
  rejects(() => decodeConfigurationJson('{"x":1,"\\u0078":2}'), 'escaped duplicate');
  rejects(() => decodeConfigurationJson('${List.filled(34, '[').join()}0${List.filled(34, ']').join()}'), 'depth');
  rejects(() => decodeConfigurationJson('${' ' * (2 * 1024 * 1024)}0'), 'size');
  rejects(() => parseFactoryPanel('{"code":200,"content":"{}"}'), 'data is not content');
  rejects(() => parseFactoryPanel('{"code":401,"data":"{}"}'), 'business failure');
  rejects(() => parseFactoryPanel('{"code":200,"success":false,"data":"{}"}'), 'success false');
  rejects(() => parseFactoryPanel(envelope('{"x":1,"x":2}')), 'inner duplicate');
  rejects(() => convertFactoryPanel(-1, {}), 'model bounds');
  p = fixture(); p['gameMode']['cmdid'] = 15;
  rejects(() => convertFactoryPanel(1, p), 'game opcode mismatch');
  p = fixture(); p['ancDeepMode']['modes'][0]['defaultLevel'] = 5;
  rejects(() => convertFactoryPanel(1, p), 'default not in factory levels');
  p = fixture(); p['ancDeepMode']['modes'][0]['cmdid'] = 256;
  rejects(() => convertFactoryPanel(1, p), 'ANC byte overflow');
  p = fixture(); p['ancDeepMode']['modes'][1]['cmdid'] = 7;
  rejects(() => convertFactoryPanel(1, p), 'duplicate ANC mode');
  p = fixture(); p['equalizer']['sys_eq'][0]['eqs'][0] = 128;
  rejects(() => convertFactoryPanel(1, p), 'gain must not wrap');
  p = fixture(); p['equalizer']['maxdb'] = -7;
  rejects(() => convertFactoryPanel(1, p), 'inverted gain bounds');
  p = fixture(); p['equalizer']['freq'] = [32, 64];
  rejects(() => convertFactoryPanel(1, p), 'frequency count');
  p = fixture(); p['equalizer']['freq'][1] = 32;
  rejects(() => convertFactoryPanel(1, p), 'duplicate frequencies');
  p = fixture(); p['singleEarbudsKey']['KeyList'][0]['event'][0]['defaultFun'] = 99;
  rejects(() => convertFactoryPanel(1, p), 'button default not in list');
  p = fixture(); p['closeTouch']['name'] = 'bad\nlabel';
  rejects(() => convertFactoryPanel(1, p), 'control characters');
  print('config_check: $checks offline synthetic checks passed; no network/device I/O');
}
