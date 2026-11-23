# 06 · Spec de la geometría de dibujo exportable

Depende de: `02-spec-formato-json.md` y `04-spec-react-core.md`. Implementación: `@crux-diagram/core` (`computeGeometry`). Consumidores: el editor React y cualquier pintor externo (por ejemplo, un backend con Java2D).

---

## 1. Objetivo

Dar, junto con el documento v1, un JSON aparte con **primitivas listas para pintar**, en unidades del lienzo, para que un pintor externo dibuje el documento sin conocer las reglas del formato. El pintor solo pinta, no calcula.

La geometría **no** va dentro del documento: `parse` descarta los campos desconocidos (FMT-009) y el formato v1 no cambia.

## 2. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| GEO-O1 | Lo que dibuja el editor es exactamente la geometría exportada | Test en `react` que compara la escena con `computeGeometry` |
| GEO-O2 | Un pintor externo reproduce el dibujo leyendo solo esta estructura | Fixtures `fixtures/drawing-geometry/` |
| GEO-O3 | La estructura se verifica igual en cualquier lenguaje | `validateGeometry` con códigos estables (sección 7) |

## 3. Alcance

**Dentro:** figuras y juntas (línea guía, punta y etiqueta) del documento, en el orden de pintado.

**Fuera:** cambios al formato v1 o a `schemaVersion`; el paquete Flutter; el render en el servidor; la interfaz del editor (selección, asas, cuadrícula).

## 4. Función

```ts
export function computeGeometry(
  document: DrawingDocument,
  options: { measurer: TextMeasurer; style?: JointStyle },
): DrawingGeometry;
```

- **GEO-001** `style` por defecto: `DEFAULT_JOINT_STYLE`.
- **GEO-002** Es pura y determinista: el mismo documento con el mismo `measurer` y estilo da la misma salida. No modifica el documento.
- **GEO-003** El editor y el visor de `react` pintan desde esta función. No hay una segunda implementación.

## 5. Estructura

```ts
interface DrawingGeometry {
  geometryVersion: 1;
  canvas: { width: number; height: number };
  shapes: ShapeGeometry[];    // de atrás hacia adelante
  joints: JointGeometry[];    // encima de todas las figuras
}

interface ShapeGeometry {
  id: string;                 // shape.id del documento
  kind: 'rect' | 'ellipse';   // square/rectangle → rect; circle → ellipse
  center: Point;
  width: number;
  height: number;
  rotation: number;           // radianes, sentido horario (+y hacia abajo)
  fill: number | null;        // ARGB, o null si no se pinta
  stroke: { color: number; width: number } | null;
}

interface JointGeometry {
  id: string;                 // joint.id del documento
  anchor: Point;              // punto del ancla en el lienzo
  labelRect: Rect;            // { left, top, width, height }, con padding incluido
  text: {
    value: string;            // joint.name
    x: number;                // esquina superior izquierda del texto
    y: number;
    width: number;            // tamaño medido por el measurer
    height: number;
    fontSize: number;         // 30 / 34 / 38 según labelSize
    fontFamily: string;       // "Arial" (LABEL_FONT_FAMILY)
    bold: boolean;
    color: number;            // ARGB
  };
  line: { from: Point; to: Point } | null;  // del inicio de la flecha a la base de la punta
  arrowhead: [Point, Point, Point] | null;  // [punta, izquierda, derecha]
  lineWidth: number;          // 2.5 por defecto
  lineColor: number;          // ARGB
}
```

- **GEO-010** `geometryVersion` es `1`. Un cambio incompatible de la estructura sube este número.
- **GEO-011** `canvas` copia `document.canvas`.

### 5.1 Figuras

- **GEO-020** Hay un `ShapeGeometry` por figura, en el orden de `document.shapes` (de atrás hacia adelante).
- **GEO-021** La figura se pinta trasladando a `center`, girando `rotation` y dibujando el rectángulo o la elipse inscrita de `width × height` centrado en el origen. El trazo va centrado sobre el contorno.
- **GEO-022** Un relleno o trazo con alfa 0, o un trazo con ancho 0, no se pinta: `fill` o `stroke` es `null`. (Es la regla de Flutter y de `react`: un trazo con alfa 0 es invisible, así que pintarlo o no da la misma imagen.)

### 5.2 Juntas

