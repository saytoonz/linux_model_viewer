import 'package:flutter/material.dart';
import '../model_viewer/model_viewer.dart';

void main() => runApp(const MyApp());

String js = r'''
const models = ['shishkebab.glb', 'Astronaut.glb'];
const toggleModel = document.querySelector('#toggle-model');
let j = 0;
setInterval(() => toggleModel.setAttribute('src', `https://modelviewer.dev/shared-assets/models/${models[j++ % 2]}`), 2000);
''';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Model Viewer')),
        body: ModelViewer(
          id: 'toggle-model',
          src: 'https://modelviewer.dev/shared-assets/models/shishkebab.glb',
          alt: 'A 3D model of a shishkebab',
          shadowIntensity: 1,
          autoRotate: true,
          relatedJs: js,
        ),
      ),
    );
  }
}
