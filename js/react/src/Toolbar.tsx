import type { CSSProperties } from 'react';
import { useStore } from 'zustand';
import { ControlButton, controlRowStyle } from './controls.js';
import { useEditor, useEditorConfig, useEditorLabels } from './editor-context.js';
import { useHistoryAvailability } from './hooks.js';
import { runCommand } from './interaction/keyboard.js';
import { addPaletteShape, visibleCenterOf } from './interaction/palette.js';
import { JointDisplayBar } from './JointDisplayBar.js';

/** Height of both rows, so selecting never moves a button or resizes the drawing area (TB-2). */
const ROW_HEIGHT = 56;

/**
 * Ready-made toolbar (REA-053): the selection bar above the create bar. Render it inside a
 * `DrawingEditor`, as a child.
 */
export function Toolbar({ style }: { style?: CSSProperties }) {
  const editor = useEditor();
  const config = useEditorConfig();
  const labels = useEditorLabels();
  const tool = useStore(editor, (state) => state.tool);
  const showGrid = useStore(editor, (state) => state.view.showGrid);
  const selectionMode = useStore(editor, (state) => state.selectionMode);
  const selection = useStore(editor, (state) => state.selection);
  const { canUndo, canRedo } = useHistoryAvailability(editor);
  const document = useStore(editor, (state) => state.document);

  const add = (type: 'square' | 'rectangle' | 'circle') =>
    addPaletteShape(editor, type, { center: visibleCenterOf(editor), gridSize: config.gridSize, style: config.shapeStyle });
  // Rotate 90° only turns a single shape that is not in a group (MS-5).
  const single = selection.length === 1 && !document.groups.some((g) => g.shapeIds.includes(selection[0]!));
  const rowStyle = { ...controlRowStyle, minHeight: ROW_HEIGHT, boxSizing: 'border-box' } as const;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', ...style }}>
      {tool === 'joint' ? (
        <JointDisplayBar style={rowStyle} />
      ) : (
        <div role="toolbar" aria-label={labels.selectionBar} style={rowStyle}>
          <ControlButton label={labels.select} title={labels.selectMode} pressed={selectionMode} onClick={() => editor.setSelectionMode(!selectionMode)} />
          {selection.length > 0 && (
            <>
              {single && <ControlButton label={labels.rotate} title={labels.rotate90} onClick={() => runCommand(editor, { type: 'rotate90' })} />}
              <ControlButton label={labels.duplicate} onClick={() => runCommand(editor, { type: 'duplicate' })} />
              <ControlButton label={labels.front} title={labels.bringToFront} onClick={() => runCommand(editor, { type: 'front' })} />
              <ControlButton label={labels.back} title={labels.sendToBack} onClick={() => runCommand(editor, { type: 'back' })} />
              <ControlButton label={labels.delete} onClick={() => runCommand(editor, { type: 'delete' })} />
            </>
          )}
        </div>
      )}
      <div role="toolbar" aria-label={labels.createBar} style={rowStyle}>
        <ControlButton label={labels.square} onClick={() => add('square')} />
        <ControlButton label={labels.rectangle} onClick={() => add('rectangle')} />
        <ControlButton label={labels.circle} onClick={() => add('circle')} />
        <ControlButton
          label={labels.joint}
          title={labels.jointTool}
          pressed={tool === 'joint'}
          onClick={() => editor.setTool(tool === 'joint' ? 'select' : 'joint')}
        />
        {config.gridSize !== null && (
          <ControlButton
            label={labels.grid}
            title={showGrid ? labels.hideGrid : labels.showGrid}
            pressed={showGrid}
            onClick={() => editor.setShowGrid(!showGrid)}
          />
        )}
        <ControlButton label={labels.undo} disabled={!canUndo} onClick={() => editor.undo()} />
        <ControlButton label={labels.redo} disabled={!canRedo} onClick={() => editor.redo()} />
      </div>
    </div>
  );
}
