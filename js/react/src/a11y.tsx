// Basic accessibility of the drawing (REA-052): an alternative description and a list of shapes
// for screen readers. The phrases are English; only `alt` is configurable.

import type { DrawingDocument, Shape } from '@diagrama-kit/core';
import type { CSSProperties } from 'react';

const plural = (count: number, noun: string) => `${count} ${noun}${count === 1 ? '' : 's'}`;
const typeName = (shape: Shape) => shape.type.charAt(0).toUpperCase() + shape.type.slice(1);

/** The default alternative description of a drawing. */
export function describeDrawing(document: DrawingDocument): string {
  return `Drawing with ${plural(document.shapes.length, 'shape')} and ${plural(document.joints.length, 'joint')}`;
}

/** One phrase per shape, back to front, marking the selected ones. */
export function describeShapes(document: DrawingDocument, selection: readonly string[]): string[] {
  const selected = new Set(selection);
  return document.shapes.map((shape, index) => {
    const degrees = Math.round((shape.rotation * 180) / Math.PI);
    const parts = [
      `${typeName(shape)} ${index + 1} of ${document.shapes.length} at ${Math.round(shape.center.x)}, ${Math.round(shape.center.y)}, ${Math.round(shape.size.width)} by ${Math.round(shape.size.height)}`,
    ];
    if (degrees !== 0) parts.push(`rotated ${degrees}°`);
    if (selected.has(shape.id)) parts.push('selected');
    return parts.join(', ');
  });
}

/** One phrase per visible joint; none while the joints are hidden (REA-023). */
export function describeJoints(document: DrawingDocument): string[] {
  if (!document.jointDisplay.visible) return [];
  return document.joints.flatMap((joint) => {
    const index = document.shapes.findIndex((s) => s.id === joint.shapeId);
    return index < 0 ? [] : [`Joint ${joint.name} on ${typeName(document.shapes[index]!)} ${index + 1}`];
  });
}

/** Hidden by clipping, not `display: none`, so it stays in the accessibility tree. */
const visuallyHidden: CSSProperties = {
  position: 'absolute',
  width: 1,
  height: 1,
  margin: -1,
  padding: 0,
  overflow: 'hidden',
  clip: 'rect(0 0 0 0)',
  whiteSpace: 'nowrap',
  border: 0,
};

/** The shape and joint list of a drawing, for screen readers. */
export function DrawingList({ document, selection = [] }: { document: DrawingDocument; selection?: readonly string[] }) {
  return (
    <ul style={{ ...visuallyHidden, listStyle: 'none' }}>
      {[...describeShapes(document, selection), ...describeJoints(document)].map((text, index) => (
        <li key={index}>{text}</li>
      ))}
    </ul>
  );
}
