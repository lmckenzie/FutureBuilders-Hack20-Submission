import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components/component.dart';
import 'package:flame/components/mixins/has_game_ref.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/gestures.dart';
import 'package:flame/palette.dart';
import 'package:flame/position.dart';
import 'package:flame/text_config.dart';
import 'package:flame/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    Util flameUtil = Util();
    await flameUtil.fullScreen();
    await flameUtil.setOrientation(DeviceOrientation.portraitUp);
  }

  final game = MyGame();
  runApp(game.widget);
}

class Palette {
  static const PaletteEntry white = BasicPalette.white;
  static const PaletteEntry magenta = PaletteEntry(Color(0xffF20098));
  static const PaletteEntry pink = PaletteEntry(Color(0xfffe00fe));
  static const PaletteEntry purple = PaletteEntry(Color(0xff7700a6));
  static const PaletteEntry blue = PaletteEntry(Color(0xff00b3fe));
}

enum ShipLocation { left, center, right }

class MyGame extends BaseGame with TapDetector {
  int score = 0;
  bool running = true;
  Size screenSize;
  ui.Image carImage;
  ui.Image carImageLeft;
  ui.Image carImageRight;
  ui.Image horizonImage;
  Ground ground;
  Car car;
  ShipLocation shipLocation = ShipLocation.center;

  MyGame() {
    ground = Ground();
    add(ground);
    car = Car();
    add(car);
    add(Score());
    add(Pause());
    _loadImages();
  }

  void resize(Size size) {
    screenSize = size;
    super.resize(size);
  }

  @override
  void onTapDown(TapDownDetails details) {
    if (details.globalPosition.dx > screenSize.width - 80 && details.globalPosition.dy < 48) {
      if (running) {
        pauseEngine();
      } else {
        resumeEngine();
      }

      running = !running;
      return;
    }
    if (!running) return;

    if (details.globalPosition.dx > screenSize.width * .6666) {
      if (shipLocation == ShipLocation.left) {
        shipLocation = ShipLocation.center;
      } else if (shipLocation == ShipLocation.center) {
        shipLocation = ShipLocation.right;
      }
    } else if (details.globalPosition.dx > 0) {
      if (shipLocation == ShipLocation.right) {
        shipLocation = ShipLocation.center;
      } else if (shipLocation == ShipLocation.center) {
        shipLocation = ShipLocation.left;
      }
    }
  }

  Future<void> _loadImages() async {
    carImage = await Flame.images.load('2.png');
    carImageLeft = await Flame.images.load('1.png');
    carImageRight = await Flame.images.load('3.png');
    horizonImage = await Flame.images.load('neon-background.png');
  }
}

class Score extends PositionComponent with HasGameRef<MyGame> {
  @override
  void render(Canvas c) {
    prepareCanvas(c);
    textConfig.render(c, 'Score: ${gameRef.score}', Position(24, 24));
  }
}

class Pause extends PositionComponent with HasGameRef<MyGame> {
  @override
  void render(Canvas c) {
    prepareCanvas(c);
    textConfig.render(c, 'Pause', Position(gameRef.screenSize.width - 94, 24));
  }
}

class Car extends PositionComponent with HasGameRef<MyGame> {
  static const SPEED = 0.25;

  @override
  void resize(Size size) {
    x = size.width * .372;
    y = size.height * .85;
  }

  @override
  void render(Canvas c) {
    prepareCanvas(c);
    if (gameRef.carImage != null) {
      c.save();
      c.scale(0.3, 0.3);
      if (angle > -0.03 && angle < 0.03) {
        c.drawImage(gameRef.carImage, Offset(-180, -100), Paint());
      } else if (angle < -0.03) {
        c.drawImage(gameRef.carImageRight, Offset(-180, -90), Paint());
      } else if (angle > 0.03) {
        c.drawImage(gameRef.carImageLeft, Offset(-180, -120), Paint());
      }
      c.restore();
    }
  }

  @override
  void update(double t) {
    super.update(t);
    if (gameRef.shipLocation == ShipLocation.left) {
      angle = math.min(.1, angle + .01);
    } else if (gameRef.shipLocation == ShipLocation.right) {
      angle = math.max(-.1, angle - .01);
    } else if (angle > 0) {
      angle = math.max(0, angle - .01);
    } else if (angle < 0) {
      angle = math.min(0, angle + .01);
    }
  }
}

final textConfig = TextConfig(color: Palette.white.color);

class Ground extends PositionComponent with HasGameRef<MyGame> {
  static const ROTATION_SPEED = 0.75;
  int currentTime = 0;
  int projectileLeftStartTime = 0;
  int projectileRightStartTime = 0;
  int projectileCenterStartTime = 0;

  Size get screenSize => gameRef.screenSize;
  double get height => screenSize.height;
  double get width => screenSize.width;

  @override
  void resize(Size size) {
    x = size.width / 2;
    y = size.height / 2;
  }