- **GEO-030** `jointDisplay.visible === false` → `joints: []`.
- **GEO-031** Una junta cuya figura o ancla no existe se omite (REC-054). Las demás conservan el orden de `document.joints`.
- **GEO-032** `labelRect` es el rectángulo de FMT-042: centrado en `anchor + labelOffset`, de tamaño `text + 2 · labelPadding`.
- **GEO-033** `text.x = labelRect.left + labelPadding` y `text.y = labelRect.top + labelPadding`; `text.width` y `text.height` son los del `measurer`.
- **GEO-034** Si el ancla está dentro de la etiqueta (FMT-043), o el inicio de la flecha coincide con el ancla (FMT-045), `line` y `arrowhead` son `null`.
- **GEO-035** `arrowhead` sigue FMT-044 con el tamaño escalado de `arrowheadSize`. `line` va del inicio de la flecha al punto medio de la base de la punta, y es `null` si la distancia del inicio al ancla no supera el largo de la punta; en ese caso `arrowhead` sí se da.
- **GEO-036** `text.color` y `lineColor` son `style.color`; `lineWidth` es `style.lineWidth`; `text.bold` es `style.labelBold`; `text.fontFamily` es `LABEL_FONT_FAMILY`.

## 6. Orden de pintado

Fondo (no incluido: lo decide el consumidor), figuras en orden, y luego, por cada junta: línea (si hay), punta (si hay, rellena) y texto. La línea usa extremos planos (`butt`).

## 7. Validación de la forma

`validateGeometry(document, geometry): GeometryError[]`, con `GeometryError = { code, path, message }`. Una lista vacía significa válida. `path` sigue la forma de `validate` (`joints[2].labelRect.width`).

- **GEO-040** Comprueba solo la **forma**, no recalcula la geometría.

| Código | Cuándo |
|---|---|
| `not_object` | La raíz, un registro o un campo compuesto no es un objeto |
| `unsupported_version` | `geometryVersion` no es `1` |
| `missing_field` | Falta un campo requerido |
| `not_finite` | Un número no es finito (o no es número) |
| `negative_size` | `labelRect.width`/`height`, `text.width`/`height`, `width`/`height` de figura, `lineWidth` o `stroke.width` son negativos |
| `wrong_type` | Un campo tiene otro tipo (`id`, `value`, `fontFamily` no son texto; `bold` no es booleano; `kind` no es `rect` ni `ellipse`) |
| `bad_arrowhead` | `arrowhead` no es `null` ni una lista de tres puntos |
| `id_mismatch` | Los ids de `joints` no son, en orden, los de las juntas dibujables del documento, o los de `shapes` no son los de `document.shapes` |

- **GEO-041** Los códigos son estables: se pueden agregar, nunca cambiar ni reutilizar. Sirven de referencia para reimplementar la verificación en otro lenguaje.

## 8. Fuente del texto

- **GEO-050** El texto se mide con la fuente del navegador (`Arial`), así que `text.width` puede diferir unos píxeles de lo que mide otra plataforma (FMT-050). Un pintor externo debe **centrar** el texto dentro de `labelRect` con una fuente equivalente, en lugar de pintarlo en `text.x`, `text.y`.

## 9. Fixtures

`fixtures/drawing-geometry/`: pares `documento → geometría esperada` calculados con `ApproximateTextMeasurer`, para que sean deterministas. Los genera `js/core/scripts/generate-drawing-geometry.mjs` (Flutter no implementa esta función). Casos: junta normal, ancla dentro de la etiqueta, línea más corta que la punta, junta con figura inexistente, `visible: false`, los tres `labelSize` y figuras giradas. Se comparan con tolerancia `1e-6`.

## 10. Criterios de aceptación

- [ ] Cada requisito `GEO-xxx` tiene un test que cita su ID.
- [ ] `test/conformance/` de `core` pasa todas las fixtures de `fixtures/drawing-geometry/`.
- [ ] Un test de `react` confirma que la escena del editor sale de `computeGeometry` (misma salida para el mismo documento y `measurer`).
- [ ] `DrawingEditorHandle.getGeometry()` devuelve la geometría del documento confirmado.

## 11. Preguntas abiertas

- Si Flutter llega a guardar documentos, necesitará la misma función; hoy queda fuera de alcance.
