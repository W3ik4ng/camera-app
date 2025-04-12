import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
// import 'package:path/path.dart' as path;
// import 'package:path_provider/path_provider.dart' as pathProvider;
import 'package:flutter_vision/flutter_vision.dart';

// import 'dart:typed_data';
// import 'package:image/image.dart' as img;

// import 'dart:typed_data';

// import 'package:flutter/services.dart' show rootBundle;

// Future<void> checkFileAccess() async {
//   try {
//     // Load and read the labels file
//     String labelsContent = await rootBundle.loadString('assets/labels.txt');
//     print('Labels file content: $labelsContent');

//     // Load the YOLOv5 model file (just loading, not reading the content)
//     ByteData modelData = await rootBundle.load('assets/yolov5n.tflite');
//     print('YOLOv5 model file loaded successfully');

//     // If you need to read the content of the YOLOv5 model file:
//     // List<int> modelBytes = modelData.buffer.asUint8List();
//     // Do something with modelBytes...
//   } catch (e) {
//     print('Error accessing files: $e');
//   }
// }

class PhotoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  PhotoScreen(this.cameras);

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  late CameraController _cameraController;
  bool isCapturing = false;
  int _seclectedCameraIndex = 0;
  bool _isFrontCamera = false;
  bool _isFlashOn = false;
  String result = "";
  File? captureImage;
  AssetsAudioPlayer audioPlayer = AssetsAudioPlayer();

  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? cameraImage;
  bool isDetecting = false;
  bool isLoaded = false;

  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/yolov5s.tflite',
        modelVersion: "yolov5",
        quantization: false,
        numThreads: 1,
        useGpu: false);
    setState(() {
      isLoaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    vision = FlutterVision();

    _cameraController =
        CameraController(widget.cameras[0], ResolutionPreset.low);
    _cameraController.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
      });
      if (!mounted) {
        return;
      }
    });
  }

  @override
  void dispose() async {
    super.dispose();
    await vision.closeYoloModel();
    _cameraController.dispose();
  }

  void _toggleFlashLight() {
    if (_isFlashOn) {
      _cameraController.setFlashMode(FlashMode.off);
      setState(() {
        _isFlashOn = false;
      });
    } else {
      _cameraController.setFlashMode(FlashMode.torch);
      setState(() {
        _isFlashOn = true;
      });
    }
  }

  void _switchCamera() async {
    await _cameraController.dispose();
    if (_seclectedCameraIndex == 0) {
      _seclectedCameraIndex = 2;
    } else {
      _seclectedCameraIndex = 0;
    }

    _initCamera(_seclectedCameraIndex);
  }

  Future<void> _initCamera(int cameraIndex) async {
    _cameraController =
        CameraController(widget.cameras[cameraIndex], ResolutionPreset.low);
    try {
      await _cameraController.initialize();
      setState(() {
        if (cameraIndex == 0) {
          _isFrontCamera = false;
        } else {
          _isFrontCamera = true;
        }
      });
    } catch (e) {
      print("Error message: ${e}");
    }
    if (mounted) {
      setState(() {});
    }
  }

  void capturePhoto() async {
    _cameraController.takePicture().then((value) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageDisplayWidget(
            imagePath: value.path,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return SafeArea(
      child: Scaffold(
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  top: 50,
                  bottom: _isFrontCamera == false ? 150 : 0,
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: CameraPreview(_cameraController),
                  ),
                ),
                ...displayBoxesAroundRecognizedObjects(size),
                topPanel(),
                bottomPanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  Positioned bottomPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: _isFrontCamera == false ? Colors.black : Colors.transparent,
        ),
        child: Column(
          children: [
            // Padding(
            //   padding: const EdgeInsets.all(10.0),
            //   child: modePicker(),
            // ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(),
                      ),
                      cameraButton(),
                      Expanded(
                          child: GestureDetector(
                        onTap: () {
                          _switchCamera();
                        },
                        child: Icon(
                          Icons.cameraswitch_sharp,
                          color: Colors.white,
                          size: 40,
                        ),
                      ))
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Row modePicker() {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //     children: [
  //       Expanded(
  //         child: Center(
  //           child: Text(
  //             "Video",
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //       ),
  //       Expanded(
  //         child: Center(
  //           child: Text(
  //             "Photo",
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //       ),
  //       Expanded(
  //         child: Center(
  //           child: Text(
  //             "Pro Mode",
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Positioned topPanel() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            flashLight(),
            isDetecting
                ? IconButton(
                    onPressed: () async {
                      stopDetection();
                    },
                    icon: const Icon(
                      Icons.stop,
                      color: Colors.red,
                    ),
                    iconSize: 50,
                  )
                : IconButton(
                    onPressed: () async {
                      await startDetection();
                      // checkFileAccess();
                    },
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                    ),
                    iconSize: 50,
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await vision.yoloOnFrame(
      bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
      imageHeight: cameraImage.height,
      imageWidth: cameraImage.width,
      iouThreshold: 0.4,
      confThreshold: 0.4,
      classThreshold: 0.5,
    );

    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
        print(yoloResults);
        yoloResults.forEach((item) {
          if (item["tag"] == "person") {
            isDetecting = false;
            capturePhoto();
          }
        });
      });
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (_cameraController.value.isStreamingImages) {
      return;
    }
    await _cameraController.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  Expanded cameraButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          capturePhoto();
        },
        child: Center(
          child: Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                width: 4,
                color: Colors.white,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Padding qrScanner() {
  //   return Padding(
  //     padding: const EdgeInsets.all(8.0),
  //     child: GestureDetector(
  //       onTap: () {},
  //       child: Icon(
  //         Icons.qr_code_scanner,
  //         color: Colors.white,
  //       ),
  //     ),
  //   );
  // }

  Padding flashLight() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GestureDetector(
        onTap: () {
          _toggleFlashLight();
        },
        child: _isFlashOn == false
            ? Icon(
                Icons.flash_off,
                color: Colors.white,
              )
            : Icon(
                Icons.flash_on,
                color: Colors.white,
              ),
      ),
    );
  }
}

class ImageDisplayWidget extends StatelessWidget {
  final String imagePath;

  const ImageDisplayWidget({Key? key, required this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
              onPressed: () async {
                await GallerySaver.saveImage(imagePath);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save))
        ],
      ),
      body: Center(child: Image.file(File(imagePath))),
    );
  }
}
