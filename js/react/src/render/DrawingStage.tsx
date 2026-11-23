// The Konva stage shared by the viewer and the editor. Layers, bottom to top (spec 05
// section 4): (1) background, (2) shapes, (3) joints, (4) editing UI, given as children.

import {
  applyZoom,
  clampZoom,
  computeGeometry,
  DEFAULT_JOINT_STYLE,
  FITTED_ZOOM,
  fitViewport,
  type CanvasViewport,
  type DrawingDocument,
  type JointStyle,
  type Shape,
  type Size,
  type ViewportZoom,
} from '@crux-diagram/core';
import type { KonvaEventObject } from 'konva/lib/Node';
import { memo, useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Ellipse, Layer, Line, Rect, Stage, Text } from 'react-konva';
import { useFontsReady, useLabelMeasurer } from './fonts.js';
import { describeDrawing, DrawingList } from '../a11y.js';
import { jointNodeProps, shapeNodeProps } from './scene.js';

export interface DrawingStageProps {
  readonly document: DrawingDocument;
  readonly jointStyle?: JointStyle;
  /** Whether the stage handles pointer events. */
  readonly listening: boolean;
  /** Zoom and pan on top of the fitted view (default: fitted); clamped so the canvas stays in view. */
  readonly zoom?: ViewportZoom;
  /** Called on a mouse wheel or trackpad pinch over the stage (REA-016). */
  readonly onWheel?: (event: KonvaEventObject<WheelEvent>) => void;
  /** Alternative description of the drawing for screen readers (REA-052); a summary by default. */
  readonly alt?: string;
  /** Ids of the selected shapes, announced in the shape list (REA-052). */
  readonly selection?: readonly string[];
  /** Called with the measured size of the drawing area whenever it changes. */
  readonly onAreaChange?: (area: Size) => void;
  /** Called when a pointer goes down anywhere on the stage (the editor's gestures). */
  readonly onPointerDown?: (event: KonvaEventObject<PointerEvent>) => void;
  /** HTML drawn over the stage, positioned with the viewport (the joint name editor). */
  readonly overlay?: (viewport: CanvasViewport) => ReactNode;
  /** Layer 4, drawn above the joints; a function receives the view scale (screen pixels per canvas unit). */
  readonly children?: ReactNode | ((scale: number) => ReactNode);
}

/** Fills its parent and fits the canvas into it, centered, keeping the aspect ratio. */
export function DrawingStage({ document, jointStyle = DEFAULT_JOINT_STYLE, listening, zoom = FITTED_ZOOM, onWheel, onPointerDown, onAreaChange, alt, selection, overlay, children }: DrawingStageProps) {
  const container = useRef<HTMLDivElement>(null);
  const area = useContainerSize(container);
  const width = area?.width;
  const height = area?.height;
  useEffect(() => {
    if (width !== undefined && height !== undefined) onAreaChange?.({ width, height });
  }, [width, height, onAreaChange]);
  return (
    <div ref={container} role="group" aria-label={alt ?? describeDrawing(document)} style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden' }}>
      <DrawingList document={document} selection={selection} />
      {area && area.width > 0 && area.height > 0 && (
        <FittedStage document={document} jointStyle={jointStyle} listening={listening} zoom={zoom} onWheel={onWheel} onPointerDown={onPointerDown} overlay={overlay} area={area}>
          {children}
        </FittedStage>
      )}
    </div>
  );
}

function FittedStage({
  document,
  jointStyle,
  listening,
  zoom,
  onWheel,
  onPointerDown,
  overlay,
  area,
  children,
}: Required<Omit<DrawingStageProps, 'children' | 'onPointerDown' | 'onWheel' | 'overlay' | 'onAreaChange' | 'alt' | 'selection'>> & Pick<DrawingStageProps, 'onPointerDown' | 'onWheel' | 'overlay'> & { area: Size; children?: DrawingStageProps['children'] }) {
  const viewport = applyZoom(clampZoom(zoom, document.canvas, area), fitViewport(document.canvas, area));
  const clip = { x: 0, y: 0, width: document.canvas.width, height: document.canvas.height };
  return (
    <>
    <div aria-hidden="true">
    <Stage
      width={area.width}
      height={area.height}
      x={viewport.origin.x}
      y={viewport.origin.y}
      scaleX={viewport.scale}
      scaleY={viewport.scale}
      listening={listening}
      onPointerDown={onPointerDown}
      onWheel={onWheel}
    >
      <Layer name="background" clip={clip} listening={false}>
        <Rect name="background-fill" width={clip.width} height={clip.height} fill="#ffffff" />
      </Layer>
      <Layer name="shapes" clip={clip}>
        {document.shapes.map((shape) => (
          <ShapeNode key={shape.id} shape={shape} />
        ))}
      </Layer>
      <JointsLayer document={document} style={jointStyle} clip={clip} />
      {typeof children === 'function' ? children(viewport.scale) : children}
    </Stage>
    </div>
    {overlay?.(viewport)}
    </>
  );
}

/** One shape; re-renders only when its data changes (REA-050). */
const ShapeNode = memo(function ShapeNode({ shape }: { shape: Shape }) {
  const { kind, ...props } = shapeNodeProps(shape);
  return kind === 'ellipse' ? <Ellipse id={shape.id} {...props} /> : <Rect id={shape.id} {...props} />;
});

function JointsLayer({ document, style, clip }: { document: DrawingDocument; style: JointStyle; clip: object }) {
  const fontsReady = useFontsReady();
  const measurer = useLabelMeasurer();
  // The joints of the exportable geometry, so the screen shows exactly what getGeometry returns (REA-033).
  const graphics = useMemo(() => {
    if (!fontsReady) return [];
    return computeGeometry(document, { measurer: measurer(), style }).joints.map(jointNodeProps);
  }, [document, style, fontsReady, measurer]);
  return (
    <Layer name="joints" clip={clip}>
      {graphics.map(({ id, line, head, text, lineColor, lineWidth }) => [
        line && (
          <Line
            key={`${id}-line`}
            name="joint-line"
            points={line}
            stroke={lineColor}
            strokeWidth={lineWidth}
            lineCap="butt"
          />
        ),
        head && <Line key={`${id}-head`} name="joint-head" points={head} closed fill={lineColor} />,
        <Text
          key={`${id}-label`}
          id={id}
          name="joint-label"
          {...text}
          align="center"
          verticalAlign="middle"
          wrap="none"
        />,
      ])}
    </Layer>
  );
}

/** The content size of `ref`, tracked with `ResizeObserver` (window resizes without it); `null` before mount. */
function useContainerSize(ref: React.RefObject<HTMLDivElement | null>): Size | null {
  const [size, setSize] = useState<Size | null>(null);
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const update = (width: number, height: number) =>
      setSize((old) => (old && old.width === width && old.height === height ? old : { width, height }));
    if (typeof ResizeObserver === 'undefined') {
      // Without ResizeObserver, follow window resizes only.
      const read = () => update(element.clientWidth, element.clientHeight);
      read();
      window.addEventListener('resize', read);
      return () => window.removeEventListener('resize', read);
    }
    const observer = new ResizeObserver(([entry]) => {
      if (entry) update(entry.contentRect.width, entry.contentRect.height);
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref]);
  return size;
}