  @override
  void render(Canvas c) {
    prepareCanvas(c);
    _drawBackground(c);
    _drawGamePlane(c, color: Palette.pink.color, stroke: 3, blendMode: BlendMode.srcOver);
    _drawGamePlane(c, color: Palette.white.color, stroke: 1, blendMode: BlendMode.luminosity);
    if (gameRef.horizonImage != null) {
      c.save();
      c.scale(0.45, 0.45);
      c.drawImage(gameRef.horizonImage, Offset(-width * 1.3, -height * 1.5), Paint());
      c.restore();
    }
  }

  void _drawGamePlane(Canvas canvas, {Color color, double stroke, BlendMode blendMode}) {
    Paint linePaint = Paint()
      ..strokeWidth = stroke
      ..blendMode = blendMode;
    if (color != Palette.white.color) {
      linePaint.shader = ui.Gradient.linear(
          Offset(width / 2, 0), Offset(width, height), [Palette.magenta.color, Palette.pink.color, color], [.3, .7, 1]);
    } else {
      linePaint.shader = ui.Gradient.linear(
          Offset(width / 2, 0), Offset(width, height), [Palette.pink.color, Palette.magenta.color, color], [.1, .3, 1]);
    }

    canvas.save();
    final movement = Tween<double>(begin: 100, end: 400);

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective
      ..rotateX(-1.14577) // changed
      ..rotateY(0)
      ..rotateZ(0)
      ..translate(-180.0, movement.transform(currentTime % 800 / 800), 240.0);
    canvas.transform(matrix.storage);
    final lineSpacing = 30.0;
    double lastLineY = height;
    final horizonY = -height * 2;

    canvas.drawLine(Offset(0 - width, lastLineY), Offset(width * 2, lastLineY), linePaint);
    while (lastLineY > horizonY) {
      final lineY = lastLineY - lineSpacing;
      canvas.drawLine(Offset(0 - width, lineY), Offset(width * 2, lineY), linePaint);
      lastLineY = lineY;
    }

    final centerX = width / 2 * (1 - angle);
    canvas.drawLine(Offset(centerX, height), Offset(centerX, horizonY), linePaint);
    for (int i = 1; i < 60; i++) {
      double topSpacing = lineSpacing * i;
      double bottomSpacing = lineSpacing * i;
      canvas.drawLine(Offset(centerX - bottomSpacing, height), Offset(centerX - topSpacing, horizonY), linePaint);
      canvas.drawLine(Offset(centerX + bottomSpacing, height), Offset(centerX + topSpacing, horizonY), linePaint);
      if (i == 5) {
        if (projectileLeftStartTime > 0) {
          final time = math.min(currentTime - projectileLeftStartTime, 2000) / 2000;
          if (time < 1) {
            final t = Curves.easeInQuad.transform(time);
            final teen = Tween<Offset>(
                begin: Offset(centerX + topSpacing, horizonY * 1.06), end: Offset(centerX + bottomSpacing, height));
            final size = Tween<double>(begin: 2, end: 40);
            canvas.drawCircle(teen.transform(t), size.transform(time), Paint()..color = Palette.blue.color);
          } else {
            projectileLeftStartTime = 0;
            gameRef.score++;
          }
        }
        if (projectileRightStartTime > 0) {
          final time = math.min(currentTime - projectileRightStartTime, 2000) / 2000;
          if (time < 1) {
            final t = Curves.easeInQuad.transform(time);
            final teen = Tween<Offset>(
                begin: Offset(centerX - topSpacing, horizonY * 1.06), end: Offset(centerX - bottomSpacing, height));
            final size = Tween<double>(begin: 2, end: 40);
            canvas.drawCircle(teen.transform(t), size.transform(time), Paint()..color = Palette.blue.color);
          } else {
            projectileRightStartTime = 0;
            gameRef.score++;
          }
        }
      }
    }
    canvas.restore();
  }

  void _drawBackground(Canvas canvas) {
    Rect bgRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    Paint bgPaint = Paint();
    bgPaint.color = Color(0xff000000);
    canvas.drawRect(bgRect, bgPaint);
  }

  @override
  void update(double t) {
    super.update(t);
    currentTime += (t * 1000).toInt();
    if (gameRef.shipLocation == ShipLocation.left) {
      angle = math.max(-.2, angle - .01);
      if (projectileRightStartTime == 0) {
        projectileRightStartTime = currentTime;
      }
    } else if (gameRef.shipLocation == ShipLocation.right) {
      if (projectileLeftStartTime == 0) {
        projectileLeftStartTime = currentTime;
      }

      angle = math.min(.2, angle + .01);
    } else if (angle > 0) {
      angle = math.max(0, angle - .01);
    } else if (angle < 0) {
      angle = math.min(0, angle + .01);
    } else {
      if (projectileCenterStartTime == 0) {
        projectileCenterStartTime = currentTime;
      }
    }
  }
}
