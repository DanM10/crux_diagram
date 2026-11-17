# 02 · Especificación del formato JSON — v1

Estado: **borrador revisado**. Este documento es la **fuente de verdad** del formato. Las specs de Flutter y React dependen de él.

Base: el formato describe lo que la implementación Flutter (`soft_drawer_service`) ya lee y escribe. Flutter es la implementación de referencia; React se adapta a este documento. La versión anterior de esta spec se conserva en `02-spec-formato-json.original.md`.

---

## 1. Objetivo

Definir un formato JSON para dibujos de figuras básicas (cuadrado, rectángulo, círculo) con rotación, juntas nombradas con flecha guía y grupos, que pueda ser leído, editado y dibujado por implementaciones independientes (Dart, TypeScript, Java u otras) con el mismo resultado.

## 2. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| O-1 | Un dibujo guardado por una implementación se abre y se ve igual en la otra (geometría con tolerancia de 1e-6; el texto puede variar por la fuente) | Fixtures `valid/` y `geometry/` |
| O-2 | Un documento inválido se rechaza en ambas implementaciones | Fixtures `invalid/` |
| O-3 | Cargar y guardar un documento válido no cambia su significado (round-trip) | Fixtures `roundtrip/` |
| O-4 | Las funciones geométricas compartidas dan el mismo resultado en Dart y TypeScript | Fixtures `geometry/` |

## 3. Alcance

**Dentro:** `square`, `rectangle`, `circle` con rotación; `joints` (ancla con nombre y flecha guía); `groups`; `jointDisplay`; lienzo.

**Fuera (v1):** texto libre como figura, flechas libres no ligadas a una figura, triángulos, grupos anidados, historial de versiones, colaboración en tiempo real, campos `computed`.

## 4. Convenciones generales

- **FMT-001** Unidades lógicas del lienzo. Origen arriba-izquierda, `+x` hacia la derecha, `+y` hacia abajo.
- **FMT-002** Toda figura se ubica por su **centro** (`center`) y su tamaño sin rotar (`size`). La rotación gira alrededor del centro.
- **FMT-003** `rotation` está en **radianes**, sentido **horario** con `+y` hacia abajo, normalizada a `[0, 2π)`. Al leer, el lector normaliza; al escribir, el escritor escribe el valor normalizado.
- **FMT-004** Colores: **entero de 32 bits sin signo en formato ARGB** (`0xAARRGGBB`), con valor entre `0` y `4294967295`.
  - No es el orden de CSS (`#rrggbbaa`). Conversión a CSS: `rgba(R, G, B, A/255)`.
  - Valores como `0xFF757575` superan `2³¹−1`. Un lector Java debe mapearlos a `long`, no a `int`.
- **FMT-005** Los números son JSON `number` finitos (sin `NaN` ni infinito). Los lectores aceptan enteros o decimales indistintamente (`100` y `100.0`), salvo `schemaVersion` y los colores, que deben ser enteros.
- **FMT-006** Los ids (de figuras, juntas y grupos) son cadenas **no vacías y opacas**; no se interpreta su contenido. Cada tipo de id es único dentro de su lista.
- **FMT-007** El orden de `shapes` define el orden de dibujo: el índice 0 queda al fondo.
- **FMT-008** Todos los campos de esta spec son **obligatorios** y se escriben siempre. No hay valores por defecto al leer.
- **FMT-009** Los campos desconocidos se **ignoran** al leer y **no se conservan** al guardar.

## 5. Documento raíz

