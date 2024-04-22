import 'package:flutter/material.dart';
import '../model_viewer/model_viewer.dart';
import '../model_viewer/model_viewer_web.dart';
import '../model_viewer/shim/dart_html_fake.dart'
    if (dart.library.html) 'dart:html';

void main() => runApp(const MyApp());

String js = '''
const modelViewerColor = document.querySelector("model-viewer#color");

document.querySelector('#color-controls').addEventListener('click', (event) => {
  const colorString = event.target.dataset.color;
  const [material] = modelViewerColor.model.materials;
  material.pbrMetallicRoughness.setBaseColorFactor(colorString);
});

''';

String html = '''
  <div class="controls" id="color-controls">
    <button data-color="#ff0000">Red</button>
    <button data-color="#00ff00">Green</button>
    <button data-color="#0000ff">Blue</button>
  </div>
''';

NodeValidatorBuilder myNodeValidatorBuilder = defaultNodeValidatorBuilder
  ..allowElement(
    'button',
    attributes: ['data-color'],
    uriPolicy: AllowAllUri(),
  );

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Model Viewer')),
        body: ModelViewer(
          id: 'color',
          src: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
          alt: 'A 3D model of an astronaut',
          touchAction: TouchAction.panY,
          ar: true,
          orientation: '20deg 0 0',
          relatedJs: js,
          innerModelViewerHtml: html,
          overwriteNodeValidatorBuilder: myNodeValidatorBuilder,
        ),
      ),
    );
  }
}
