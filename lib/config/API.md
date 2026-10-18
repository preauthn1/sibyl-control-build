# 原厂产品配置 API（仅静态恢复）

## 状态与边界

**CONFIRMED（静态）**：本文路径、查询参数、字段、调用分支来自 APK 恢复 DEX 的定点 JADX 输出。**未验证**：线上服务当前行为、匿名访问是否被服务器接受、真实产品响应及硬件互操作性。未访问业务端点、未登录、未调用 token API、未扫描/连接设备、未运行测试/构建。`tool/config_check.dart` 为交给主代理串行执行的离线合成检查，不是原厂配置样本。

只新增 `lib/config/` 与 `tool/config_check.dart`，未改 controller/UI。因此模块本身不会自动解除 UI 锁定；主代理需将用户按钮接入下面接口。

## 集成接口

```dart
import 'config/product_config.dart';

final productConfigClient = ProductConfigClient(); // 不联网
// 仅 loadProductConfiguration 用户按钮触发；先确认广播型号非空。
final configuration = await productConfigClient.loadProductConfiguration(
  modelId, // identities[connectedId].modelId；不是 proModelId、chipId 或名称
  firmwareVersion: '0.0.0', // 原厂 DeviceBean 的未知固件默认值
);
```

精确签名：

- `ProductConfigClient({Duration timeout = const Duration(seconds: 15)})`
- `Future<Map<String,dynamic>> loadProductConfiguration(int modelId, {String firmwareVersion = '0.0.0'})`
- `Future<List<FactoryProduct>> allDeviceList()`
- `Future<Map<String,dynamic>> requestFunControlPanel(FactoryProduct product, {String firmwareVersion = '0.0.0'})`
- `List<FactoryProduct> parseFactoryProductList(String response)`：离线解析原厂完整 envelope。
- `Map<String,dynamic> parseFactoryPanel(String response)`：离线解析 envelope 及其中 JSON 字符串。
- `Map<String,dynamic> convertFactoryPanel(int modelId, Map<String,dynamic> panel)`：离线转换裸 `ControlFuncs`。
- `Object? decodeConfigurationJson(String text)`：带重复键、深度、大小检查的 JSON 解码。

无持久缓存、后台刷新、构造时请求或蓝牙副作用。每次高层调用串行读产品列表、唯一匹配 vendorId、读该面板。列表中未知型号或多个相同 vendorId 均抛 `FormatException`，不选第一个、不按名称猜测。UI 可缓存成功返回的 schema；读取异常不得替换现有有效配置或解锁未知能力。

**集成注意**：既有 `EarbudController.importConfiguration` 在连接时禁止导入。父代理需在自己的 controller 修改中处理用户主动载入配置、连接 epoch 和型号再次校验；不能在联网返回后把旧连接型号的结果赋给新连接。解析器不负责修改该限制，也不发送状态查询。RTK ANC/EQ 的既有协商锁不因配置存在而解除。

## 原厂 HTTP 合约

固定源 `https://sibyl.linkcos.cn`，只允许下列两个 GET：

| 路径 | 查询 | 返回 |
|---|---|---|
| `/app/promodel/list` | 无 | `BaseResult<ArrayList<ProductTypeBean>>` |
| `/app/func/controlpanel` | `vendorId`、`flageId`、`firmwareVersion`、`appVersion=1.26.38`、`sys_=Android` | `BaseResult<String>`，`data` 是面板 JSON 字符串 |

证据：`evidence/ApiHelper.java.txt/ApiHelper.java:32-34,65-71`；`evidence/ApiServer/ApiServer.java:16-17,31-32`。

`BaseResult` 的成员名是 `code/data/msg/success`；Java `getContent()` 读取 **data** 而不是 `content`，见 `evidence/BaseResult/BaseResult.java:6-10,29-34`。client 要求 code=200；success 若存在必须为 bool，false 拒绝；不包含 data 拒绝。面板还接受已解码的对象用于离线导出兼容，但该分支不是已证实的服务端变体。

列表 `data[]`：`{proType,typeName,earbudsList:[DeviceBean...]}`。`ProductTypeBean` 证据：`evidence/ProductTypeBean/ProductTypeBean.java:8-11,30-36`。每个 DeviceBean 使用 `vendorId` 作为当前广播 modelId；`flageId` 必须为 C912（十进制 51474）。缺失 flageId 使用原厂 DeviceBean 构造默认 C912，不是 company ID 字节反序；显式其他值拒绝。名称取产品返回的 productName/title/deviceName，仅展示，不作为匹配依据。

静态证据（以下相对 `../sibyl-bluetooth/static_recovered/`）：

- `ui_mapping/ControlFunManager.java:143-153,256-273`：按 `getVendorId()==modelId` 匹配。
- `ui_mapping/DeviceBean.java:61-76`：flageId=51474、firmwareVersion=0.0.0。
- `ui_mapping/ControlFunManager.java:62-78,195-200`：控制面板 content 经 Gson 转 `ControlFuncs`；产品列表检查 code=200。

