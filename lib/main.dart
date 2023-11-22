import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';

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
  Timer? _timer; // 타이머를 위한 변수 추가

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
    _timer?.cancel(); // 타이머 정리
    super.dispose();
  }

  void _handleCameraStream() {
   setState(() {
     
   
    if (_controller.value.isStreamingImages) {
      // 스트리밍 중지 및 타이머 정리
      _controller.stopImageStream();
      _timer?.cancel();
    } else {
      // 스트림 시작 및 타이머 설정
      _controller.startImageStream((CameraImage image) {
        // 이미지 처리 로직은 타이머 콜백에서 실행
      });
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        // 타이머 콜백에서 프레임 이미지 처리
        // TODO: 여기서 이미지 처리 로직 구현
        print("Received image frame");
      });
    }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운전자 얼굴인식')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
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