```json
{
  "schemaVersion": 1,
  "canvas": { "width": 1600, "height": 1200 },
  "shapes": [],
  "joints": [],
  "jointDisplay": { "labelSize": "small", "visible": true },
  "groups": []
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `schemaVersion` | entero | Versión del formato (no del paquete). En esta spec es `1` |
| `canvas.width`, `canvas.height` | número > 0 | Tamaño lógico del lienzo |
| `shapes` | arreglo | Puede estar vacío |
| `joints` | arreglo | Puede estar vacío |
| `jointDisplay` | objeto | Sección 9 |
| `groups` | arreglo | Puede estar vacío |

- **FMT-010** Un lector rechaza un documento con `schemaVersion` ausente, no entero, menor que 1 o mayor que la versión que soporta.

## 6. Figuras

```json
{
  "id": "shape_lq2x_1",
  "type": "rectangle",
  "center": { "x": 400, "y": 300 },
  "size": { "width": 240, "height": 140 },
  "rotation": 0.5236,
  "fill": 16777215,
  "stroke": 4286611584,
  "strokeWidth": 2
}
```

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | texto | No vacío, único entre las figuras |
| `type` | texto | `square`, `rectangle` o `circle` |
| `center.x`, `center.y` | número | Centro de la figura |
| `size.width`, `size.height` | número > 0 | Tamaño sin rotar |
| `rotation` | número | Radianes, ver FMT-003 |
| `fill` | color | Relleno. Alfa `0` = sin relleno |
| `stroke` | color | Color del borde |
| `strokeWidth` | número ≥ 0 | Grosor del borde. `0` = sin borde |

- **FMT-011** `square` y `circle` exigen `size.width == size.height`. Los lectores aceptan una diferencia de hasta `1e-6`.
- **FMT-012** Dibujo: se aplica traslación al centro y rotación; el relleno se dibuja solo si su alfa es mayor que `0` y el borde solo si `strokeWidth > 0`. El borde se centra sobre el contorno. `circle` es el óvalo inscrito en `size`.
- **FMT-013** Los tamaños iniciales de una figura nueva (por ejemplo 160×160) son comportamiento del editor, no parte del formato.

## 7. Juntas (`joints`)

Una junta es un ancla con nombre. Se dibuja como una etiqueta con una flecha guía que apunta al ancla.

```json
{
  "id": "joint_lq2y_1",
  "shapeId": "shape_lq2x_1",
  "anchorId": "tr",
  "name": "J1",
  "labelOffset": { "dx": 45.25, "dy": -45.25 }
}
```

| Campo | Reglas |
|---|---|
| `id` | No vacío, único entre las juntas |
| `shapeId` | Debe existir en `shapes` |
| `anchorId` | Debe ser un ancla válida del tipo de esa figura (sección 10) |
| `name` | No vacío tras recortar espacios |
| `labelOffset` | Vector `{dx, dy}` del ancla al centro de la etiqueta, en ejes del lienzo |

- **FMT-020** A lo sumo una junta por par `(shapeId, anchorId)`.
- **FMT-021** El centro de la etiqueta es `ancla + labelOffset`, **sin rotar** con la figura: al mover o girar la figura, la etiqueta y la flecha la acompañan manteniendo el mismo `labelOffset`.
- **FMT-022** El límite de longitud del nombre (12 por defecto, configurable) es una regla del editor, no del decodificador: un nombre cargado desde JSON conserva su texto aunque supere el límite. Al escribir en el editor, se cuenta en **grapheme clusters**, no en unidades de código ni en puntos de código.
- **FMT-023** Las juntas se dibujan por encima de todas las figuras, sin importar el orden de `shapes`.

## 8. Grupos (`groups`)

```json
{ "id": "group_lq2z_1", "shapeIds": ["shape_lq2x_1", "shape_lq2x_2"] }
```

- **FMT-030** `shapeIds` tiene al menos **2** ids, sin repetir, y cada uno existe en `shapes`.
- **FMT-031** Una figura pertenece a lo sumo a un grupo (no hay anidación).
- **FMT-032** Los ids de grupo son únicos entre los grupos.

## 9. Visualización de juntas (`jointDisplay`)

| Campo | Valores |
|---|---|
| `labelSize` | `small`, `medium` o `large`. Aplica a **todas** las etiquetas del documento |
| `visible` | booleano. Con `false`, las juntas siguen guardadas pero no se dibujan, exportan ni seleccionan |

## 10. Anclas

Posición en el lienzo de un ancla: `mundo = center + R(rotation) · local`, con `R` la rotación horaria con `+y` hacia abajo:

```
R(θ)·(x, y) = (x·cosθ − y·sinθ,  x·sinθ + y·cosθ)
```

Los ids de ancla se refieren al marco **local** de la figura: `tl` es siempre la esquina que era superior izquierda antes de rotar.

**`square` y `rectangle`** (`w`, `h` = tamaño sin rotar)

| id | Local | Tipo |
|---|---|---|
| `tl` | (−w/2, −h/2) | vértice |
| `tr` | (w/2, −h/2) | vértice |
| `br` | (w/2, h/2) | vértice |
| `bl` | (−w/2, h/2) | vértice |
| `tc` | (0, −h/2) | punto medio |
| `rc` | (w/2, 0) | punto medio |
| `bc` | (0, h/2) | punto medio |
| `lc` | (−w/2, 0) | punto medio |

**`circle`** (`r = w/2`)

| id | Local |
|---|---|
| `tc` | (0, −r) |
| `rc` | (r, 0) |
| `bc` | (0, r) |
| `lc` | (−r, 0) |

El centro de la figura no es un ancla.

## 11. Geometría de la flecha guía

Todas estas funciones son puras y están cubiertas por fixtures (sección 14).

- **FMT-040 Desplazamiento por defecto.** Vector unitario desde el centro de la figura hacia el ancla, multiplicado por `64`. Si el centro y el ancla coinciden, `(0, −64)`.
- **FMT-041 Límite al lienzo.** El centro de la etiqueta (`ancla + labelOffset`) se restringe a `[0, width] × [0, height]`; se devuelve el `labelOffset` resultante.
- **FMT-042 Rectángulo de etiqueta.** Centrado en `ancla + labelOffset`, con ancho y alto del texto medido más `labelPadding` por cada lado.
- **FMT-043 Inicio de la flecha.** Es el punto donde el segmento del centro de la etiqueta hacia el ancla sale del rectángulo de etiqueta. Si el ancla está dentro del rectángulo, no hay flecha. "Dentro" es **semiabierto**: `left ≤ x < right` y `top ≤ y < bottom` (igual que `Rect.contains` de Flutter). Un ancla sobre el borde derecho o inferior cuenta como fuera, y su inicio de flecha coincide con el ancla misma, así que tampoco se dibuja flecha (FMT-045).
  - Con `d = ancla − centro`: `tx = (w/2)/|dx|`, `ty = (h/2)/|dy|` (infinito si el divisor es 0); inicio = `centro + d · min(tx, ty)`.
- **FMT-044 Punta.** Con `dir = (punta − inicio) / |punta − inicio|`, `base = punta − dir · largo`, `normal = (dir.y, −dir.x) · (ancho/2)`; el triángulo es `[punta, base + normal, base − normal]`.
- **FMT-045 Trazo.** La línea va del inicio al punto medio de la base de la punta, y solo se dibuja si su longitud supera el largo de la punta. La punta se dibuja siempre que haya flecha.
- **FMT-046 Nombre automático.** `prefijo` (por defecto `J`) + `n`, con `n` = 1 + el mayor sufijo numérico entre los nombres que cumplen exactamente `^prefijo\d+$`. El sufijo puede exceder 64 bits: usar enteros de precisión arbitraria.

## 12. Estilo de referencia de las juntas

El documento solo guarda `small/medium/large`. Para que el mismo JSON se vea igual, ambas implementaciones usan por defecto estos valores (en unidades del lienzo):

| Elemento | Valor |
|---|---|
| Color de línea, punta y etiqueta | `#000000` |
| Grosor de línea | `2.5` (no cambia con el tamaño) |
| Tamaño de fuente `small` / `medium` / `large` | `30` / `34` / `38` (base 30, paso 4) |
| Peso de la fuente | negrita |
| Punta (largo × ancho) en `small` | `16 × 11`, escalada por `fuente / 30` en los otros tamaños |
| `labelPadding` | `6` |

