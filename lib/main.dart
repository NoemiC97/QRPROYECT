import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'QR Scanner App',
    theme: ThemeData(
      primaryColor: Colors.green,
      accentColor: Colors.grey,
    ),
    home: QRScannerApp(),
  ));
}

class QRScannerApp extends StatefulWidget {
  @override
  _QRScannerAppState createState() => _QRScannerAppState();
}

class _QRScannerAppState extends State<QRScannerApp>
    with TickerProviderStateMixin {
  final GlobalKey qrKey =
      GlobalKey(debugLabel: 'QR'); // Clave global para el escáner QR
  QRViewController? controller; // Controlador del escáner QR
  AnimationController?
      lineAnimationController; // Controlador de animación de la línea de escaneo
  late Animation<double> lineAnimation; // Animación de la línea de escaneo
  bool scanning = true; // Variable para habilitar/deshabilitar el escaneo
  bool flashEnabled =
      false; // Variable para habilitar/deshabilitar el flash de la cámara

  @override
  void initState() {
    super.initState();
    _checkCameraPermission(); // Verificar el permiso de la cámara
    lineAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    lineAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: lineAnimationController!,
      curve: Curves.linear,
    ));
    lineAnimationController!
        .repeat(reverse: true); // Repetir la animación de la línea de escaneo
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (result.isDenied) {
        _showPermissionDeniedDialog(); // Mostrar un diálogo si se deniega el permiso de la cámara
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permiso denegado'),
          content: const Text('No se ha concedido el permiso de la cámara.'),
          actions: [
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('QR Scanner'),
        actions: [
          IconButton(
            icon: Icon(
              flashEnabled ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                flashEnabled = !flashEnabled;
                controller?.toggleFlash();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildQRView(context), // Construir la vista del escáner QR
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        scanning = !scanning;
                        if (scanning) {
                          controller?.resumeCamera();
                        } else {
                          controller?.pauseCamera();
                        }
                      });
                    },
                    backgroundColor: Theme.of(context).accentColor,
                    child: Icon(scanning ? Icons.stop : Icons.play_arrow),
                  ),
                ],
              ),
            ),
          ),
          Align(
            //alineacion del boton de la galeria
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0, right: 16.0),
              child: FloatingActionButton(
                onPressed: _pickImageFromGallery,
                backgroundColor: Theme.of(context).accentColor,
                child: const Icon(Icons.photo_library),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRView(BuildContext context) {
    return Stack(
      children: [
        QRView(
          key: qrKey, //como se visualiza el cuadro del scanner
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Theme.of(context).accentColor,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: MediaQuery.of(context).size.width * 0.8,
          ),
        ),
        Positioned(
          bottom: 180.0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(8.0),
            child: const Center(
              child: Text(
                'Coloque el código dentro del recuadro',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white60,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: lineAnimationController!,
          builder: (context, child) {
            return Positioned(
              top: lineAnimation.value *
                      (MediaQuery.of(context).size.width * 0.8 - 10 - 10 - 00) +
                  218,
              left: 50,
              right: 50,
              child: Container(
                height: 2,
                color: Colors.green,
              ),
            );
          },
        ),
      ],
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      _launchURL(scanData.code); // Abrir el enlace escaneado
    });
    controller.getFlashStatus().then((status) {
      setState(() {
        flashEnabled = status!;
      });
    });
  }

  Future<void> _launchURL(String? code) async {
    if (code != null && code.isNotEmpty) {
      try {
        await launch(
            code); // Abrir el enlace utilizando la biblioteca url_launcher
      } catch (e) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  child: Text('Cerrar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final imagePath = image.path;
      final imageBytes = await File(imagePath).readAsBytes();
      print('Image path: $imagePath');
      print('Image bytes: $imageBytes');
      final qrCode = await FlutterBarcodeScanner.scanBarcode(
        String.fromCharCodes(imageBytes),
        '#000000',
        true,
        ScanMode.QR,
      );
      print('QR Code: $qrCode');
      if (qrCode != '-1') {
        _launchURL(qrCode);
      }
    }
  }

  @override
  void dispose() {
    lineAnimationController?.dispose();
    controller?.dispose();
    super.dispose();
  }
}
