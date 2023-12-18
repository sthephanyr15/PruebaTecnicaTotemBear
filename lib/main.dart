import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:device_info/device_info.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identificador de dispositivo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Mobile ID'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? encryptedCode;
  late Database database;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    initDatabase();
  }

  Future<void> initDatabase() async {
    database = await openDatabase(
      join(await getDatabasesPath(), 'mobile_id.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE mobile_id(id INTEGER PRIMARY KEY, encrypted_code TEXT)',
        );
      },
      version: 1,
    );
    generateEncryptedCode();
  }

  Future<void> generateEncryptedCode() async {
    var deviceInfo = DeviceInfoPlugin();
    var androidInfo = await deviceInfo.androidInfo;

    var androidId = androidInfo.androidId;
    var model = androidInfo.model;
    var version = androidInfo.version;
    var data = "$androidId$model$version";
    var encryptedCode = sha256.convert(utf8.encode(data)).toString();
    await database.insert(
      'mobile_id',
      {'encrypted_code': encryptedCode},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    setState(() {
      this.encryptedCode = encryptedCode;
    });
  }

  Future<String> collectDeviceInfo() async {
    var deviceInfo = DeviceInfoPlugin();
    var androidInfo = await deviceInfo.androidInfo;
    var identifier = androidInfo.androidId;
    return identifier;
  }

  Future<void> saveToDatabase(String code) async {
    await database.insert(
      'mobile_id',
      {'encrypted_code': code},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getFromDatabase() async {
    List<Map<String, dynamic>> maps = await database.query('mobile_id');
    if (maps.isNotEmpty) {
      return maps.first['encrypted_code'].toString();
    }
    return null;
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> login(BuildContext context) async {
    String enteredCode = _controller.text;

    if (enteredCode.isNotEmpty) {
      String? storedCode = await getFromDatabase();

      if (storedCode == enteredCode) {
        showSnackBar(context, 'Inicio de sesion exitoso');
      } else {
        showErrorSnackBar(context, 'Inicio de sesion fallido');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un codigo válido')),
      );
    }
  }

  void _copyToClipboard(BuildContext context) {
    if (encryptedCode != null) {
      Clipboard.setData(ClipboardData(text: encryptedCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Código encriptado',
                hintText: 'Ingrese el código encriptado',
              ),
            ),
            SizedBox(height: 15),
            ElevatedButton(
                onPressed: () => login(context), child: Text('Iniciar sesión')),
            SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Código encriptado del dispositivo:',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 15),
                  Text(encryptedCode ?? 'generando codigo...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  GestureDetector(
                      onTap: (() => _copyToClipboard(context)),
                      child: const Text(
                        '(Toca para copiar):',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