- **FMT-050** Las dimensiones del texto dependen de la fuente de cada plataforma y **no son interoperables al píxel**. La posición de la flecha puede variar levemente entre implementaciones. Las fixtures de geometría reciben el rectángulo de etiqueta como dato y no miden texto.

## 13. Validación

El lector rechaza el documento si incumple cualquiera de estas reglas:

1. No es JSON, o la raíz no es un objeto.
2. `schemaVersion`: FMT-010.
3. Falta un campo obligatorio o tiene un tipo incorrecto.
4. `canvas` o `size` con ancho o alto no positivo.
5. `type` desconocido.
6. `strokeWidth` negativo.
7. Un color fuera de `[0, 4294967295]` o no entero.
8. `square` o `circle` con `width != height` (FMT-011).
9. Id de figura, junta o grupo vacío o repetido.
10. Junta cuya figura no existe, ancla no válida para el tipo, o ancla repetida (FMT-020).
11. `name` de junta vacío tras recortar.
12. `jointDisplay.labelSize` desconocido, o `visible` no booleano.
13. Grupo que incumple FMT-030, FMT-031 o FMT-032.

- **FMT-060** La conformidad solo exige **aceptar o rechazar**, no coincidir en códigos ni mensajes de error.
- **FMT-061** Cada implementación debe reportar el error con su ruta (por ejemplo `shapes[3].center.x`), pero el formato exacto del mensaje no forma parte del contrato.

## 14. Trampas de portabilidad (obligatorias para TypeScript)

