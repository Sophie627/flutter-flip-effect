import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.indigo,
        accentColor: Colors.pinkAccent,
      ),
      home: ExampleScreen(),
    ),
  );
}

class ExampleScreen extends StatefulWidget {
  @override
  _ExampleScreenState createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.5,
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_controller.status == AnimationStatus.dismissed || _controller.status == AnimationStatus.reverse) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Container(
          height: 200.0,
          width: 300.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PageTurnImage(
                  amount: AlwaysStoppedAnimation(1.0),
                  image: NetworkImage(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/John_Masefield.djvu/page10-1024px-John_Masefield.djvu.jpg'),
                ),
                PageTurnImage(
                  amount: _controller,
                  image: AssetImage('images/template_sample.png'),
                ),
                Positioned(
                  left: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  height: 48.0,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget child) {
                      return Slider(
                        value: _controller.value,
                        onChanged: (double value) {
                          _controller.value = value;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageTurnImage extends StatefulWidget {
  const PageTurnImage({
    Key key,
    this.amount,
    this.image,
    this.backgroundColor = const Color(0xFFFFFFCC),
  }) : super(key: key);

  final Animation<double> amount;
  final ImageProvider image;
  final Color backgroundColor;

  @override
  _PageTurnImageState createState() => _PageTurnImageState();
}

class _PageTurnImageState extends State<PageTurnImage> {
  ImageStream _imageStream;
  ImageInfo _imageInfo;
  bool _isListeningToStream = false;

  ImageStreamListener _imageListener;

  @override
  void initState() {
    super.initState();
    _imageListener = ImageStreamListener(_handleImageFrame);
  }

  @override
  void dispose() {
    _stopListeningToStream();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    if (TickerMode.of(context)) {
      _listenToStream();
    } else {
      _stopListeningToStream();
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(PageTurnImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _resolveImage();
    }
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    final ImageStream newStream = widget.image.resolve(createLocalImageConfiguration(context));
    assert(newStream != null);
    _updateSourceStream(newStream);
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    setState(() => _imageInfo = imageInfo);
  }

  // Updates _imageStream to newStream, and moves the stream listener
  // registration from the old stream to the new stream (if a listener was
  // registered).
  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream?.key == newStream?.key) return;

    if (_isListeningToStream) _imageStream.removeListener(_imageListener);

    _imageStream = newStream;
    if (_isListeningToStream) _imageStream.addListener(_imageListener);
  }

  void _listenToStream() {
    if (_isListeningToStream) return;
    _imageStream.addListener(_imageListener);
    _isListeningToStream = true;
  }

  void _stopListeningToStream() {
    if (!_isListeningToStream) return;
    _imageStream.removeListener(_imageListener);
    _isListeningToStream = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_imageInfo != null) {
      return CustomPaint(
        painter: _PageTurnEffect(
          amount: widget.amount,
          image: _imageInfo.image,
          backgroundColor: widget.backgroundColor,
        ),
        size: Size.infinite,
      );
    } else {
      return const SizedBox();
    }
  }
}

class _PageTurnEffect extends CustomPainter {
  _PageTurnEffect({
    @required this.amount,
    @required this.image,
    this.backgroundColor,
    this.radius = 0.18,
  })  : assert(amount != null && image != null && radius != null),
        super(repaint: amount);

  final Animation<double> amount;
  final ui.Image image;
  final Color backgroundColor;
  final double radius;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final pos = amount.value;
    final movX = (1.0 - pos) * 0.85;
    final calcR = (movX < 0.20) ? radius * movX * 5 : radius;
    final wHRatio = 1 - calcR;
    final hWRatio = image.height / image.width;
    final hWCorrection = (hWRatio - 1.0) / 2.0;

    final w = size.width.toDouble();
    final h = size.height.toDouble();
    final c = canvas;
    final shadowXf = (wHRatio - movX);
    final shadowSigma = Shadow.convertRadiusToSigma(8.0 + (32.0 * (1.0 - shadowXf)));
    final pageRect = Rect.fromLTRB(0.0, 0.0, w * shadowXf, h);
    if (backgroundColor != null) {
      c.drawRect(pageRect, Paint()..color = backgroundColor);
    }
    c.drawRect(
      pageRect,
      Paint()
        ..color = Colors.black54
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, shadowSigma),
    );

    final ip = Paint();
    for (double x = 0; x < size.width; x++) {
      final xf = (x / w);
      final v = (calcR * (math.sin(math.pi / 0.5 * (xf - (1.0 - pos)))) + (calcR * 1.1));
      final xv = (xf * wHRatio) - movX;
      final sx = (xf * image.width);
      final sr = Rect.fromLTRB(sx, 0.0, sx + 1.0, image.height.toDouble());
      final yv = ((h * calcR * movX) * hWRatio) - hWCorrection;
      final ds = (yv * v);
      final dr = Rect.fromLTRB(xv * w, 0.0 - ds, xv * w + 1.0, h + ds);
      c.drawImageRect(image, sr, dr, ip);
    }
  }

  @override
  bool shouldRepaint(_PageTurnEffect oldDelegate) {
    return oldDelegate.image != image || oldDelegate.amount.value != amount.value;
  }
}
