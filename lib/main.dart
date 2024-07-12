import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Serial Port to HTTP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _baudRateController = TextEditingController();
  final TextEditingController _parityController = TextEditingController();
  final TextEditingController _stopBitsController = TextEditingController();
  final TextEditingController _startCharController = TextEditingController();
  final TextEditingController _endCharController = TextEditingController();
  final TextEditingController _httpPortController = TextEditingController();
  SerialPort? _serialPort;
  SerialPortReader? _reader;
  final List<String> _serialData = [];
  String? _selectedPort;
  List<String> _availablePorts = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _scanSerialPorts();
    _loadPreferences();
  }

  @override
  void dispose() {
    _serialPort?.close();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _baudRateController.text = prefs.getString('baudRate') ?? '';
    _parityController.text = prefs.getString('parity') ?? '';
    _stopBitsController.text = prefs.getString('stopBits') ?? '';
    _startCharController.text = prefs.getString('startChar') ?? '';
    _endCharController.text = prefs.getString('endChar') ?? '';
    _httpPortController.text = prefs.getString('httpPort') ?? '';
    _selectedPort = prefs.getString('selectedPort');
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baudRate', _baudRateController.text);
    await prefs.setString('parity', _parityController.text);
    await prefs.setString('stopBits', _stopBitsController.text);
    await prefs.setString('startChar', _startCharController.text);
    await prefs.setString('endChar', _endCharController.text);
    await prefs.setString('httpPort', _httpPortController.text);
    if (_selectedPort != null) {
      await prefs.setString('selectedPort', _selectedPort!);
    }
  }

  void _scanSerialPorts() {
    setState(() {
      _availablePorts = SerialPort.availablePorts;
    });
  }

  void _startSerialPort() {
    final portName = _selectedPort;
    if (portName == null) {
      print('No port selected');
      return;
    }

    final baudRate = int.tryParse(_baudRateController.text) ?? 9600;
    final parity = int.tryParse(_parityController.text) ??
        SerialPortParity.none; // Default to none
    final stopBits =
        int.tryParse(_stopBitsController.text) ?? 1; // Default to 1
    final startChar = _startCharController.text.isNotEmpty
        ? _startCharController.text.codeUnitAt(0)
        : null;
    final endChar = _endCharController.text.isNotEmpty
        ? _endCharController.text.codeUnitAt(0)
        : null;

    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      print('Failed to open port: ${SerialPort.lastError}');
      return;
    }

    port.config.baudRate = baudRate;
    port.config.parity = parity;
    port.config.stopBits = stopBits;
    _serialPort = port;

    final reader = SerialPortReader(port);
    _reader = reader;
    reader.stream.listen((Uint8List data) {
      final receivedData = String.fromCharCodes(data);
      if (startChar != null && endChar != null) {
        final startIndex = receivedData.indexOf(String.fromCharCode(startChar));
        final endIndex =
            receivedData.indexOf(String.fromCharCode(endChar), startIndex + 1);
        if (startIndex != -1 && endIndex != -1) {
          final parsedData = receivedData.substring(startIndex, endIndex + 1);
          setState(() {
            _serialData.add(parsedData);
          });
          print('Received: $parsedData');
        }
      } else {
        setState(() {
          _serialData.add(receivedData);
        });
        print('Received: $receivedData');
      }
    });
  }

  void _startHttpServer() async {
    final port = int.tryParse(_httpPortController.text) ?? 8080;

    final router = shelf_router.Router()
      ..get('/data', (shelf.Request request) {
        final responseData = _serialData.join('\n');
        return shelf.Response.ok(responseData);
      });

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router);

    final server = await shelf_io.serve(handler, '0.0.0.0', port);
    print('Serving at http://${server.address.host}:${server.port}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Port to HTTP Server'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButton<String>(
                value: _selectedPort,
                hint: const Text('Select Serial Port'),
                items: _availablePorts.map((String port) {
                  return DropdownMenuItem<String>(
                    value: port,
                    child: Text(port),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPort = newValue;
                  });
                },
              ),
              TextField(
                controller: _baudRateController,
                decoration: const InputDecoration(
                  labelText: 'Baud Rate (e.g., 9600)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _parityController,
                decoration: const InputDecoration(
                  labelText: 'Parity (0=None, 1=Odd, 2=Even, 3=Mark, 4=Space)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _stopBitsController,
                decoration: const InputDecoration(
                  labelText: 'Stop Bits (1 or 2)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _startCharController,
                decoration: const InputDecoration(
                  labelText: 'Start Character',
                ),
              ),
              TextField(
                controller: _endCharController,
                decoration: const InputDecoration(
                  labelText: 'End Character',
                ),
              ),
              TextField(
                controller: _httpPortController,
                decoration: const InputDecoration(
                  labelText: 'HTTP Port (e.g., 8080)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _savePreferences();
                      _startSerialPort();
                    },
                    child: const Text('Start Serial Port'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _savePreferences();
                      _startHttpServer();
                    },
                    child: const Text('Start HTTP Server'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _serialData.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_serialData[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
