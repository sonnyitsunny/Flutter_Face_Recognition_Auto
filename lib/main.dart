import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:image/image.dart' as imageLib;
import 'image_utils.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => throw Exception("전면 카메라 이용불가"),
  );

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(camera: firstCamera),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key, required this.camera});
  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  Timer? _timer;
  CameraImage? _lastImage; // 마지막으로 스트리밍된 이미지를 저장할 변수

  

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _handleCameraStream() {
    setState(() {
      if (_controller.value.isStreamingImages) {
        _controller.stopImageStream();
        _timer?.cancel();
      } else {
        _controller.startImageStream((CameraImage image) {
          _lastImage = image; // 스트리밍된 마지막 이미지 저장
        });

        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (_lastImage != null) {
              print("Received image frame");
            processCameraImage(_lastImage!); // 1초마다 마지막으로 받은 이미지 처리
          }
        });
      }
    });
  }
  // 리사이즈한 이미지를 위한 변수
  imageLib.Image? _resizedImage;


  void processCameraImage(CameraImage cameraImage) {
    imageLib.Image? convertedImage = ImageUtils.convertCameraImage(cameraImage);
    if (convertedImage != null) {
      convertedImage = img.copyRotate(convertedImage, 270);
      imageLib.Image resizedImage = imageLib.copyResize(convertedImage, width: 224, height: 224);
      
      // 리사이즈한 이미지 저장
      setState(() {
        _resizedImage = resizedImage; 
      });
      
      
      print("Resized image dimensions: ${resizedImage.width}x${resizedImage.height}");
      // 여기서 리사이즈된 이미지로 추가 작업 수행
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운전자 얼굴인식')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
  return SingleChildScrollView(
    child: Column(
      children: [
        Container(
          height: 200, // 고정된 높이 지정
          child: CameraPreview(_controller),
        ),
        SizedBox(height: 20),
        if (_resizedImage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.memory(Uint8List.fromList(imageLib.encodeJpg(_resizedImage!))),
          ),
      ],
    ),
  );
} else {
  return const Center(child: CircularProgressIndicator());
}
        },
      ),



      bottomNavigationBar: Container(
        height: 50.0,
        child: Center(
          child: Text(
            '시스템 시작',
            style: TextStyle(fontSize: 30, color: Colors.white),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 50.0),
        child: FloatingActionButton(
          onPressed: _handleCameraStream,
          child: Icon(
            _controller.value.isStreamingImages ? Icons.stop : Icons.camera_alt,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
