// jsdom has no 2D canvas, no ResizeObserver and no font loading. These fakes let
// react-konva mount and let tests control the container size and font readiness.

/** Fonts recorded by every `measureText` call, to check the label font (REA-030). */
export const measuredFonts: string[] = [];

/** Width per character reported by the fake `measureText`. */
export const FAKE_CHAR_WIDTH = 10;

function fakeContext(canvas: HTMLCanvasElement): CanvasRenderingContext2D {
  const state: Record<string | symbol, unknown> = { canvas, font: '10px sans-serif' };
  return new Proxy(state, {
    get(target, key) {
      if (key in target) return target[key];
      if (key === 'measureText') {
        return (text: string) => {
          measuredFonts.push(String(target.font));
          return { width: Array.from(text).length * FAKE_CHAR_WIDTH };
        };
      }
      if (key === 'getImageData' || key === 'createImageData') {
        return () => ({ data: new Uint8ClampedArray(4), width: 1, height: 1 });
      }
      if (key === 'getTransform') return () => ({ a: 1, b: 0, c: 0, d: 1, e: 0, f: 0 });
      if (key === 'isPointInPath' || key === 'isPointInStroke') return () => false;
      return () => undefined;
    },
    set(target, key, value) {
      target[key] = value;
      return true;
    },
  }) as unknown as CanvasRenderingContext2D;
}

let installed = false;

/** Every canvas encoded by the fake `toBlob`: its size and the arguments of the call. */
export const encoded: { width: number; height: number; type?: string; quality?: unknown }[] = [];

/** Installs the canvas fake once per test file. */
export function installCanvas(): void {
  if (installed) return;
  installed = true;
  HTMLCanvasElement.prototype.getContext = function getContext(this: HTMLCanvasElement) {
    return fakeContext(this);
  } as unknown as typeof HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.toDataURL = () => 'data:,';
  HTMLCanvasElement.prototype.toBlob = function toBlob(this: HTMLCanvasElement, callback: BlobCallback, type?: string, quality?: unknown) {
    encoded.push({ width: this.width, height: this.height, type, quality });
    callback(new Blob(['image'], { type: type ?? 'image/png' }));
  };
}

/** Makes every observed element report `width × height`. */
export function installResizeObserver(width: number, height: number): void {
  globalThis.ResizeObserver = class {
    constructor(private readonly callback: ResizeObserverCallback) {}
    observe(target: Element): void {
      const entry = { target, contentRect: { width, height } } as unknown as ResizeObserverEntry;
      this.callback([entry], this as unknown as ResizeObserver);
    }
    unobserve(): void {}
    disconnect(): void {}
  };
}

/** Replaces `document.fonts` with one whose `ready` resolves when `load()` is called. */
export function installPendingFonts(): { load(): void } {
  let resolve!: () => void;
  const ready = new Promise<void>((r) => {
    resolve = r;
  });
  const fonts = { status: 'loading', ready };
  Object.defineProperty(document, 'fonts', { configurable: true, value: fonts });
  return {
    load() {
      fonts.status = 'loaded';
      resolve();
    },
  };
}

/** Replaces `document.fonts` with one whose `ready` rejects when `fail()` is called. */
export function installFailingFonts(): { fail(): void } {
  let reject!: (error: Error) => void;
  const ready = new Promise<void>((_, r) => {
    reject = r;
  });
  Object.defineProperty(document, 'fonts', { configurable: true, value: { status: 'loading', ready } });
  return { fail: () => reject(new Error('font loading failed')) };
}

/** Removes the fake `ResizeObserver`, so the stage falls back to the element size. */
export function removeResizeObserver(): void {
  Reflect.deleteProperty(globalThis, 'ResizeObserver');
}

/** Makes every element report `width × height` as its client size. */
export function setClientSize(width: number, height: number): void {
  Object.defineProperty(HTMLElement.prototype, 'clientWidth', { configurable: true, get: () => width });
  Object.defineProperty(HTMLElement.prototype, 'clientHeight', { configurable: true, get: () => height });
}

/** Removes the fake `document.fonts`. */
export function removeFonts(): void {
  Reflect.deleteProperty(document, 'fonts');
}
