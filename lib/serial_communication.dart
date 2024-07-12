
// import 'dart:async';
// import 'dart:typed_data';
// import 'package:flutter_libserialport/flutter_libserialport.dart';

// class SerialCommunication {
//   SerialPort? _port;
//   late StreamController<Uint8List> _dataStreamController;

//   Stream<Uint8List> get dataStream => _dataStreamController.stream;

//   Future<void> initialize({
//     required String comPort,
//     required int baudRate,
//     required int dataBits,
//     required int stopBits,
//     required int parity,
//   }) async {
//     _dataStreamController = StreamController<Uint8List>();

//     _port = SerialPort(comPort);

//     final config = SerialPortConfig()
//       ..baudRate = baudRate
//       ..dataBits = dataBits
//       ..stopBits = stopBits
//       ..parity = SerialPortParity.values[parity];

//     if (!_port!.openReadWrite()) {
//       throw Exception("Failed to open port");
//     }

//     _port!.config = config;

//     _port!.inputStream?.listen((data) {
//       _dataStreamController.add(data);
//     });
//   }

//   void dispose() {
//     _port?.close();
//     _dataStreamController.close();
//   }
// }
