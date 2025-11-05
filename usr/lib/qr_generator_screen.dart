import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _vpaController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  final GlobalKey _qrKey = GlobalKey();
  String? _upiUri;

  String _buildUpiUri() {
    final pa = _vpaController.text.trim();
    final pn = _nameController.text.trim();
    final am = _amountController.text.trim();
    final tn = _noteController.text.trim();

    final queryParameters = {
      'pa': pa,
      if (pn.isNotEmpty) 'pn': pn,
      if (am.isNotEmpty) 'am': am,
      if (tn.isNotEmpty) 'tn': tn,
      'cu': 'INR',
    };

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    ).toString();
  }

  void _generateQr() {
    if (_vpaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your UPI ID (VPA)')),
      );
      return;
    }
    setState(() {
      _upiUri = _buildUpiUri();
    });
  }

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> _downloadQr() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
        final pngBytes = await _capturePng();
        if (pngBytes != null) {
          final result = await ImageGallerySaver.saveImage(
            pngBytes,
            quality: 100,
            name: "upi_qr_${DateTime.now().millisecondsSinceEpoch}",
          );
          if (mounted && result['isSuccess']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR Code saved to Gallery!')),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save QR Code.')),
            );
          }
        }
    } else if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission is required to save QR code.')),
         );
    }
  }

  Future<void> _shareQr() async {
    final pngBytes = await _capturePng();
    if (pngBytes != null) {
      final directory = await getTemporaryDirectory();
      final file = await File('${directory.path}/upi_qr.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR to pay via UPI',
        subject: 'UPI QR Code',
      );
    }
  }

  @override
  void dispose() {
    _vpaController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI QR Generator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTextField(_vpaController, 'Enter your UPI ID (e.g. name@upi)'),
              const SizedBox(height: 10),
              _buildTextField(_nameController, 'Name (optional)'),
              const SizedBox(height: 10),
              _buildTextField(_amountController, 'Amount ₹ (optional)',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _buildTextField(_noteController, 'Note (optional)'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _generateQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Generate QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              if (_upiUri != null)
                Column(
                  children: [
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        child: QrImageView(
                          data: _upiUri!,
                          version: QrVersions.auto,
                          size: 250.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _downloadQr,
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          onPressed: _shareQr,
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
