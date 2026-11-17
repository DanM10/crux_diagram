# 04 · Spec de `@diagrama-kit/core` (TypeScript)

Depende de: `02-spec-formato-json.md`. Publicación: npm. Corre en **Node y navegador**.

---

## 1. Objetivo

Librería TypeScript **sin dependencias de React** que lee, valida, calcula y serializa dibujos del formato JSON v1. Es la base del editor React y puede usarse sola en un servidor Node, en Vue, Angular, etc.

Es un **port** de la lógica del modelo y la geometría de Flutter (`soft_drawer_service`). Donde haya duda, manda el comportamiento de Flutter y las fixtures generadas con él.

## 2. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| REC-O1 | Pasa el 100 % de las fixtures de conformidad | `vitest` corre `fixtures/` |
| REC-O2 | Se puede usar en Node y navegador con el mismo código | Tests en ambos entornos |
| REC-O3 | Cero dependencias en runtime | `package.json` sin `dependencies` |
| REC-O4 | Tipos TypeScript completos y exactos | `tsc --noEmit` y tests de tipos |
| REC-O5 | Un documento escrito por Flutter se lee sin pérdida, y viceversa | Fixtures `roundtrip/` |

## 3. Alcance

**Dentro:** tipos, validación, anclas y geometría de juntas, serialización, utilidades de nombre, operaciones puras de edición (mover, redimensionar, rotar, juntas, grupos).

**Fuera:** render, UI, estado reactivo, persistencia, exportación de imagen (eso es del paquete `react`).

## 4. Estructura propuesta

```
js/core/
├── src/
│   ├── types.ts            ← DrawingDocument, Shape, Joint, Group, JointDisplay…
│   ├── color.ts            ← ARGB ↔ CSS
│   ├── validate.ts         ← validate(json): DrawingError[]
│   ├── io.ts               ← parse / serialize
│   ├── angle.ts            ← normalizeAngle y conversión a grados
│   ├── geometry/
│   │   ├── anchors.ts      ← anchorsOf, anchorPositionOf
│   │   ├── joints.ts       ← defaultLabelOffset, clampLabelOffset, leaderLineStart, arrowheadPoints
│   │   └── transforms.ts   ← rotación de vectores, mundo ↔ local
│   ├── names.ts            ← nextJointName, normalizeJointName
│   ├── style.ts            ← JointStyle y valores por defecto (spec 02, sección 12)
│   ├── measure.ts          ← TextMeasurer
│   ├── ops.ts              ← funciones puras de edición
│   └── index.ts
├── test/conformance/
└── package.json
```

## 5. Requisitos

### 5.1 Tipos y I/O

- **REC-010** Tipos de unión discriminada por `type` (`square`, `rectangle`, `circle`). Los campos siguen la spec 02: `center`, `size`, `rotation`, `fill`, `stroke`, `strokeWidth`.
- **REC-011** `parse(json: unknown): DrawingDocument` lanza `DrawingFormatError` con la ruta del problema; `safeParse` devuelve `{ ok, document | error }`.
- **REC-012** `serialize(document): string` escribe todos los campos siempre (FMT-008), con `rotation` normalizada. No redondea `center`, `size`, `rotation` ni `labelOffset` (FMT-070).
- **REC-013** Los campos desconocidos se ignoran al leer y no se conservan (FMT-009).
- **REC-014** `schemaVersion` se lee y se escribe como entero `1`.

### 5.2 Validación

- **REC-020** `validate(json): DrawingError[]` aplica las reglas de la spec 02, sección 13.
- **REC-021** `validate` nunca lanza ante entradas arbitrarias (`null`, números, arreglos): devuelve un error.
- **REC-022** `square` y `circle` aceptan una diferencia de hasta `1e-6` entre `width` y `height` (FMT-011).
- **REC-023** La conformidad exige aceptar o rechazar, no coincidir en mensajes (FMT-060). Las rutas siguen el patrón `shapes[3].center.x`.

### 5.3 Color

- **REC-030** `argbToCss(value)` convierte `0xAARRGGBB` a `rgba(R, G, B, A/255)` y `cssToArgb` hace el camino inverso. Un test usa un color con alfa distinto de 255 y otro con valor mayor que `2³¹−1`.
- **REC-031** Los colores se tratan como enteros de 32 bits **sin signo**. En JS se normalizan con `>>> 0` cuando hay operaciones de bits.

### 5.4 Ángulos

- **REC-040** `normalizeAngle(x)` devuelve un valor en `[0, 2π)`. Debe usar `((x % T) + T) % T` y cubrir negativos, `2π` exacto y valores muy grandes (FMT-003).
- **REC-041** `toDegrees` y `toRadians` para las bibliotecas que usan grados (Konva). El documento siempre guarda radianes.

### 5.5 Anclas y geometría de juntas

