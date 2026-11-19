import type { DrawingDocument, JointStyle } from '@diagrama-kit/core';
import { DrawingStage } from './render/DrawingStage.js';

export interface DrawingViewerProps {
  readonly document: DrawingDocument;
  /** Look of leader arrows and labels; the reference style (spec 02, section 12) by default. */
  readonly jointStyle?: JointStyle;
  /** Alternative description for screen readers (REA-052); a summary of the drawing by default. */
  readonly alt?: string;
}

/**
 * Read-only view of a drawing (REA-001), like Flutter's `DrawingView`: white canvas,
 * shapes and joints, fitted and centered in its parent, which must have a size. It
 * ignores gestures.
 */
export function DrawingViewer({ document, jointStyle, alt }: DrawingViewerProps) {
  return <DrawingStage document={document} jointStyle={jointStyle} alt={alt} listening={false} />;
}
