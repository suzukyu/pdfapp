import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Draw Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DrawPage(title: 'Flutter Draw Demo'),
    );
  }
}

class DrawPage extends StatefulWidget {
  const DrawPage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  var _rectPos = const Offset(0, 0);
  //Uint8List? _bytes;
  ui.Image? _uiimage;
  Image? _image;

  static double _windowsizescale = 380;
  static double _windowsizeall = 250;

  File? _file;
  Uint8List? _bytes;
  Uint8List? _pdfbytes;
  int _pagenum = 1;
  int _maxpagenum = 1;
  double _width = 0;
  double _height = 0;
  double _allscale = 1.0;
  double _allwidth = 0;
  double _allheight = 0;
  double _allwidth_offset = 0;
  double _allheight_offset = 0;
  final double _scale = 100.0 * _windowsizescale / _windowsizeall;

  FilePickerResult? _result;
  TransformationController _controller = TransformationController();

  void _savePicture(Uint8List bytes) async {
    ui.Image? tmp = await decodeImageFromList(bytes);
    setState(() {
      _bytes = bytes;
      _uiimage = tmp;
      _image = Image.memory(bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 380,
          height: 720,
          color: Colors.teal,
          child: Column(
            children: [
              Text(""),
              InteractiveViewer(
                transformationController: _controller,
                constrained: true,
                panEnabled: true,
                scaleEnabled: true,
                boundaryMargin: const EdgeInsets.all(32.0),
                minScale: 1.0,
                maxScale: 20.0,
                child: (_image != null)
                    ? Container(
                        width: _windowsizescale,
                        height: _windowsizescale,
                        child: _image!,
                      )
                    : Container(
                        width: _windowsizescale,
                        height: _windowsizescale,
                        color: Colors.blueGrey,
                      ),
              ),
              Text(_rectPos.toString()),
                GestureDetector(
                  onTapUp: (TapUpDetails details) {
                    setState(() {
                      _rectPos = details.localPosition;
                      //double scale = _scale * _pdfscale;
                      //double offx = _rectPos.dx  / _pdfscale;
                      //double offy = _rectPos.dy  / _pdfscale;
                      double scale = 10.0;
                      double offx = (_rectPos.dx + _allwidth_offset / 2) *
                          (_windowsizescale / _windowsizeall);
                      double offy = (_rectPos.dy + _allheight_offset / 2) *
                          (_windowsizescale / _windowsizeall);
                      print("${scale}:${-offx}:${-offy}");
                      var m = Matrix4.identity()
                        ..translate(-offx * scale, -offy * scale, 0.0)
                        ..scale(scale, scale, 1.0);
                      _controller.value = m;
                    });
                  },
                  child: (_uiimage != null)
                      ? Container(
                          width: _windowsizeall,
                          height: _windowsizeall,
                          child: CustomPaint(
                            size: const ui.Size(300, 300),
                            painter: FixedImagePainter(_uiimage!),
                          ))
                      : Container(
                          width: _windowsizeall,
                          height: _windowsizeall,
                          color: Colors.blueGrey,
                        ),
                ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () async {
                      pickFile();
                    },
                    child: const Text('Pick File'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_result != null && _pagenum > 1) {
                        _bytes = await createPdfDocumentFromMemory(
                            _pdfbytes!, --_pagenum);
                      }
                      _savePicture(_bytes!);
                      //setState(() {});
                    },
                    child: const Text('prev'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_result != null && _pagenum < _maxpagenum) {
                        _bytes = await createPdfDocumentFromMemory(
                            _pdfbytes!, ++_pagenum);
                      }
                      _savePicture(_bytes!);
                      //setState(() {});
                    },
                    child: const Text('next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> getPictureBytes() async {
    ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    Uint8List bytes = await image!.readAsBytes();
    return bytes;
  }

  Future<void> pickFile() async {
    _pagenum = 1;
    try {
      _result = await FilePicker.platform.pickFiles();
      if (_result != null) {
        if (!kIsWeb) {
          _file = File(_result!.files.single.path!);
          _pdfbytes = await _file!.readAsBytes();
        } else {
          _pdfbytes = _result!.files.first.bytes!;
        }
        _bytes = await createPdfDocumentFromMemory(_pdfbytes!, _pagenum);
        //setState(() {});
        _savePicture(_bytes!);
      } else {
        // User canceled the picker
      }
    } catch (_) {}
  }

  Future<Uint8List?> createPdfDocumentFromMemory(
      Uint8List pdfData, int num) async {
    // PDFデータをPDFXドキュメントに変換
    final PdfDocument pdfDocument = await PdfDocument.openData(pdfData);
    Uint8List? result;

    final PdfPage pdfPage = await pdfDocument.getPage(num);
    _maxpagenum = pdfDocument.pagesCount;
    _width = pdfPage.width * 2.0;
    _height = pdfPage.height * 2.0;
    if (_width > _height) {
      _allscale = _windowsizeall / _width;
      _allwidth = _width * _allscale;
      _allheight = _height * _allscale;
      _allwidth_offset = 0;
      _allheight_offset = _allwidth - _allheight + 1;
    } else {
      _allscale = _windowsizeall / _height;
      _allwidth = _width * _allscale;
      _allheight = _height * _allscale;
      _allwidth_offset = _allheight - _allwidth + 1;
      _allheight_offset = 0;
    }
    _allscale =
        _width > _height ? _windowsizeall / _width : _windowsizeall / _height;
    _allwidth = _width * _allscale;
    _allheight = _height * _allheight;

    print("$num:${pdfDocument.pagesCount}:$_width:$_height:$_allscale");
    final pdfPageImage = await pdfPage.render(
      width: _width,
      height: _height,
      //format: PdfPageImageFormat.jpeg,
      format: PdfPageImageFormat.png,
      backgroundColor: '#FFFFFF',
    );
    result = pdfPageImage!.bytes;

    return result;
  }
}

class FixedImagePainter extends CustomPainter {
  final ui.Image image;
  FixedImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    //size.w == size.h
    double newWidth = 0;
    double newHeight = 0;

    if (image.width > image.height) {
      newWidth = size.width;
      newHeight = image.height * (size.width / image.width);
    } else {
      newHeight = size.height;
      newWidth = image.width * (size.height / image.height);
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, newWidth, newHeight),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(FixedImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}
