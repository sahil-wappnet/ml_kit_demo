import 'dart:io';
import 'dart:ui' as ui; // Import dart:ui
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image_picker/image_picker.dart';

class FaceSwapScreen extends StatefulWidget {
  @override
  _FaceSwapScreenState createState() => _FaceSwapScreenState();
}

class _FaceSwapScreenState extends State<FaceSwapScreen> {
  final FaceMeshDetector _meshDetector =
      FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  bool _canProcess = true;
  bool _isBusy = false;
  File? _image1;
  File? _image2;
  CustomPaint? _customPaint;

  @override
  void dispose() {
    _canProcess = false;
    _meshDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Face Swap')),
      body: Column(
        children: [
          if (_image1 != null) Image.file(_image1!),
          ElevatedButton(
            onPressed: () => _pickImage(true),
            child: Text('Pick Image 1'),
          ),
          if (_image2 != null) Image.file(_image2!),
          ElevatedButton(
            onPressed: () => _pickImage(false),
            child: Text('Pick Image 2'),
          ),
          if (_customPaint != null) _customPaint!,
        ],
      ),
    );
  }

  Future<void> _pickImage(bool isFirstImage) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        if (isFirstImage) {
          _image1 = File(pickedImage.path);
        } else {
          _image2 = File(pickedImage.path);
          _processImages();
        }
      });
    }
  }

  Future<void> _processImages() async {
    if (_image1 != null && _image2 != null) {
      final meshes1 = await _meshDetector.processImage(InputImage.fromFile(_image1!));
      final meshes2 = await _meshDetector.processImage(InputImage.fromFile(_image2!));

      if (meshes1.isNotEmpty && meshes2.isNotEmpty) {
        final painter = FaceSwapPainter(meshes1.first, _image2!);
        _customPaint = CustomPaint(painter: painter);
      }
    }
    setState(() {});
  }
}

class FaceSwapPainter extends CustomPainter {
  final FaceMesh detectedFace;
  final File image2;

  FaceSwapPainter(this.detectedFace, this.image2);

  @override
  void paint(Canvas canvas, Size size)async {
    final imageSize = Size(25, 25);

    // Load image2
    final imageBytes = await image2.readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Draw image2 onto the canvas
    final imageRect = Rect.fromPoints(Offset(0, 0), Offset(imageSize.width, imageSize.height));
    canvas.drawImageRect(
      image,
      imageRect,
      imageRect,
      Paint(),
    );

    for (final FaceMeshTriangle triangle in detectedFace.triangles) {
      final List<Offset> cornerPoints = <Offset>[];
      for (final FaceMeshPoint point in triangle.points) {
        final double x = point.x.toDouble();
        final double y = point.y.toDouble();
        cornerPoints.add(Offset(x, y));
      }

      final path = Path()
        ..moveTo(cornerPoints[0].dx, cornerPoints[0].dy)
        ..lineTo(cornerPoints[1].dx, cornerPoints[1].dy)
        ..lineTo(cornerPoints[2].dx, cornerPoints[2].dy)
        ..close();

      final paint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(FaceSwapPainter oldDelegate) {
    return true;
  }
}
