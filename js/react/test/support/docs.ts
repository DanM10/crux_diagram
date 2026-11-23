// Small documents for interaction tests. Canvas 1000 × 800, white rectangles.
import type { DrawingDocument, Group, Joint, Shape } from '@crux-diagram/core';

/** A rectangle centered at (x, y), `width × height`, rotated by `rotation` radians. */
export function rect(id: string, x: number, y: number, width = 100, height = 60, rotation = 0): Shape {
  return { id, type: 'rectangle', center: { x, y }, size: { width, height }, rotation, fill: 0xffffffff, stroke: 0xff000000, strokeWidth: 2 };
}

/** A joint on the top-left anchor of `shapeId`. */
export function joint(id: string, shapeId: string): Joint {
  return { id, shapeId, anchorId: 'tl', name: id, labelOffset: { dx: 0, dy: -40 } };
}

export function docOf(shapes: readonly Shape[], options: { groups?: readonly Group[]; joints?: readonly Joint[] } = {}): DrawingDocument {
  return {
    schemaVersion: 1,
    canvas: { width: 1000, height: 800 },
    shapes,
    joints: options.joints ?? [],
    jointDisplay: { labelSize: 'medium', visible: true },
    groups: options.groups ?? [],
  };
}

/** The center of the shape with `id`. */
export function centerOf(doc: DrawingDocument, id: string) {
  return doc.shapes.find((s) => s.id === id)!.center;
}
