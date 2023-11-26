import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter_application_2/image_utils.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

class InferenceResult {
  final Map<String, double> prob;
  final List<int> image;
  InferenceResult(this.prob, this.image);
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

      // 이미지의 중앙을 기준으로 1:1 비율로 잘라냅니다.
      int width = img.width;
      int height = img.height;
      int offset = (width - height).abs() ~/ 2;
      // 가로가 세로보다 길 경우, 가로를 잘라냅니다.
      final croppedImage = width > height
          ? image_lib.copyCrop(img, offset, 0, height, height)
          : image_lib.copyCrop(img, 0, offset, width, width);
      // 세로가 가로보다 길 경우, 세로를 잘라냅니다.

      // resize original image to match model shape.
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

      // Set tensor input [1, 224, 224, 3]
      final input = [imageMatrix];
      // Set tensor output [1, 4]
      final output = [List<double>.filled(isolateModel.outputShape[1], .0)];
      // // Run inference
      final interpreter = Interpreter.fromAddress(
        isolateModel.interpreterAddress,
      );
      interpreter.run(input, output);
      // Get first output tensor
      final result = output.first;
      print("result: $result");
      double maxScore = result.reduce((a, b) => a + b);
      // Set classification map {label: points}
      var classification = <String, double>{};
      for (var i = 0; i < result.length; i++) {
        if (result[i] != 0) {
          // Set label: points
          classification[isolateModel.labels[i]] =
              result[i].toDouble() / maxScore.toDouble();
        }
      }

      final infResult =
          InferenceResult(classification, image_lib.encodePng(imageInput));
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
