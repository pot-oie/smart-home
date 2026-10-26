# USB 转 TTL 上传（R5）

当前阶段：RFID读卡成功，增加主控主动串口上传。2026-10-26已编译、备份烧录并逐字节回读校验UART版固件（Flash13468B/RAM2216B），记录在本机`artifacts/rfid/flash_20261026_103832`。实物USB转TTL经历异常枚举，经USB软件重新枚举后识别为USB Serial（VID0x1A86/PID0x7523），本机串口/dev/cu.usbserial-1140已成功打开；随后用户恢复主控供电，真实IOT1串口帧校验通过，两个UID已在安卓模拟器显示；接收服务暂停9秒隐藏旧值、恢复后自动更新也已实测。物理USB拔插恢复尚未在本轮单独验收。

## 链路与接线

STM32 USART1 TX → USB转TTL RXD → Mac串口 → 本地接收服务 → Android模拟器。运行时不使用CubeProgrammer、ST-LINK读RAM、ELF或STM32开发环境。烧录固件仍使用ST-LINK；主控必须有稳定供电，当前保留原ST-LINK供电方式，串口数据不经过ST-LINK。

断开两侧USB电源后新增2根母对母线：

| STM32丝印 | USB转TTL丝印 |
| --- | --- |
| A9（PA9 / USART1_TX） | RXD |
| G / GND | GND |

USB转TTL的TXD、VCC、5V、3V3均留空。单向上传不使用其TXD，因此无需让未知逻辑电平的模块输出连接主控。现有RC522七线保留。两个USB分别接Mac：ST-LINK为主控提供现有电源；USB转TTL提供串口链路。不要并联两路供电输出。此阶段不接NodeMCU，也不使用其Micro-USB代替独立USB转TTL模块。

连接后先检查`/dev/cu.*`，识别新增设备，例如`/dev/cu.usbserial-...`；实际名称以本机为准，不能固定写死。仅看到LED不代表串口被系统识别；没有设备时先核查USB连接、数据线、转接器和设备VID/PID，再决定是否需要驱动，不盲目安装。

## 接收程序

在客户端目录执行：

```sh
python3 -u tools/serial_gateway.py --device /dev/cu.usbserial-实际编号 --record ../../artifacts/rfid/serial_upload.jsonl
```

串口固定9600波特率、8数据位、无校验、1停止位、无流控；只读数据，不向主控发送命令。Python3标准库实现，无需pip、ST工具或ELF。服务绑定Mac本地127.0.0.1:8765；不能同时运行旧swd_gateway占用同一端口。

接入安卓模拟器：

```sh
adb -s emulator-5554 reverse tcp:8765 tcp:8765
flutter run -d emulator-5554 -t lib/main_hardware.dart
```

入口显示“USB 串口”和RFID最近卡号、刷卡事件序号。未连接的温湿度/光照显示无有效读数，不造数据；尚未做真实授权判断/写卡/远程控制。原main.dart仍是模拟界面，不能混淆。

## 帧与有效性

每约1秒上传一帧ASCII，格式为`IOT1,<18个数据字段>*CCCC\r\n`，共19个逗号分隔字段（含IOT1）。从左到右：

`IOT1,seq,uptimeMs,dhtAttempts,dhtFrameOK,temperatureTenths,humidityTenths,lightAttempts,lightValid,luxTenths,rfidPolls,rfidStatus,chipVersion,eventSeq,cardReads,lastSeenMs,UIDhex,sak,atqa*CRC16`

温湿度/光照采用十分之一单位整数，UID为8/14/20位大写十六进制，未读卡为`-`。CRC16/CCITT-FALSE，poly0x1021、init0xFFFF、不反射、xorout0，覆盖星号前所有ASCII字节；标准测试`123456789`→0x29B1。按换行恢复帧边界，拒绝损坏/超长/错误状态/重复帧；序号或设备时间重置时开始新的接收会话。

有效上传帧并不自动证明每个模块都更新：传感器采样计数和RFID轮询计数分别跟踪，超过6秒不变视为旧数据。串口断开或6秒无有效帧，页面显示连接/更新异常，恢复后自动重新读取。最近卡号可能保留，卡号存在不代表卡当前仍在天线上，也不代表已授权。

## 验证要求

1. 停止所有ST-LINK读数和调试进程，只运行serial_gateway。
2. 收到真实串口帧，CRC通过且序号、设备时间、RFID轮询计数持续增加。
3. 刷卡后UID与实测一致，当前已测卡为本机私有记录中的卡号；不把具体卡号硬编码进程序。
4. 拔下USB转TTL时页面停止更新并隐藏当前读数，插回能恢复；主控继续独立采样。
5. 打开Android模拟器真实入口，确认USB串口标记和真实卡号。授权名单后续单独接入。

软件检查：固件构建、Flutter analyze通过；Dart解析4项测试通过；Python协议和伪终端收发/断线测试共6项通过。伪终端测试使用构造数据，仅验证接收软件，不能代替实物上传验收。

参考：[ST RM0008 USART1引脚与寄存器](https://www.st.com/resource/en/reference_manual/cd00171190-stm32f101-103-105-107-stm32f100-series-armbased-32bit-mcus-stmicroelectronics.pdf)。
