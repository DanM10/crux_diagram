// The Konva stage shared by the viewer and the editor. Layers, bottom to top (spec 05
// section 4): (1) background, (2) shapes, (3) joints, (4) editing UI, given as children.

import {
  argbToCss,
  DEFAULT_JOINT_STYLE,
  fitViewport,
  type DrawingDocument,
  type JointStyle,
  type Shape,
  type Size,
} from '@diagrama-kit/core';
import type { KonvaEventObject } from 'konva/lib/Node';
import { memo, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Ellipse, Layer, Line, Rect, Stage, Text } from 'react-konva';
import { useFontsReady, useLabelMeasurer } from './fonts.js';
import { jointGraphics, placeJoints, shapeNodeProps } from './scene.js';

export interface DrawingStageProps {
  readonly document: DrawingDocument;
  readonly jointStyle?: JointStyle;
  /** Whether the stage handles pointer events. */
  readonly listening: boolean;
  /** Called when a pointer goes down anywhere on the stage (the editor's gestures). */
  readonly onPointerDown?: (event: KonvaEventObject<PointerEvent>) => void;
  /** Layer 4, drawn above the joints; a function receives the view scale (screen pixels per canvas unit). */
  readonly children?: ReactNode | ((scale: number) => ReactNode);
}

/** Fills its parent and fits the canvas into it, centered, keeping the aspect ratio. */
export function DrawingStage({ document, jointStyle = DEFAULT_JOINT_STYLE, listening, onPointerDown, children }: DrawingStageProps) {
  const container = useRef<HTMLDivElement>(null);
  const area = useContainerSize(container);
  return (
    <div ref={container} style={{ width: '100%', height: '100%', overflow: 'hidden' }}>
      {area && area.width > 0 && area.height > 0 && (
        <FittedStage document={document} jointStyle={jointStyle} listening={listening} onPointerDown={onPointerDown} area={area}>
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
  onPointerDown,
  area,
  children,
}: Required<Omit<DrawingStageProps, 'children' | 'onPointerDown'>> & Pick<DrawingStageProps, 'onPointerDown'> & { area: Size; children?: DrawingStageProps['children'] }) {
  const viewport = fitViewport(document.canvas, area);
  const clip = { x: 0, y: 0, width: document.canvas.width, height: document.canvas.height };
  return (
    <Stage
      width={area.width}
      height={area.height}
      x={viewport.origin.x}
      y={viewport.origin.y}
      scaleX={viewport.scale}
      scaleY={viewport.scale}
      listening={listening}
      onPointerDown={onPointerDown}
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
  const graphics = useMemo(() => {
    if (!fontsReady) return [];
    const labelSize = document.jointDisplay.labelSize;
    return placeJoints(document, style, measurer()).map((p) => ({
      id: p.joint.id,
      ...jointGraphics(p, style, labelSize),
    }));
  }, [document, style, fontsReady, measurer]);
  const color = argbToCss(style.color);
  return (
    <Layer name="joints" clip={clip}>
      {graphics.map(({ id, line, head, text }) => [
        line && (
          <Line
            key={`${id}-line`}
            name="joint-line"
            points={line}
            stroke={color}
            strokeWidth={style.lineWidth}
            lineCap="butt"
          />
        ),
        head && <Line key={`${id}-head`} name="joint-head" points={head} closed fill={color} />,
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
