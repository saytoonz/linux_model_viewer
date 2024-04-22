import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:convert' show utf8;
import './widget/html_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'entity/model_viewer_plus.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_linux_webview/flutter_linux_webview.dart';

class ModelViewerState extends State<ModelViewer> with WidgetsBindingObserver {
  HttpServer? _proxy;

  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  late String _proxyURL;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initProxy();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_proxy != null) {
      _proxy!.close(force: true);
      _proxy = null;
    }
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await LinuxWebViewPlugin.terminate();
    return AppExitResponse.exit;
  }
  // ===== end: For Flutter 3.10 or later =====

  @override
  Widget build(final BuildContext context) {
    return WebView(
      initialUrl: 'flutter.dev',
      javascriptMode: JavascriptMode.unrestricted,
      backgroundColor: Colors.transparent,
      onWebViewCreated: (WebViewController controller) async {
        _controller.complete(controller);
        await controller.loadUrl(_proxyURL);
      },
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }

  String _buildHTML(String htmlTemplate) {
    return HTMLBuilder.build(
      htmlTemplate: htmlTemplate,
      src: '/model',
      alt: widget.alt,
      poster: widget.poster,
      loading: widget.loading,
      reveal: widget.reveal,
      withCredentials: widget.withCredentials,
      // AR Attributes
      ar: widget.ar,
      arModes: widget.arModes,
      arScale: widget.arScale,
      arPlacement: widget.arPlacement,
      iosSrc: widget.iosSrc,
      xrEnvironment: widget.xrEnvironment,
      // Cameras Attributes
      cameraControls: widget.cameraControls,
      disablePan: widget.disablePan,
      disableTap: widget.disableTap,
      touchAction: widget.touchAction,
      disableZoom: widget.disableZoom,
      orbitSensitivity: widget.orbitSensitivity,
      autoRotate: widget.autoRotate,
      autoRotateDelay: widget.autoRotateDelay,
      rotationPerSecond: widget.rotationPerSecond,
      interactionPrompt: widget.interactionPrompt,
      interactionPromptStyle: widget.interactionPromptStyle,
      interactionPromptThreshold: widget.interactionPromptThreshold,
      cameraOrbit: widget.cameraOrbit,
      cameraTarget: widget.cameraTarget,
      fieldOfView: widget.fieldOfView,
      maxCameraOrbit: widget.maxCameraOrbit,
      minCameraOrbit: widget.minCameraOrbit,
      maxFieldOfView: widget.maxFieldOfView,
      minFieldOfView: widget.minFieldOfView,
      interpolationDecay: widget.interpolationDecay,
      // Lighting & Env Attributes
      skyboxImage: widget.skyboxImage,
      environmentImage: widget.environmentImage,
      exposure: widget.exposure,
      shadowIntensity: widget.shadowIntensity,
      shadowSoftness: widget.shadowSoftness,
      // Animation Attributes
      animationName: widget.animationName,
      animationCrossfadeDuration: widget.animationCrossfadeDuration,
      autoPlay: widget.autoPlay,
      // Materials & Scene Attributes
      variantName: widget.variantName,
      orientation: widget.orientation,
      scale: widget.scale,
      // CSS Styles
      backgroundColor: widget.backgroundColor,
      // Annotations CSS
      minHotspotOpacity: widget.minHotspotOpacity,
      maxHotspotOpacity: widget.maxHotspotOpacity,
      // Others
      innerModelViewerHtml: widget.innerModelViewerHtml,
      relatedCss: widget.relatedCss,
      relatedJs: widget.relatedJs,
      id: widget.id,
      debugLogging: widget.debugLogging,
    );
  }

  Future<void> _initProxy() async {
    final url = Uri.parse(widget.src);
    _proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    setState(() {
      final host = _proxy!.address.address;
      final port = _proxy!.port;
      _proxyURL = 'http://$host:$port/';
    });

    _proxy!.listen((request) async {
      final response = request.response;

      switch (request.uri.path) {
        case '/':
        case '/index.html':
          final htmlTemplate =
              await rootBundle.loadString('assets/template.html');
          final html = utf8.encode(_buildHTML(htmlTemplate));
          response
            ..statusCode = HttpStatus.ok
            ..headers.add('Content-Type', 'text/html;charset=UTF-8')
            ..headers.add('Content-Length', html.length.toString())
            ..add(html);
          await response.close();
        case '/model-viewer.min.js':
          final code = await _readAsset('assets/model-viewer.min.js');
          response
            ..statusCode = HttpStatus.ok
            ..headers
                .add('Content-Type', 'application/javascript;charset=UTF-8')
            ..headers.add('Content-Length', code.lengthInBytes.toString())
            ..add(code);
          await response.close();
        case '/model':
          if (url.isAbsolute && !url.isScheme('file')) {
            await response.redirect(url);
          } else {
            final data = await (url.isScheme('file')
                ? _readFile(url.path)
                : _readAsset(url.path));
            response
              ..statusCode = HttpStatus.ok
              ..headers.add('Content-Type', 'application/octet-stream')
              ..headers.add('Content-Length', data.lengthInBytes.toString())
              ..headers.add('Access-Control-Allow-Origin', '*')
              ..add(data);
            await response.close();
          }
        case '/favicon.ico':
          final text = utf8.encode("Resource '${request.uri}' not found");
          response
            ..statusCode = HttpStatus.notFound
            ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
            ..headers.add('Content-Length', text.length.toString())
            ..add(text);
          await response.close();
        default:
          if (request.uri.isAbsolute) {
            debugPrint('Redirect: ${request.uri}');
            await response.redirect(request.uri);
          } else if (request.uri.hasAbsolutePath) {
            // Some gltf models need other resources from the origin
            final pathSegments = [...url.pathSegments]..removeLast();
            final tryDestination = path.joinAll([
              url.origin,
              ...pathSegments,
              request.uri.path.replaceFirst('/', ''),
            ]);
            debugPrint('Try: $tryDestination');
            await response.redirect(Uri.parse(tryDestination));
          } else {
            debugPrint('404 with ${request.uri}');
            final text = utf8.encode("Resource '${request.uri}' not found");
            response
              ..statusCode = HttpStatus.notFound
              ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
              ..headers.add('Content-Length', text.length.toString())
              ..add(text);
            await response.close();
            break;
          }
      }
    });
  }

  Future<Uint8List> _readAsset(final String key) async {
    final data = await rootBundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<Uint8List> _readFile(final String path) async {
    return File(path).readAsBytes();
  }
}
