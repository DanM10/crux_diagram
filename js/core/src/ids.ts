// Id generation, ported from Flutter's `defaultIdGenerator`: `prefix_<µs base36>_<counter base36>`.
// Ids are opaque (FMT-006); this format is only the default.

let counter = 0;

/** A new id such as `s_lq2x3k9c0_1`. Unique within this process, not across processes. */
export function generateId(prefix: string): string {
  counter++;
  const micros = BigInt(Date.now()) * 1000n;
  return `${prefix}_${micros.toString(36)}_${counter.toString(36)}`;
}

/** `generateId(prefix)` retried until it is not in `taken`. */
export function uniqueId(prefix: string, taken: ReadonlySet<string>): string {
  let id = generateId(prefix);
  while (taken.has(id)) id = generateId(prefix);
  return id;
}
