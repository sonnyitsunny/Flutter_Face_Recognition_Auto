import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter_application_2/image_utils.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

class InferenceResult {
  final String label; // 가장 확률이 높은 레이블
  final List<int> image; // 이미지 데이터
  InferenceResult(this.label, this.image);
}

class IsolateInference {
  static const String _debugName = "TFLITE_INFERENCE";
  final ReceivePort _receivePort = ReceivePort();
  late Isolate _isolate;
  late SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(entryPoint, _receivePort.sendPort,
        debugName: _debugName);
    _sendPort = await _receivePort.first;
  }

  Future<void> close() async {
    _isolate.kill();
    _receivePort.close();
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final InferenceModel isolateModel in port) {
      final img = ImageUtils.convertCameraImage(isolateModel.cameraImage!);
      if (img == null) throw '이미지 안들어옴';

      int width = img.width;
      int height = img.height;
      int offset = (width - height).abs() ~/ 2;
      final croppedImage = width > height
          ? image_lib.copyCrop(img, offset, 0, height, height)
          : image_lib.copyCrop(img, 0, offset, width, width);

      image_lib.Image imageInput = image_lib.copyResize(
        croppedImage,
        width: isolateModel.inputShape[1],
        height: isolateModel.inputShape[2],
      );

      if (Platform.isAndroid) {
        imageInput = image_lib.copyRotate(imageInput, 270);
      }

      final imageMatrix = List.generate(
        imageInput.height,
        (y) => List.generate(
          imageInput.width,
          (x) {
            final pixel = imageInput.getPixel(x, y);
            return [
              image_lib.getRed(pixel),
              image_lib.getGreen(pixel),
              image_lib.getBlue(pixel)
            ];
          },
        ),
      );

      final input = [imageMatrix];
      final output = [List<double>.filled(isolateModel.outputShape[1], .0)];
      final interpreter = Interpreter.fromAddress(
        isolateModel.interpreterAddress,
      );
      interpreter.run(input, output);
      final result = output.first;

      double maxProb = 0.0;
      String topLabel = '';
      for (int i = 0; i < result.length; i++) {
        if (result[i] > maxProb) {
          maxProb = result[i];
          topLabel = isolateModel.labels[i];
        }
      }

      final infResult = InferenceResult(topLabel, image_lib.encodePng(imageInput));
      isolateModel.responsePort.send(infResult);
    }
  }
}

class InferenceModel {
  CameraImage? cameraImage;
  int interpreterAddress;
  List<String> labels;
  List<int> inputShape;
  List<int> outputShape;
  late SendPort responsePort;

  InferenceModel(
    this.cameraImage,
    this.interpreterAddress,
    this.labels,
    this.inputShape,
    this.outputShape,
  );
}