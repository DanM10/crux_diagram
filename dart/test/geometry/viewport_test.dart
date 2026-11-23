import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux_diagram/src/geometry/viewport.dart';

void main() {
  test('fit centers a 4:3 canvas in a wide area, preserving aspect ratio', () {
    final viewport = CanvasViewport.fit(
      const Size(1600, 1200),
      const Size(1000, 600),
    );
    expect(viewport.scale, 0.5);
    expect(viewport.origin, const Offset(100, 0));
  });

  test('toCanvas inverts toScreen', () {
    const viewport = CanvasViewport(scale: 0.25, origin: Offset(10, 20));
    const point = Offset(640, 480);
    expect(viewport.toCanvas(viewport.toScreen(point)), point);
    expect(viewport.toScreen(point), const Offset(170, 140));
  });

  test('dp lengths convert to canvas units', () {
    const viewport = CanvasViewport(scale: 0.5, origin: Offset.zero);
    expect(viewport.canvasLength(24), 48);
  });

  group('ViewportZoom', () {
    const canvas = Size(1600, 1200);
    const area = Size(1000, 600);
    final fit = CanvasViewport.fit(canvas, area);

    test('identity zoom yields the fitted viewport', () {
      expect(const ViewportZoom().apply(fit), fit);
    });

    test('pinch keeps the canvas point under the start focal under the '
        'current focal', () {
      const startFocal = Offset(400, 300);
      final canvasPoint = fit.toCanvas(startFocal);
      final zoom = const ViewportZoom().pinch(
        startFocal: startFocal,
        focal: const Offset(450, 320),
        scale: 2,
      );
      expect(zoom.zoom, 2);
      final viewport = zoom.apply(fit);
      expect(viewport.scale, fit.scale * 2);
      final screen = viewport.toScreen(canvasPoint);
      expect(screen.dx, closeTo(450, 1e-9));
      expect(screen.dy, closeTo(320, 1e-9));
    });

    test('pinch clamps zoom to 1x..4x', () {
      const zoom = ViewportZoom();
      expect(
        zoom.pinch(startFocal: Offset.zero, focal: Offset.zero, scale: 10).zoom,
        ViewportZoom.maxZoom,
      );
      expect(
        zoom
            .pinch(startFocal: Offset.zero, focal: Offset.zero, scale: 0.1)
            .zoom,
        ViewportZoom.minZoom,
      );
    });

    test('clamped at 1x always recenters the canvas', () {
      const zoom = ViewportZoom(pan: Offset(300, -200));
      expect(zoom.clamped(canvas, area), const ViewportZoom());
    });

    test('clamped keeps a zoomed canvas covering the area', () {
      // At 2x the canvas is 1600 x 1200 dp inside a 1000 x 600 area.
      final far = const ViewportZoom(
        zoom: 2,
        pan: Offset(5000, 5000),
      ).clamped(canvas, area).apply(fit);
      expect(far.toScreen(Offset.zero), Offset.zero);
      final near = const ViewportZoom(
        zoom: 2,
        pan: Offset(-5000, -5000),
      ).clamped(canvas, area).apply(fit);
      final bottomRight = near.toScreen(const Offset(1600, 1200));
      expect(bottomRight.dx, closeTo(1000, 1e-9));
      expect(bottomRight.dy, closeTo(600, 1e-9));
    });

    test('clamped centers an axis the zoomed canvas does not fill', () {
      // Tall area: at 1.5x the canvas is 750 dp tall in a 1000 dp area.
      const tall = Size(500, 1000);
      final tallFit = CanvasViewport.fit(canvas, tall);
      final viewport = const ViewportZoom(
        zoom: 1.5,
        pan: Offset(0, 400),
      ).clamped(canvas, tall).apply(tallFit);
      final top = viewport.toScreen(Offset.zero).dy;
      final bottom = viewport.toScreen(const Offset(0, 1200)).dy;
      expect(top, closeTo(1000 - bottom, 1e-9));
    });
  });

  group('visibleCenter (spec 03, PL-1)', () {
    const canvas = Size(1600, 1200);
    const area = Size(1000, 600);

    test('fitted, it is the canvas center', () {
      final viewport = CanvasViewport.fit(canvas, area);
      expect(viewport.visibleCenter(area, canvas), const Offset(800, 600));
    });

    test('zoomed and panned, it is the canvas point under the area center', () {
      // Scale 1, canvas shifted so (300, 200) sits under the area center.
      const viewport = CanvasViewport(scale: 1, origin: Offset(200, 100));
      expect(viewport.visibleCenter(area, canvas), const Offset(300, 200));
    });

    test('it is clamped to the canvas', () {
      const viewport = CanvasViewport(scale: 1, origin: Offset(900, 500));
      expect(viewport.visibleCenter(area, canvas), Offset.zero);
      const far = CanvasViewport(scale: 1, origin: Offset(-5000, -5000));
      expect(far.visibleCenter(area, canvas), const Offset(1600, 1200));
    });
  });
}