原厂 `BaseRetrofit.TokenInterceptor` 会加普通标头、语言及设备信息；仅本地 token 非空时加入 Authorization，见 `evidence/BaseRetrofit/BaseRetrofit.java:136-159`。这证明客户端调用路径可不带 Authorization，**不证明服务端一定公开可读**。本模块不取 token、不登录、不带 cookie；401/403/业务失败直接返回错误，不自动转登录。只复用 User-Agent、lang/language/country、原厂拼写 `appVerson`；不伪造 SDK/设备信息。也不复制原厂不安全 hostname verifier。

## 原厂 JSON → controller schema

| controller 字段 | 原厂来源 / 规则 |
|---|---|
| `modelId` | 唯一匹配的广播 modelId/vendorId，0..65535 |
| `ancModes[].id/label/defaultLevel` | `ancDeepMode.modes[].cmdid/name/defaultLevel`，不是列表下标；外层 cmdid 必须9 |
| `ancModes[].levels` | `levelModels[].level`，若无 picker 仅保留显式 defaultLevel 一个可发送值，不生成0..maxDepth |
| `ancModes[].levelLabels` | 可选扩展，由各 `LevelModel.name` 映射供 UI 使用 |
| `game` | 仅 `gameMode` 对象存在、cmdid=14 且文案合法时 true |
| `eq.labels/min/max` | `equalizer.freq[]/mindb/maxdb`；cmdid=2，正好10个递增频率，signed-byte 增益区间；原厂隐藏 custom 时不生成 eq |
| `eqPresets[].id/label/gains` | `equalizer.sys_eq[].eqid/name/eqs`；gains 必须明确给出10个 -128..127 整数；缺失则跳过该预设并警告，不补零、不绕回unsigned |
| `toggles[].id/label` | 仅已确认标题开关路径 `closeTouch`、`toneVolumeControl` 的 cmdid/name；不把任意 ControlBaseItem 当开关 |
| `buttons[].eventId/label/functions` | `earbudsKey.music.event[].left/right` 或 `singleEarbudsKey.KeyList[].event[]`；eventID、list[].cmd/name 原样验证 |

证据：`ui_mapping/ControlItemANCMode.java:13-28`、`ui_mapping/FunctionBeanANC.java:28-43`、`ui_mapping/ItemViewANC.java:71-99,110-121`；`ui_mapping/ControlItemEQ.java:8-29,41-50,81-90,113-115`；`ui_mapping/HomeViewModel.java:206-243`；本目录 `evidence/ControlItemBtnKey/ControlItemBtnKey.java:16-28,55-72` 与 `evidence/ControlitemEarbudsKey/ControlitemEarbudsKey.java:8-19,30-37`。

**不生成** promptVolume/min/max、powerOff/min/max、rename：现有 ControlBaseItem 只有功能元信息，没有明确产品范围/名称写入参数。toneVolumeControl 实际走 bool 开关，不能据名称编造音量滑杆；timedShutdown 存在不能据此猜范围；pairName 存在还不足以证明当前控制器改名命令兼容。`configurationWarnings` 说明降级原因。禁止根据 maxDepth、频段数或按钮个数推断档位/gain。

转换采用原子失败：消费字段的类型、范围、文本控制字符、唯一 ID、defaultLevel/defaultFun 成员关系、十频段、频率顺序、增益大小均验证；未消费的图片/图标/OTA/恢复出厂等元数据不进入输出、不触发网络或指令。原厂无字段不会强制开启未知能力。

## 网络与解析约束

- TLS 使用系统证书和 hostname 校验；HTTPS、固定精确 host、443、两个固定 path；无调用者 URL、无 metadata URL下载。
- 禁重定向、代理直连；每个请求独立 HttpClient，不复用 cookie/auth。
- 默认每请求总计15秒（含读取），可设0..60秒；同样设置 connect/idle timeout。超时或失败 finally 强制关闭 client，不留下后台请求；两个请求不重试。
- 仅 HTTP200、JSON MIME；请求 identity 编码并拒绝压缩响应，杜绝解压膨胀。响应累计最多2 MiB（含chunked），检查 Content-Length 但不信任它。
- UTF8严格、JSON重复键拒绝（含转义等价键）、嵌套最多32层、值节点最多100000；内部面板 JSON 二次应用同样约束。
- 型号/command/event/gain 不作字符串强转，不接受浮点、bool或16进制字符串。文本不允许控制字符。产品总数最多4096、组最多512，局部列表均有边界。
- 严格验证可能拒绝服务端未来格式变化；应保留错误并更新静态证据，不静默放宽为猜测配置。

## 验证与回滚

本子任务仅写文件、阅读源码和定点反编译（JADX 单线程、512MiB heap），没有执行 `dart`/`flutter`/测试/构建。主代理可串行运行 `dart tool/config_check.dart`；其输出只能证明合成离线检查，不是线上/硬件验证。检查覆盖 data envelope、字符串面板、重复键/深度/大小、原厂 ANC 非连续档位、EQ签名与缺失字段锁定、隐藏custom、按键和非法输入拒绝。

回滚：删除本任务新增 `lib/config/` 以及 `tool/config_check.dart`；controller/UI 未在本任务范围内修改，不需回退其他文件。JADX 尝试 `com.sibyl.app.http.HttpManager` 未找到，转由已恢复 `BaseRetrofit` 获取真实拦截器；不影响两个配置API证据。