| Tema | Dart | Qué hacer en TypeScript |
|---|---|---|
| Módulo negativo | `%` da resultado no negativo | `((x % T) + T) % T` en `normalizeAngle` |
| Longitud del nombre | `characters.take` (grapheme clusters) | `Intl.Segmenter` |
| Enteros grandes | `BigInt` en el nombre automático | `BigInt` |
| Redondeo | no se redondea lo guardado | no redondear `center`, `size`, `rotation` ni `labelOffset` al guardar |
| Rotación | radianes | Konva usa grados: convertir al dibujar y al guardar |
| Pivote de rotación | el centro | Konva rota sobre `(x, y)`: usar `x,y = center` y `offsetX = w/2`, `offsetY = h/2` |
| Escala del Transformer | n/a | tras transformar, volver a `size` y reiniciar `scaleX/scaleY` a 1 |
| Igualdad de círculos | exacta hoy | `square` y `circle`: escribir el mismo valor en `width` y `height` |
| Entero vs decimal | `jsonEncode` escribe `100.0` | comparar numéricamente, nunca por texto |
| Punto dentro de un rectángulo | `Rect.contains` es semiabierto (excluye derecha y abajo) | implementar `left <= x < right && top <= y < bottom`, no un intervalo cerrado |

- **FMT-070 Redondeo compartido (`round2`).** Para valores **derivados** (fixtures de geometría, y `computed` si algún día existe): `round2(v) = signo(v) · floor(|v|·100 + 0.5) / 100`. Es "mitad lejos de cero", y se usa la misma fórmula en ambos lados (no `Math.round` ni `double.round`, que difieren en las mitades negativas). Como ambos usan doubles IEEE 754, la fórmula da el mismo resultado.

## 15. Conformidad y fixtures

```
fixtures/
├── valid/        *.json                          debe aceptarse
├── invalid/      *.json                          debe rechazarse
├── roundtrip/    *.json                          leer y guardar conserva el significado
└── geometry/     *.json                          entrada + resultado esperado
```

Una implementación es **conforme** si, para todas las fixtures:

1. **FMT-080** Acepta todo `valid/`.
2. **FMT-081** Rechaza todo `invalid/`.
3. **FMT-082** `roundtrip/`: tras leer y volver a escribir, el documento es **numéricamente equivalente** (tolerancia `1e-6`; los campos desconocidos no se conservan, FMT-009). Se compara con `<nombre>.expected.json` si existe, y si no, con el propio `<nombre>.json`.
4. **FMT-083** `geometry/`: cada resultado coincide con el esperado dentro de `1e-6`.

**Casos mínimos**

- `valid/`: documento vacío; cada tipo de figura; figura rotada; color con alfa; juntas en cada ancla de cada tipo; los tres `labelSize`; `visible: false`; un grupo.
- `invalid/`: un caso por cada regla de la sección 13.
- `geometry/`:
  - anclas de un rectángulo con rotaciones `0`, `π/2`, `0.5` y `7` (esta última debe normalizarse);
  - desplazamiento por defecto, incluido el caso centro = ancla;
  - límite al lienzo;
  - inicio de la flecha, con ancla dentro y fuera del rectángulo, y con `dx = 0` o `dy = 0`;
  - puntos de la punta;
  - nombre automático con huecos, nombres que no cumplen el patrón y sufijos enormes;
  - recorte del nombre con emoji y con letras acentuadas descompuestas;
  - `normalizeAngle` con valores negativos, `2π` y valores muy grandes.
  - Más adelante, al portar `hit_testing`, `resize`, `grid`, `anchor_snapping` y `viewport` a TypeScript, se agrega una fixture por función (spec 04, REC-077).

Las fixtures `valid/` y los resultados esperados se generan con la implementación Dart y se revisan a mano una vez.

## 16. Pendientes

- **Flutter, hecho:** tolerancia de `1e-6` en `width == height` (FMT-011) y renumeración a `schemaVersion: 1` sin ramas de versiones anteriores.
- **Flutter, hecho:** fixtures y `test/conformance/` (rama `test/format-conformance`). Formato de los archivos de `geometry/` descrito en `fixtures/README.md` del paquete.
- **Flutter:** los mensajes de error no deben cambiar, pero las rutas conviene que sigan el patrón `shapes[3].center.x`.
- **Decisión futura:** si un backend necesita dibujar sin medir texto, agregar `computed` por junta (posición del ancla, rectángulo de etiqueta, inicio de flecha).
- **Decisión futura:** conservar campos desconocidos al guardar (FMT-009) cuando haya versiones desincronizadas en producción.
- **Otros documentos:** alineados con esta spec (`README.md`, `03` a `06`).
