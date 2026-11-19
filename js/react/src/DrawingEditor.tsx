import {
  boundsOfShapes,
  handleLocalPosition,
  handlesFor,
  visibleGridStep,
  type Point,
  type Rect as CanvasRect,
  type Shape,
} from '@diagrama-kit/core';
import type { KonvaEventObject } from 'konva/lib/Node';
import { forwardRef, useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { Circle, Group, Layer, Line, Rect } from 'react-konva';
import { useStore } from 'zustand';
import { EditorProvider, useEditor, useEditorConfig, type DrawingEditorHandle, type EditorProviderProps } from './editor-context.js';
import {
  beginDrag,
  cancelDrag,
  endDrag,
  HANDLE_VISUAL_RADIUS,
  ROTATION_STEM_LENGTH,
  tap,
  TAP_SLOP,
  updateDrag,
  type Gesture,
  type HandleContext,
} from './interaction/gestures.js';
import { commandForKey, isTextEntry, runCommand } from './interaction/keyboard.js';
import { DrawingStage } from './render/DrawingStage.js';

export type DrawingEditorProps = Omit<EditorProviderProps, 'children'> & {
  /**
   * Shows the document without selection, dragging or keyboard shortcuts (REA-005).
   * Changes from the parent's `value` and the imperative handle still apply.
   */
  readOnly?: boolean;
};

/**
 * Controlled drawing editor (REA-002). Click or drag shapes to select and move them;
 * while the editor has the focus, `Delete`/`Backspace` delete, `Ctrl/Cmd+Z` undoes,
 * `Ctrl/Cmd+Shift+Z` redoes, `Ctrl/Cmd+D` duplicates and the arrow keys move the
 * selection by 1 (`Shift`: 10) (REA-010 to REA-018).
 */
export const DrawingEditor = forwardRef<DrawingEditorHandle, DrawingEditorProps>(function DrawingEditor({ readOnly, ...props }, ref) {
  return (
    <EditorProvider ref={ref} {...props}>
      <EditorCanvas readOnly={readOnly} />
    </EditorProvider>
  );
});

/** Color of the selection outline and the selection rectangle. */
const SELECTION_COLOR = '#1e88e5';

/** A pointer that went down on the stage, until it is released. */
interface PointerSession {
  readonly pointerId: number;
  readonly downScreen: Point;
  readonly downCanvas: Point;
  gesture: Gesture | null;
  readonly dispose: () => void;
}

/**
 * The editor's stage: the gesture preview while there is one, else the document, with
 * the selection drawn in the `editor-ui` layer. Pointer gestures and shortcuts drive the
 * enclosing editor's store.
 */
export function EditorCanvas({ readOnly = false }: { readOnly?: boolean }) {
  const editor = useEditor();
  const config = useEditorConfig();
  const document = useStore(editor, (state) => state.preview ?? state.document);
  const selection = useStore(editor, (state) => state.selection);
  const [marquee, setMarquee] = useState<CanvasRect | null>(null);
  const focusable = useRef<HTMLDivElement>(null);
  const session = useRef<PointerSession | null>(null);

  // A pointer still down when the editor unmounts, or turns read-only, ends with no change.
  const endSession = useCallback(() => {
    const current = session.current;
    if (!current) return;
    session.current = null;
    current.dispose();
    if (current.gesture) cancelDrag(editor, current.gesture);
    setMarquee(null);
  }, [editor]);
  useEffect(() => endSession, [endSession]);
  useEffect(() => {
    if (readOnly) endSession();
  }, [readOnly, endSession]);

  const onPointerDown = (event: KonvaEventObject<PointerEvent>) => {
    const evt = event.evt;
    if (readOnly || evt.button > 0) return;
    // The same pointer pressed again means its release was lost: start over. Another
    // pointer while one is down is ignored (multi-touch is a zoom gesture).
    if (session.current?.pointerId === evt.pointerId) endSession();
    if (session.current) return;
    const stage = event.target.getStage();
    const downCanvas = stage?.getRelativePointerPosition();
    if (!stage || !downCanvas) return;
    focusable.current?.focus({ preventScroll: true });
    const { gridSize, gridMajorEvery } = config;
    const grid = {
      gridSize,
      visibleStep:
        gridSize !== null && editor.getState().view.showGrid
          ? visibleGridStep({ gridSize, majorEvery: gridMajorEvery, scale: stage.scaleX() })
          : null,
    };
    const handles: HandleContext = {
      scale: stage.scaleX(),
      rotationSnap: { step: config.rotationSnapStep, tolerance: config.rotationSnapTolerance },
    };
    const canvasPoint = (e: PointerEvent) => {
      stage.setPointersPositions(e);
      return stage.getRelativePointerPosition() ?? downCanvas;
    };
    const onMove = (e: PointerEvent) => {
      const current = session.current;
      if (!current || e.pointerId !== current.pointerId) return;
      if (!current.gesture) {
        if (Math.hypot(e.clientX - current.downScreen.x, e.clientY - current.downScreen.y) < TAP_SLOP) return;
        current.gesture = beginDrag(editor, current.downCanvas, grid, handles);
      }
      current.gesture = updateDrag(editor, current.gesture, canvasPoint(e));
      setMarquee(current.gesture.kind === 'marquee' ? current.gesture.rect : null);
    };
    const onUp = (e: PointerEvent) => {
      const current = session.current;
      if (!current || e.pointerId !== current.pointerId) return;
      session.current = null;
      current.dispose();
      if (current.gesture) endDrag(editor, current.gesture);
      else tap(editor, current.downCanvas, handles);
      setMarquee(null);
    };
    const onCancel = (e: PointerEvent) => {
      if (session.current && e.pointerId === session.current.pointerId) endSession();
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onCancel);
    session.current = {
      pointerId: evt.pointerId,
      downScreen: { x: evt.clientX, y: evt.clientY },
      downCanvas,
      gesture: null,
      dispose: () => {
        window.removeEventListener('pointermove', onMove);
        window.removeEventListener('pointerup', onUp);
        window.removeEventListener('pointercancel', onCancel);
      },
    };
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (readOnly || isTextEntry(event.target)) return;
    const command = commandForKey(event);
    if (!command) return;
    event.preventDefault();
    runCommand(editor, command);
  };

  const selected = useMemo(() => {
    if (readOnly || selection.length === 0) return null;
    const ids = new Set(selection);
    const shapes = document.shapes.filter((s) => ids.has(s.id));
    return shapes.length > 0 ? shapes : null;
  }, [readOnly, selection, document]);

  return (
    <div ref={focusable} tabIndex={0} onKeyDown={onKeyDown} style={{ width: '100%', height: '100%' }}>
      <DrawingStage document={document} listening onPointerDown={onPointerDown}>
        {(scale) => (
          <Layer name="editor-ui" listening={false}>
            {selected && <SelectionOverlay shapes={selected} scale={scale} />}
            {marquee && (
              <Rect
                name="selection-marquee"
                x={marquee.left}
                y={marquee.top}
                width={marquee.width}
                height={marquee.height}
                stroke={SELECTION_COLOR}
                strokeWidth={1}
                strokeScaleEnabled={false}
                dash={[4, 4]}
                fill="rgba(30, 136, 229, 0.08)"
              />
            )}
          </Layer>
        )}
      </DrawingStage>
    </div>
  );
}

const toDegrees = (radians: number) => (radians * 180) / Math.PI;

/**
 * The selection outline and, for a single shape, its resize handles and rotation handle
 * with stem (FR-7). A lone shape's outline follows its rotation; several shapes get the
 * outline of their bounds and no handles (MS-5). Sizes are screen pixels, so they are
 * divided by the view `scale`.
 */
function SelectionOverlay({ shapes, scale }: { shapes: readonly Shape[]; scale: number }) {
  const single = shapes.length === 1 ? shapes[0]! : null;
  const bounds = single ? null : boundsOfShapes(shapes);
  const center = single
    ? single.center
    : {
        x: bounds!.left + bounds!.width / 2,
        y: bounds!.top + bounds!.height / 2,
      };
  const width = single ? single.size.width : bounds!.width;
  const height = single ? single.size.height : bounds!.height;
  const rotation = single ? toDegrees(single.rotation) : 0;
  const stem = ROTATION_STEM_LENGTH / scale;
  const handle = {
    radius: HANDLE_VISUAL_RADIUS / scale,
    fill: '#ffffff',
    stroke: SELECTION_COLOR,
    strokeWidth: 1.5,
    strokeScaleEnabled: false,
  };
  return (
    <>
      <Rect
        name="selection-outline"
        x={center.x}
        y={center.y}
        offsetX={width / 2}
        offsetY={height / 2}
        rotation={rotation}
        width={width}
        height={height}
        stroke={SELECTION_COLOR}
        strokeWidth={1.5}
        strokeScaleEnabled={false}
      />
      {single && (
        <Group name="selection-handles" x={center.x} y={center.y} rotation={rotation}>
          <Line
            name="rotation-stem"
            points={[0, -height / 2, 0, -height / 2 - stem]}
            stroke={SELECTION_COLOR}
            strokeWidth={1.5}
            strokeScaleEnabled={false}
          />
          <Circle name="rotation-handle" x={0} y={-height / 2 - stem} {...handle} />
          {handlesFor(single.type).map((h) => {
            const at = handleLocalPosition(h, single.size);
            return <Circle key={h} name={`resize-handle handle-${h}`} x={at.x} y={at.y} {...handle} />;
          })}
        </Group>
      )}
    </>
  );
}
