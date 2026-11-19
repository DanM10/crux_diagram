# Performance profile (REA-O3)

Goal: dragging with 300 shapes shows no frame over 16 ms.

## How it is measured

`js/react/e2e/performance.spec.ts` loads 300 shapes (rectangles and circles on a 20-column
grid), presses the pointer on one of them and moves it 120 times, with a pause of 8 ms
between moves. A `requestAnimationFrame` loop records the time between frames during the
drag. Run it with `cd js/react && npm run e2e`; the numbers go to `e2e/output/performance.json`.

## Result (2026-11-18)

Headless Chromium 159 on Linux, software rendering, 1100 × 900 viewport:

| Shapes | Frames | Median | p95 | Max | Frames over 20 ms |
|---|---|---|---|---|---|
| 300 | 266 | 16.7 ms | 16.8 ms | 16.8 ms | 0 |

The frame interval is the 60 Hz refresh (16.7 ms), so every frame of the drag was
presented on time; a missed frame would show as 33 ms.

## What this does and does not prove

- It shows that a drag with 300 shapes does not drop frames in this environment.
- A frame loop cannot see work that fits inside one frame, so it does not say how much
  headroom there is. It also does not say anything about a slower machine, a high-refresh
  display or more shapes (see `large-drawings.md` for 1 000 and more).
- The test only fails on a stall (p95 over 250 ms, or more than 5 % of frames missed); it
  does not enforce the 16 ms goal, because a CI machine may be slower than this one.