- **REC-050** `anchorsOf(shape)` y `anchorPositionOf(shape, anchorId)` implementan la spec 02, sección 10, incluida la rotación horaria con `+y` hacia abajo.
- **REC-051** `defaultLabelOffset`, `clampLabelOffset`, `leaderLineStart` y `arrowheadPoints` implementan FMT-040 a FMT-044 y dan los mismos resultados que Flutter con tolerancia `1e-6`.
- **REC-052** `TextMeasurer` es una interfaz inyectable:
  ```ts
  interface TextMeasurer { measure(text: string, fontSize: number, bold: boolean): { width: number; height: number } }
  ```
  Se incluye `CanvasTextMeasurer` (solo navegador, usa `measureText`). En Node sin medidor propio se documenta que las cajas serán aproximadas (FMT-050).
- **REC-053** `placeJoints(document, style, measurer)` devuelve, por junta, la posición del ancla y el rectángulo de etiqueta (texto medido más `labelPadding` por cada lado). Devuelve una lista vacía si `jointDisplay.visible` es `false`.
- **REC-054** Una junta cuya figura o ancla no existe se omite sin romper (igual que Flutter).

### 5.6 Nombres

- **REC-060** `nextJointName(prefix, names)` implementa FMT-046, usando `BigInt` para el sufijo.
- **REC-061** `normalizeJointName(raw, maxLength)` recorta espacios y limita por **grapheme clusters** con `Intl.Segmenter` (FMT-022). Devuelve `null` si queda vacío. Un test usa emoji y letras acentuadas descompuestas.

### 5.7 Operaciones de edición (puras)

Reciben un `DrawingDocument` y devuelven uno nuevo, sin mutar.

- **REC-070** Figuras: `addShape`, `removeShape`, `moveShape`, `resizeShape`, `rotateShape`, `setShapeStyle`, `bringToFront`, `sendToBack`, `duplicateShape`.
- **REC-071** `removeShape` elimina también las juntas de esa figura y la saca de su grupo; un grupo que queda con menos de 2 figuras se elimina.
- **REC-072** `resizeShape` de `square` y `circle` mantiene `width == height` exactamente (escribe el mismo valor en ambos).
- **REC-073** Juntas: `addJoint`, `renameJoint`, `moveJointLabel`, `removeJoint`. `addJoint` rechaza un ancla ya ocupada (FMT-020). `moveJointLabel` aplica `clampLabelOffset`.
- **REC-074** Grupos: `groupShapes` y `ungroup`, con los invariantes de FMT-030 a FMT-032.
- **REC-075** `setJointDisplay({ labelSize?, visible? })`.
- **REC-077** Se portan también los módulos de edición de Flutter que React necesita, para que el editor no tenga geometría propia: selección por punto (`hit_testing`), redimensionado con asas (`resize`: la esquina u borde opuesto queda fijo en el mundo, tamaño mínimo 20, máximo el lado mayor del lienzo), ajuste a cuadrícula (`grid`), ajuste entre anclas (`anchor_snapping`, `pickAnchor`), ajuste suave de ángulo (`softSnapAngle`) y límites de vista (`viewport`). Al portar cada uno se agregan sus fixtures a `fixtures/geometry/`.
- **REC-076** Las operaciones no mueven `labelOffset` al mover, redimensionar o girar la figura (FMT-021).

### 5.8 Empaquetado

- **REC-080** Salidas ESM y CJS con tipos (`exports` en `package.json`).
- **REC-081** `sideEffects: false` para permitir tree-shaking.
- **REC-082** Compatible con Node LTS vigentes y navegadores modernos.
- **REC-083** Provenance de npm habilitada al publicar desde GitHub Actions.

## 6. API pública esperada (boceto)

```ts
import { parse, serialize, moveShape, addJoint, placeJoints, CanvasTextMeasurer } from '@diagrama-kit/core';

const doc   = parse(jsonFromBackend);
const moved = moveShape(doc, 's_01', { dx: 20, dy: 0 });
const json  = serialize(moved);              // listo para PUT al backend
```

## 7. Criterios de aceptación

- [ ] `test/conformance/` ejecuta todas las fixtures y pasa (FMT-080 a FMT-083).
- [ ] Cada requisito `REC-xxx` tiene un test que cita su ID.
- [ ] `tsc --noEmit` sin errores en modo `strict`.
- [ ] Los mismos tests pasan en Node y en un entorno de navegador (jsdom o Playwright).
- [ ] Un documento generado por Flutter se lee, se guarda y se vuelve a abrir en Flutter sin pérdida.
- [ ] `npm pack --dry-run` muestra solo los archivos esperados.

## 8. Preguntas abiertas

- ¿Validación escrita a mano o apoyada en Ajv/Zod usada solo en desarrollo para contrastar con el JSON Schema?
- ¿Se publica un medidor de texto de Node con `canvas` como paquete opcional aparte?
- ¿Alcance del scope npm: `@diagrama-kit/*` disponible?
