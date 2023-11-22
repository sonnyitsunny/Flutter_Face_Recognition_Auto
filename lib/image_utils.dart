import 'package:camera/camera.dart';
import 'package:image/image.dart' as imageLib;

// ImageUtils 클래스
class ImageUtils {
  // CameraImage 객체를 YUV420 형식에서 imageLib.Image(RGB 형식)으로 변환
  static imageLib.Image? convertCameraImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA8888ToImage(cameraImage);
    } else {
      return null;
    }
  }

  // CameraImage 객체를 BGRA8888 형식에서 imageLib.Image(RGB 형식)으로 변환
  static imageLib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
    return imageLib.Image.fromBytes(
        cameraImage.planes[0].width ?? 0,
        cameraImage.planes[0].height ?? 0,
        cameraImage.planes[0].bytes,
        format: imageLib.Format.bgra);
  }

  // CameraImage 객체를 YUV420 형식에서 imageLib.Image(RGB 형식)으로 변환
  static imageLib.Image convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 0;

    final image = imageLib.Image(width, height);
    for (int w = 0; w < width; w++) {
      for (int h = 0; h < height; h++) {
        final int uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final int index = h * width + w;
        final y = cameraImage.planes[0].bytes[index];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.data[index] = yuv2rgb(y, u, v);
      }
    }
    return image;
  }

  // 단일 YUV 픽셀을 RGB로 변환
  static int yuv2rgb(int y, int u, int v) {
    int r = (y + v * 1436 / 1024 - 179).round();
    int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    int b = (y + u * 1814 / 1024 - 227).round();
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);
    return 0xff000000 | ((b << 16) & 0xff0000) | ((g << 8) & 0xff00) | (r & 0xff);
  }

  //CameraImage를 받아서 224x224 크기의 imageLib.Image로 변환
  static imageLib.Image? convertAndResizeCameraImage(CameraImage cameraImage) {
    var convertedImage = convertCameraImage(cameraImage);
    if (convertedImage != null) {
      
      return imageLib.copyResize(convertedImage, width: 224, height: 224);
      
    }
    return null;
  }




}

