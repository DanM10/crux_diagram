import {
  anchorPositionOf,
  anchorsOf,
  boundsOfShapes,
  clampZoom,
  DEFAULT_JOINT_STYLE,
  handleLocalPosition,
  handlesFor,
  visibleGridStep,
  type DrawingDocument,
  type Point,
  type Rect as CanvasRect,
  type Shape,
  type ViewportZoom,
} from '@diagrama-kit/core';
import type { KonvaEventObject } from 'konva/lib/Node';
import { forwardRef, useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { Circle, Group, Layer, Line, Rect } from 'react-konva';
import { useStore } from 'zustand';
import { EditorProvider, useEditor, useEditorConfig, type DrawingEditorHandle, type EditorProviderProps } from './editor-context.js';
import {
  beginDrag,
  beginLabelDrag,
  cancelDrag,
  endDrag,
  HANDLE_VISUAL_RADIUS,
  labelAt,
  ROTATION_STEM_LENGTH,
  tap,
  TAP_SLOP,
  updateDrag,
  type Gesture,
  type HandleContext,
  type LabelRect,
} from './interaction/gestures.js';
import { NameEditor } from './NameEditor.js';
import { ANCHOR_VISUAL_RADIUS, beginRename, cancelNaming, confirmNaming, jointToolTap } from './interaction/joints.js';
import { commandForKey, isTextEntry, runCommand } from './interaction/keyboard.js';
import { panBy, wheelZoom } from './interaction/viewport.js';
import { DrawingStage } from './render/DrawingStage.js';
import { useFontsReady, useLabelMeasurer } from './render/fonts.js';
import { placeJoints } from './render/scene.js';

/** Longest time between the two taps of a double tap on a label, in milliseconds (ZM-4). */
const DOUBLE_TAP_TIMEOUT = 300;

export type DrawingEditorProps = EditorProviderProps & {
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
export const DrawingEditor = forwardRef<DrawingEditorHandle, DrawingEditorProps>(function DrawingEditor({ readOnly, children, ...props }, ref) {
  return (
    <EditorProvider ref={ref} {...props}>
      {children === undefined ? (
        <EditorCanvas readOnly={readOnly} />
      ) : (
        // Controls (REA-053) go above the canvas, which takes the rest of the height.
        <div style={{ display: 'flex', flexDirection: 'column', width: '100%', height: '100%' }}>
          {children}
          <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
            <EditorCanvas readOnly={readOnly} />
          </div>
        </div>
      )}
    </EditorProvider>
  );
});

/** Color of the selection outline and the selection rectangle. */
const SELECTION_COLOR = '#1e88e5';

/** Color of the ring on the anchor a shape is snapping onto (SN-3). */
const SNAP_COLOR = '#ff9800';

/** A pointer that went down on the stage, until it is released. */
interface PointerSession {
  readonly pointerId: number;
  readonly downScreen: Point;
  readonly downCanvas: Point;
  gesture: Gesture | null;
  /** The view when a pan started, once this pointer is panning instead of editing (REA-016). */
  pan: ViewportZoom | null;
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
  const zoom = useStore(editor, (state) => state.view.zoom);
  const tool = useStore(editor, (state) => state.tool);
  const naming = useStore(editor, (state) => state.naming);
  const selectedJoint = useStore(editor, (state) => state.selectedJoint);
  const snapHighlight = useStore(editor, (state) => state.snapHighlight);
  const selection = useStore(editor, (state) => state.selection);
  const [marquee, setMarquee] = useState<CanvasRect | null>(null);
  const focusable = useRef<HTMLDivElement>(null);
  const session = useRef<PointerSession | null>(null);
  const spaceDown = useRef(false);
  const lastLabelTap = useRef<{ jointId: string; time: number } | null>(null);
  const fontsReady = useFontsReady();
  const measurer = useLabelMeasurer();
  // The labels as drawn, to hit-test them; before the fonts load none are drawn.
  const labelRects = useCallback((): LabelRect[] => {
    if (!fontsReady) return [];
    return placeJoints(editor.getDocument(), DEFAULT_JOINT_STYLE, measurer()).map((p) => ({ jointId: p.joint.id, rect: p.labelRect }));
  }, [editor, fontsReady, measurer]);

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
    const { gridSize, gridMajorEvery, anchorSnapThreshold } = config;
    const grid = {
      gridSize,
      // The threshold is in screen pixels (REA-026); gestures work in canvas units.
      anchorSnapDistance: anchorSnapThreshold === null ? null : anchorSnapThreshold / stage.scaleX(),
      visibleStep:
        gridSize !== null && editor.getState().view.showGrid
          ? visibleGridStep({ gridSize, majorEvery: gridMajorEvery, scale: stage.scaleX() })
          : null,
    };
    const handles: HandleContext = {
      scale: stage.scaleX(),
      rotationSnap: { step: config.rotationSnapStep, tolerance: config.rotationSnapTolerance },
      labels: labelRects(),
    };
    const area = { width: stage.width(), height: stage.height() };
    const shownZoom = () => clampZoom(editor.getState().view.zoom, editor.getDocument().canvas, area);
    const canvasPoint = (e: PointerEvent) => {
      stage.setPointersPositions(e);
      return stage.getRelativePointerPosition() ?? downCanvas;
    };
    const onMove = (e: PointerEvent) => {
      const current = session.current;
      if (!current || e.pointerId !== current.pointerId) return;
      if (!current.pan && !current.gesture) {
        if (Math.hypot(e.clientX - current.downScreen.x, e.clientY - current.downScreen.y) < TAP_SLOP) return;
        // The joint tool never moves, resizes or rotates shapes (JT-1).
        // Labels can be dragged in any tool (REA-022).
        current.gesture =
          editor.getState().tool === 'joint'
            ? (beginLabelDrag(editor, current.downCanvas, handles.labels ?? []) ?? { kind: 'none' })
            : beginDrag(editor, current.downCanvas, grid, handles);
        // A drag that grabs nothing pans when zoomed in (REA-016); in selection mode it is a marquee.
        if (current.gesture.kind === 'none' && editor.getState().view.zoom.zoom > 1) current.pan = shownZoom();
      }
      if (current.pan) {
        const delta = { dx: e.clientX - current.downScreen.x, dy: e.clientY - current.downScreen.y };
        editor.setZoom(panBy(current.pan, delta, editor.getDocument().canvas, area));
        return;
      }
      if (!current.gesture) return;
      current.gesture = updateDrag(editor, current.gesture, canvasPoint(e));
      setMarquee(current.gesture.kind === 'marquee' ? current.gesture.rect : null);
    };
    const onUp = (e: PointerEvent) => {
      const current = session.current;
      if (!current || e.pointerId !== current.pointerId) return;
      session.current = null;
      current.dispose();
      if (current.gesture) endDrag(editor, current.gesture);
      else if (!current.pan) {
        if (editor.getState().tool === 'joint') {
          jointToolTap(editor, current.downCanvas, {
            scale: handles.scale,
            namePrefix: config.jointNamePrefix,
            nameMaxLength: config.jointNameMaxLength,
            labels: handles.labels,
          });
        } else tap(editor, current.downCanvas, handles);
        // The first tap of a double tap acts at once; the second, on the same label, renames (NM-2, ZM-4).
        const labeled = labelAt(handles.labels ?? [], current.downCanvas);
        const now = performance.now();
        const last = lastLabelTap.current;
        if (labeled && last?.jointId === labeled && now - last.time <= DOUBLE_TAP_TIMEOUT) {
          lastLabelTap.current = null;
          beginRename(editor, labeled);
        } else lastLabelTap.current = labeled ? { jointId: labeled, time: now } : null;
      }
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
      // With the space bar down the drag pans from the start, over shapes too (REA-016).
      pan: spaceDown.current ? shownZoom() : null,
      dispose: () => {
        window.removeEventListener('pointermove', onMove);
        window.removeEventListener('pointerup', onUp);
        window.removeEventListener('pointercancel', onCancel);
      },
    };
  };

  const onWheel = (event: KonvaEventObject<WheelEvent>) => {
    const stage = event.target.getStage();
    const focal = stage?.getPointerPosition();
    if (!stage || !focal) return;
    event.evt.preventDefault();
    const { deltaY, deltaMode, ctrlKey } = event.evt;
    const area = { width: stage.width(), height: stage.height() };
    editor.setZoom(wheelZoom(editor.getState().view.zoom, { deltaY, deltaMode, ctrlKey, focal }, editor.getDocument().canvas, area));
  };

  // The space bar pans only while the container itself has the focus, so it still activates buttons.
  const onKeyUp = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === ' ') spaceDown.current = false;
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (readOnly || isTextEntry(event.target)) return;
    if (event.key === ' ' && event.target === event.currentTarget) {
      event.preventDefault();
      spaceDown.current = true;
      return;
    }
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
    <div
      ref={focusable}
      tabIndex={0}
      onKeyDown={onKeyDown}
      onKeyUp={onKeyUp}
      onBlur={() => void (spaceDown.current = false)}
      style={{ position: 'relative', width: '100%', height: '100%' }}
    >
      <DrawingStage
        document={document}
        listening
        zoom={zoom}
        onWheel={onWheel}
        onPointerDown={onPointerDown}
        onAreaChange={editor.setStageArea}
        overlay={(viewport) =>
          naming &&
          !readOnly && (
            <NameEditor
              // A new editor per name editing session, so the field starts from the joint's name.
              key={naming.jointId}
              document={document}
              naming={naming}
              viewport={viewport}
              suggestions={config.jointNameSuggestions}
              onConfirm={(name) => confirmNaming(editor, name, config.jointNameMaxLength)}
              onCancel={() => cancelNaming(editor)}
            />
          )
        }
      >
        {(scale) => (
          <Layer name="editor-ui" listening={false}>
            {selected && <SelectionOverlay shapes={selected} scale={scale} />}
            {!readOnly && tool === 'joint' && <AnchorDots document={document} scale={scale} />}
            {snapHighlight.map((at) => (
              <Circle
                key={`${at.x},${at.y}`}
                name="snap-highlight"
                x={at.x}
                y={at.y}
                radius={(ANCHOR_VISUAL_RADIUS + 4) / scale}
                stroke={SNAP_COLOR}
                strokeWidth={2.5}
                strokeScaleEnabled={false}
              />
            ))}
            {selectedJoint && <JointRing document={document} jointId={selectedJoint} scale={scale} />}
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
      {zoom.zoom > FIT_BUTTON_MIN_ZOOM && <ZoomControls zoom={zoom.zoom} onFit={editor.fitToScreen} />}
    </div>
  );
}

/** The fit button and the percentage show while the zoom is above 1× (ZM-1). */
const FIT_BUTTON_MIN_ZOOM = 1.005;

/** Fit-to-screen button with the zoom percentage, bottom right of the drawing area (ZM-1, ZM-2). */
function ZoomControls({ zoom, onFit }: { zoom: number; onFit: () => void }) {
  return (
    <div style={{ position: 'absolute', right: 16, bottom: 16, display: 'flex', alignItems: 'center', gap: 8, font: '12px sans-serif' }}>
      <span>{`${Math.round(zoom * 100)}%`}</span>
      <button type="button" onClick={onFit}>
        Fit to screen
      </button>
    </div>
  );
}

/** Anchor dots of every shape for the joint tool; filled where a joint exists (JT-1). Sizes are screen pixels. */
function AnchorDots({ document, scale }: { document: DrawingDocument; scale: number }) {
  const occupied = new Set(document.joints.map((j) => `${j.shapeId}/${j.anchorId}`));
  return (
    <>
      {document.shapes.flatMap((shape) =>
        anchorsOf(shape).map((anchor) => {
          const taken = occupied.has(`${shape.id}/${anchor.id}`);
          return (
            <Circle
              key={`${shape.id}/${anchor.id}`}
              name={taken ? 'anchor-dot anchor-occupied' : 'anchor-dot'}
              x={anchor.position.x}
              y={anchor.position.y}
              radius={ANCHOR_VISUAL_RADIUS / scale}
              fill={taken ? SELECTION_COLOR : '#ffffff'}
              stroke={SELECTION_COLOR}
              strokeWidth={1.5}
              strokeScaleEnabled={false}
            />
          );
        }),
      )}
    </>
  );
}

/** The ring around the anchor of the selected joint (AW-7). */
function JointRing({ document, jointId, scale }: { document: DrawingDocument; jointId: string; scale: number }) {
  const joint = document.joints.find((j) => j.id === jointId);
  const shape = joint && document.shapes.find((s) => s.id === joint.shapeId);
  const anchor = shape && joint ? anchorPositionOf(shape, joint.anchorId) : null;
  if (!anchor) return null;
  return (
    <Circle
      name="joint-selection-ring"
      x={anchor.x}
      y={anchor.y}
      radius={(ANCHOR_VISUAL_RADIUS + 4) / scale}
      stroke={SELECTION_COLOR}
      strokeWidth={2}
      strokeScaleEnabled={false}
    />
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
