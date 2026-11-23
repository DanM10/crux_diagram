'use client';
import { JOINT_LABEL_SIZES, type JointLabelSize } from '@crux-diagram/core';
import type { CSSProperties } from 'react';
import { useStore } from 'zustand';
import { useEditor, useEditorLabels } from './editor-context.js';
import { beginRename, setJointLabelSize, setJointsVisible } from './interaction/joints.js';
import { runCommand } from './interaction/keyboard.js';
import { ControlButton, controlRowStyle } from './controls.js';

/**
 * Joint display bar (REA-024): label size as a single choice, and show/hide. With a joint
 * selected it adds Rename and Delete. Render it inside a `DrawingEditor`.
 */
export function JointDisplayBar({ style }: { style?: CSSProperties }) {
  const editor = useEditor();
  const labels = useEditorLabels();
  const { labelSize, visible } = useStore(editor, (state) => state.document.jointDisplay);
  const selectedJoint = useStore(editor, (state) => state.selectedJoint);
  return (
    <div role="toolbar" aria-label="Joint display" style={{ ...controlRowStyle, ...style }}>
      {JOINT_LABEL_SIZES.map((size: JointLabelSize) => (
        <ControlButton key={size} label={labels[size]} pressed={labelSize === size} onClick={() => setJointLabelSize(editor, size)} />
      ))}
      <ControlButton
        label={visible ? labels.hide : labels.show}
        title={visible ? labels.hideJoints : labels.showJoints}
        pressed={!visible}
        onClick={() => setJointsVisible(editor, !visible)}
      />
      {selectedJoint && (
        <>
          <ControlButton label={labels.rename} onClick={() => beginRename(editor, selectedJoint)} />
          <ControlButton label={labels.delete} onClick={() => runCommand(editor, { type: 'delete' })} />
        </>
      )}
    </div>
  );
}
