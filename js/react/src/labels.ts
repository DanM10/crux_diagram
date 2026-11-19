// Texts of the ready-made controls (REA-053), like Flutter's `DrawingEditorLabels`: short
// visible texts with the longer ones as titles. English by default.

export interface EditorLabels {
  readonly fitToScreen: string;
  readonly rename: string;
  readonly delete: string;
  readonly small: string;
  readonly medium: string;
  readonly large: string;
  readonly hide: string;
  readonly show: string;
  readonly hideJoints: string;
  readonly showJoints: string;
}

export type EditorLabelsInput = Partial<EditorLabels>;

export const DEFAULT_EDITOR_LABELS: EditorLabels = {
  fitToScreen: 'Fit to screen',
  rename: 'Rename',
  delete: 'Delete',
  small: 'Small',
  medium: 'Medium',
  large: 'Large',
  hide: 'Hide',
  show: 'Show',
  hideJoints: 'Hide joints',
  showJoints: 'Show joints',
};

/** The defaults with the given texts on top; a field given as `undefined` keeps its default. */
export function resolveEditorLabels(input?: EditorLabelsInput): EditorLabels {
  const labels: Record<string, string> = { ...DEFAULT_EDITOR_LABELS };
  for (const [key, value] of Object.entries(input ?? {})) if (typeof value === 'string') labels[key] = value;
  return labels as unknown as EditorLabels;
}
