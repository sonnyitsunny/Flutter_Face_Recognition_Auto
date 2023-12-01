import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/isolate_inference.dart';
import 'package:flutter_application_2/tflite.dart';
import 'package:audioplayers/audioplayers.dart';






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
  CameraImage? _lastImage; // 마지막으로 스트리밍된 이미지를 저장할 변수

  final classifier = Classifier();

  InferenceResult? inferenceResult;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
    classifier.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    classifier.close();
    super.dispose();
  }

  void _handleCameraStream() {
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream();
    } else {
      _controller.startImageStream((CameraImage image) {
        _lastImage = image; // 스트리밍된 마지막 이미지 저장
        processCameraImage(_lastImage!);
      });
    }
  }
final audioPlayer = AudioPlayer();

Future<void> playSound(String label) async {
  switch (label) {
    case '응급상황':
      audioPlayer.play(AssetSource('sounds/negative.mp3')); // AudioCache를 사용하여 오디오 재생
      break;
    case '전방주시태만':
      audioPlayer.play(AssetSource('sounds/negative.mp3'));
      break;
    case '졸음주의':
      audioPlayer.play(AssetSource('sounds/negative.mp3'));
      break;
    // 기타 레이블에 대한 케이스
    default:
      // 아무 소리도 재생하지 않음
      break;
  }
}


  Future<void> processCameraImage(CameraImage cameraImage) async {
    if (!classifier.isInitialized || isProcessing) return;
    isProcessing = true;
    inferenceResult = await classifier.inferenceCameraFrame(cameraImage);
    print('${inferenceResult?.label}');
    if (inferenceResult != null && inferenceResult!.label != null) {
    playSound(inferenceResult!.label);
  }
    
    isProcessing = false;
    setState(() {});
  }

  Color _getTextColor(String? label) {
  switch (label) {
    case '정상':
      return Colors.green;
    case '전방주시태만':
      return Colors.red;
    case '응급상황':
      return Colors.red;
    case '졸음주의':
      return Colors.red;
    default:
      return Colors.white; // 기본 색상
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운전자 얼굴인식')),
      body: Column(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CameraPreview(_controller),
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Text(
            inferenceResult?.label ?? '시스템 대기',
            style: TextStyle(fontSize: 24, color:_getTextColor(inferenceResult?.label),
            ),
          ),
          ElevatedButton(
            onPressed: _handleCameraStream,
            child: Text(_controller.value.isStreamingImages ? "정지" : "시작"),
          ),
          if (inferenceResult != null)
            Image.memory(
              Uint8List.fromList(inferenceResult!.image),
            ),
        ],
      ),
    );
  }
}
