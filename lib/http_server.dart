
import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class HttpServer {
  final _router = Router();
  List<Uint8List> _data = [];

  HttpServer() {
    _router.get('/data', _getData);
  }

  void start() async {
    var handler = const Pipeline().addMiddleware(logRequests()).addHandler(_router);
    await io.serve(handler, 'localhost', 8080);
    print('HTTP server listening on http://localhost:8080');
  }

  Response _getData(Request request) {
    return Response.ok(jsonEncode(_data), headers: {'Content-Type': 'application/json'});
  }

  void addData(Uint8List data) {
    _data.add(data);
  }
}
