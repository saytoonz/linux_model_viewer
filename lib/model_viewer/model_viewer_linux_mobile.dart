import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'model_viewer.dart';
import 'dart:convert' show utf8;
import './widget/html_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_linux_webview/flutter_linux_webview.dart';
import 'package:android_intent_plus/android_intent.dart' as android_content;

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
      initialUrl: null,
      javascriptMode: JavascriptMode.unrestricted,
      backgroundColor: Colors.transparent,
      onWebViewCreated: (WebViewController controller) async {
        _controller.complete(controller);
        await controller.loadUrl(_proxyURL);
      },
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      navigationDelegate: (request) async {
        debugPrint('ModelViewer wants to load: ${request.url}');
        if (Platform.isIOS && request.url == widget.iosSrc) {
          await launchUrl(
            Uri.parse(request.url.trimLeft()),
            mode: LaunchMode.inAppWebView,
          );
          return NavigationDecision.prevent;
        }
        if (Platform.isLinux) {
          return NavigationDecision.prevent;
        }
        if (!Platform.isAndroid) {
          return NavigationDecision.navigate;
        }
        if (!request.url.startsWith('intent://')) {
          return NavigationDecision.navigate;
        }
        try {
          // Original, just keep as a backup
          // See: https://developers.google.com/ar/develop/java/scene-viewer
          // final intent = android_content.AndroidIntent(
          //   action: "android.intent.action.VIEW", // Intent.ACTION_VIEW
          //   data: "https://arvr.google.com/scene-viewer/1.0",
          //   arguments: <String, dynamic>{
          //     'file': widget.src,
          //     'mode': 'ar_preferred',
          //   },
          //   package: "com.google.ar.core",
          //   flags: <int>[
          //     Flag.FLAG_ACTIVITY_NEW_TASK
          //   ], // Intent.FLAG_ACTIVITY_NEW_TASK,
          // );

          final String fileURL;
          if (['http', 'https'].contains(Uri.parse(widget.src).scheme)) {
            fileURL = widget.src;
          } else {
            fileURL = path.joinAll([_proxyURL, 'model']);
          }
          final intent = android_content.AndroidIntent(
            action: 'android.intent.action.VIEW',
            // Intent.ACTION_VIEW
            // See https://developers.google.com/ar/develop/scene-viewer#3d-or-ar
            // data should be something like "https://arvr.google.com/scene-viewer/1.0?file=https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Avocado/glTF/Avocado.gltf"
            data: Uri(
              scheme: 'https',
              host: 'arvr.google.com',
              path: '/scene-viewer/1.0',
              queryParameters: {
                'mode': 'ar_preferred',
                'file': fileURL,
              },
            ).toString(),
            // package changed to com.google.android.googlequicksearchbox
            // to support the widest possible range of devices
            package: 'com.google.android.googlequicksearchbox',
            arguments: <String, dynamic>{
              'browser_fallback_url':
                  'market://details?id=com.google.android.googlequicksearchbox',
            },
          );
          await intent.launch().onError((error, stackTrace) {
            debugPrint('ModelViewer Intent Error: $error');
          });
        } on Object catch (error) {
          debugPrint('ModelViewer failed to launch AR: $error');
        }
        return NavigationDecision.prevent;
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
