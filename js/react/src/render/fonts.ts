// Font readiness and the label measurer (REA-030, REA-032). Client only: nothing here
// runs at import time.

import { CanvasTextMeasurer, LABEL_FONT_FAMILY, type TextMeasurer } from '@crux-diagram/core';
import { useEffect, useState } from 'react';

interface FontSet {
  readonly status?: string;
  readonly ready: Promise<unknown>;
}

function fontSet(): FontSet | undefined {
  return (globalThis.document as { fonts?: FontSet } | undefined)?.fonts;
}

/** Resolves when `document.fonts` has settled, also when loading fails; at once without a font set (REA-032). */
export async function whenFontsReady(): Promise<void> {
  const fonts = fontSet();
  if (!fonts || fonts.status === 'loaded') return;
  await fonts.ready.catch(() => undefined);
}

/** Whether `document.fonts` has settled; labels are measured only after it has (REA-032). */
export function useFontsReady(): boolean {
  const [ready, setReady] = useState(() => {
    const fonts = fontSet();
    return !fonts || fonts.status === 'loaded';
  });
  useEffect(() => {
    if (ready) return;
    let live = true;
    // A failed load still measures, with whatever font the browser falls back to.
    const settle = () => {
      if (live) setReady(true);
    };
    void fontSet()?.ready.then(settle, settle);
    return () => {
      live = false;
    };
  }, [ready]);
  return ready;
}

/** One measurer per component, created on first use in the browser with the label font. */
export function useLabelMeasurer(): () => TextMeasurer {
  const [get] = useState(() => {
    let measurer: TextMeasurer | undefined;
    return () => (measurer ??= new CanvasTextMeasurer({ fontFamily: LABEL_FONT_FAMILY }));
  });
  return get;
}
