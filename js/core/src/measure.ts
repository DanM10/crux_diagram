// Text measurement (REC-052). Label boxes depend on the platform font and are not
// pixel-interoperable (FMT-050), so the measurer is injected.

export interface TextMeasurer {
  measure(text: string, fontSize: number, bold: boolean): { width: number; height: number };
}

/** The part of a 2D canvas context the measurer needs. */
export interface MeasuringContext {
  font: string;
  measureText(text: string): { width: number; fontBoundingBoxAscent?: number; fontBoundingBoxDescent?: number };
}

/** Line height used when the context reports no font metrics. */
const FALLBACK_LINE_HEIGHT = 1.2;

/** Browser measurer based on `CanvasRenderingContext2D.measureText`. */
export class CanvasTextMeasurer implements TextMeasurer {
  private readonly context: MeasuringContext;
  private readonly fontFamily: string;

  constructor(options: { context?: MeasuringContext; fontFamily?: string } = {}) {
    this.fontFamily = options.fontFamily ?? 'sans-serif';
    const context = options.context ?? createContext();
    if (!context) {
      throw new Error('CanvasTextMeasurer needs a canvas (browser) or an explicit context; in Node use ApproximateTextMeasurer or your own TextMeasurer');
    }
    this.context = context;
  }

  measure(text: string, fontSize: number, bold: boolean): { width: number; height: number } {
    this.context.font = `${bold ? 'bold ' : ''}${fontSize}px ${this.fontFamily}`;
    const m = this.context.measureText(text);
    const ascent = m.fontBoundingBoxAscent;
    const descent = m.fontBoundingBoxDescent;
    const height =
      ascent !== undefined && descent !== undefined ? ascent + descent : fontSize * FALLBACK_LINE_HEIGHT;
    return { width: m.width, height };
  }
}

function createContext(): MeasuringContext | null {
  const g = globalThis as {
    OffscreenCanvas?: new (w: number, h: number) => { getContext(type: '2d'): MeasuringContext | null };
    document?: { createElement(tag: 'canvas'): { getContext(type: '2d'): MeasuringContext | null } };
  };
  if (g.OffscreenCanvas) return new g.OffscreenCanvas(1, 1).getContext('2d');
  if (g.document) return g.document.createElement('canvas').getContext('2d');
  return null;
}

/**
 * Measurer for environments without a canvas (Node). Boxes are APPROXIMATE (FMT-050):
 * every character is `0.6 × fontSize` wide (0.65 in bold) and the line is `1.2 × fontSize` tall.
 */
export class ApproximateTextMeasurer implements TextMeasurer {
  measure(text: string, fontSize: number, bold: boolean): { width: number; height: number } {
    const chars = Array.from(text).length;
    return { width: chars * fontSize * (bold ? 0.65 : 0.6), height: fontSize * FALLBACK_LINE_HEIGHT };
  }
}
