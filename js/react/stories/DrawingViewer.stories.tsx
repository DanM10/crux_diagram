import type { Meta, StoryObj } from '@storybook/react-vite';
import { DrawingViewer } from '../src/index.js';
import { EMOJI_JOINT, EMPTY, FULL_SAMPLE, JOINTS_HIDDEN, manyShapes } from './documents.js';

const meta = {
  title: 'DrawingViewer',
  component: DrawingViewer,
  decorators: [(Story) => <div style={{ width: 640, height: 480, border: '1px solid #ccc' }}><Story /></div>],
} satisfies Meta<typeof DrawingViewer>;
export default meta;
type Story = StoryObj<typeof meta>;

export const Sample: Story = { args: { document: FULL_SAMPLE } };
export const Empty: Story = { args: { document: EMPTY } };
export const JointsHidden: Story = { args: { document: JOINTS_HIDDEN } };
export const JointNameWithEmoji: Story = { args: { document: EMOJI_JOINT } };
export const ThreeHundredShapes: Story = { args: { document: manyShapes(300) } };
export const CustomDescription: Story = { args: { document: FULL_SAMPLE, alt: 'Floor plan of the second level' } };
