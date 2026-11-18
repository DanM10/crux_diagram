import type { DrawingDocument, JointStyle } from '@diagrama-kit/core';
import { DrawingStage } from './render/DrawingStage.js';

export interface DrawingViewerProps {
  readonly document: DrawingDocument;
  /** Look of leader arrows and labels; pass the editor's so joints look the same. */
  readonly jointStyle?: JointStyle;
}

/**
 * Read-only view of a drawing (REA-001), like Flutter's `DrawingView`: white canvas,
 * shapes and joints, fitted and centered in its parent, which must have a size. It
 * ignores gestures.
 */
export function DrawingViewer({ document, jointStyle }: DrawingViewerProps) {
  return <DrawingStage document={document} jointStyle={jointStyle} listening={false} />;
}
