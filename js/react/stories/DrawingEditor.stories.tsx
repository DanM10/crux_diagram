import type { DrawingDocument } from '@crux-diagram/core';
import type { Meta, StoryObj } from '@storybook/react-vite';
import { useState } from 'react';
import { DrawingEditor, Toolbar, type DrawingEditorProps } from '../src/index.js';
import { EMPTY, FULL_SAMPLE, manyShapes } from './documents.js';

function Controlled({ initial, ...rest }: { initial: DrawingDocument } & Partial<DrawingEditorProps>) {
  const [doc, setDoc] = useState(initial);
  return (
    <div style={{ width: 800, height: 640, border: '1px solid #ccc' }}>
      <DrawingEditor {...rest} value={doc} onChange={setDoc}>
        {rest.readOnly ? null : <Toolbar />}
      </DrawingEditor>
    </div>
  );
}

const meta = { title: 'DrawingEditor', component: Controlled } satisfies Meta<typeof Controlled>;
export default meta;
type Story = StoryObj<typeof meta>;

export const WithToolbar: Story = { args: { initial: FULL_SAMPLE } };
export const EmptyCanvas: Story = { args: { initial: EMPTY } };
export const ReadOnly: Story = { args: { initial: FULL_SAMPLE, readOnly: true } };
export const NoGrid: Story = { args: { initial: FULL_SAMPLE, config: { gridSize: null } } };
export const ThreeHundredShapes: Story = { args: { initial: manyShapes(300) } };
