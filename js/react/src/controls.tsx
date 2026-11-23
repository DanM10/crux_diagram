// Building blocks of the ready-made controls (REA-053): inline styles only, no global CSS.
import type { CSSProperties } from 'react';

export const controlRowStyle: CSSProperties = {
  display: 'flex',
  gap: 4,
  padding: 4,
  overflowX: 'auto',
  font: '12px sans-serif',
};

export interface ControlButtonProps {
  readonly label: string;
  /** The longer text, shown as the tooltip; defaults to the label. */
  readonly title?: string;
  /** Marks a toggle or a choice as selected (`aria-pressed`); omit for a plain action. */
  readonly pressed?: boolean;
  readonly disabled?: boolean;
  readonly onClick: () => void;
}

export function ControlButton({ label, title, pressed, disabled, onClick }: ControlButtonProps) {
  return (
    <button
      type="button"
      title={title ?? label}
      aria-pressed={pressed}
      disabled={disabled}
      onClick={onClick}
      style={{ flex: '1 0 48px', minHeight: 48, font: 'inherit', fontWeight: pressed ? 700 : 400 }}
    >
      {label}
    </button>
  );
}
