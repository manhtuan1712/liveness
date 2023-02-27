import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_face_api/face_api.dart' as Regula;
import 'package:image_picker/image_picker.dart';

void main() => runApp(new MaterialApp(home: new MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var image1 = new Regula.MatchFacesImage();

  var image2 = new Regula.MatchFacesImage();

  var img1 = Image.asset('assets/images/portrait.png');

  var img2 = Image.asset('assets/images/portrait.png');

  String _similarity = 'nil';

  String _liveNess = 'nil';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {}

  showAlertDialog(BuildContext context, bool first) => showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text("Select option"),
          actions: [
            TextButton(
              child: Text("Use gallery"),
              onPressed: () {
                ImagePicker().pickImage(source: ImageSource.gallery).then(
                      (value) => {
                        _setImage(first, io.File(value!.path).readAsBytesSync(),
                            Regula.ImageType.PRINTED)
                      },
                    );
              },
            ),
            TextButton(
              child: Text("Use camera"),
              onPressed: () {
                Regula.FaceSDK.presentFaceCaptureActivity().then(
                  (result) => _setImage(
                    first,
                    base64Decode(
                      Regula.FaceCaptureResponse.fromJson(json.decode(result))!
                          .image!
                          .bitmap!
                          .replaceAll(
                            "\n",
                            "",
                          ),
                    ),
                    Regula.ImageType.LIVE,
                  ),
                );
                Navigator.pop(context);
              },
            )
          ],
        ),
      );

  _setImage(bool first, Uint8List? imageFile, int type) {
    if (imageFile == null) return;
    setState(() => _similarity = "nil");
    if (first) {
      image1.bitmap = base64Encode(imageFile);
      image1.imageType = type;
      setState(() {
        img1 = Image.memory(imageFile);
        _liveNess = "nil";
      });
    } else {
      image2.bitmap = base64Encode(imageFile);
      image2.imageType = type;
      setState(() => img2 = Image.memory(imageFile));
    }
  }

  _clearResults() {
    setState(() {
      img1 = Image.asset('assets/images/portrait.png');
      img2 = Image.asset('assets/images/portrait.png');
      _similarity = "nil";
      _liveNess = "nil";
    });
    image1 = new Regula.MatchFacesImage();
    image2 = new Regula.MatchFacesImage();
  }

  _matchFaces() {
    if (image1.bitmap == null ||
        image1.bitmap == "" ||
        image2.bitmap == null ||
        image2.bitmap == "") return;
    setState(() => _similarity = "Processing...");
    var request = new Regula.MatchFacesRequest();
    request.images = [image1, image2];
    Regula.FaceSDK.matchFaces(jsonEncode(request)).then(
      (value) {
        var response = Regula.MatchFacesResponse.fromJson(json.decode(value));
        Regula.FaceSDK.matchFacesSimilarityThresholdSplit(
                jsonEncode(response!.results), 0.75)
            .then(
          (str) {
            var split = Regula.MatchFacesSimilarityThresholdSplit.fromJson(
                json.decode(str));
            setState(() => _similarity = split!.matchedFaces.length > 0
                ? ((split.matchedFaces[0]!.similarity! * 100)
                        .toStringAsFixed(2) +
                    "%")
                : "error");
          },
        );
      },
    );
  }

  _doLiveNess() => Regula.FaceSDK.startLiveness().then(
        (value) {
          var result = Regula.LivenessResponse.fromJson(json.decode(value));
          _setImage(
            true,
            base64Decode(
              result!.bitmap!.replaceAll(
                "\n",
                "",
              ),
            ),
            Regula.ImageType.LIVE,
          );
          setState(
              () => _liveNess = result.liveness == 0 ? "passed" : "unknown");
        },
      );

  Widget _createButton(String text, VoidCallback onPress) => Container(
        child: TextButton(
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all<Color>(Colors.blue),
            backgroundColor: MaterialStateProperty.all<Color>(Colors.black12),
          ),
          onPressed: onPress,
          child: Text(
            text,
          ),
        ),
        width: 250,
      );

  Widget _createImage(image, VoidCallback onPress) => Material(
        child: InkWell(
          onTap: onPress,
          child: Container(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Image(height: 150, width: 150, image: image),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 100),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _createImage(img1.image, () => showAlertDialog(context, true)),
              _createImage(img2.image, () => showAlertDialog(context, false)),
              Container(margin: EdgeInsets.fromLTRB(0, 0, 0, 15)),
              _createButton("Match", () => _matchFaces()),
              _createButton("Liveness", () => _doLiveNess()),
              _createButton("Clear", () => _clearResults()),
              Container(
                margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Similarity: " + _similarity,
                        style: TextStyle(fontSize: 18)),
                    Container(
                      margin: EdgeInsets.fromLTRB(
                        20,
                        0,
                        0,
                        0,
                      ),
                    ),
                    Text(
                      "Liveness: " + _liveNess,
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
