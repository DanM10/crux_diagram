# 03 · Spec del paquete Flutter / Dart

Depende de: `02-spec-formato-json.md`. Publicación: pub.dev.

---

## 1. Objetivo

Paquete de Flutter que **lee, valida, muestra, edita, guarda y exporta como imagen** dibujos en el formato JSON v1.

El paquete **ya existe y es funcional** (`crux_diagram`, versión `0.1.0`). Esta spec no lo rediseña: fija qué debe cumplir para ser la **implementación de referencia** del formato y qué falta para publicarlo. El comportamiento del editor se define en las specs propias del paquete (`docs/flutter-specs/00` a `06`), que siguen vigentes.

## 2. Estado actual

| Área | Estado |
|---|---|
| Modelo: `DrawingDocument`, `ShapeElement`, `Joint`, `ShapeGroup`, `JointLabelSize` | Hecho |
| Codec JSON (`fromJson`, `toJson`, `validate`) | Hecho. Escribe `schemaVersion: 4`; ver FLT-011 |
| Editor (`DrawingEditor`, `DrawingEditorPage`, `DrawingEditorController`) y visor (`DrawingView`) | Hecho |
| Exportación a JPEG y PNG (`renderDrawingImage`, `ImageFormat`) | Hecho |
| Tolerancia `1e-6` en `width == height` (FMT-011) | Hecho (commit `30a0e4c`) |
| Pruebas de conformidad con `fixtures/` | Pendiente |
| Preparación para pub.dev | Pendiente |

## 3. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| FLT-O1 | Pasa el 100 % de las fixtures de conformidad | `flutter test test/conformance/` |
| FLT-O2 | El formato que escribe es exactamente el de la spec 02 | Fixtures `roundtrip/` y revisión del codec |
| FLT-O3 | El estilo de juntas por defecto coincide con la spec 02, sección 12 | Test de valores por defecto |
| FLT-O4 | El paquete cumple los criterios de pub.dev | `dart pub publish --dry-run` limpio y puntuación `pana` alta |
| FLT-O5 | Las fixtures son la red de seguridad: un cambio de codec o de anclas que rompa a React falla un test aquí | Tests de conformidad en CI |

## 4. Alcance

**Dentro:** alinear el codec con la spec 02, pruebas de conformidad, generación de fixtures, preparación de la publicación.

**Fuera:** cambios de comportamiento del editor, rediseños de la API pública, persistencia (la hace la app que usa el paquete).

## 5. Requisitos

### 5.1 Formato

- **FLT-010** `DrawingDocument.fromJson` y `toJson` implementan la spec 02 (secciones 4 a 9 y 13). Todo documento que la spec 02 manda rechazar se rechaza con `DrawingFormatException`.
- **FLT-011** El codec escribe `schemaVersion: 1` y solo decodifica la versión `1`. Se eliminan las ramas de decodificación de las versiones 1 a 3 previas y la lógica de migración (decisión D13).
- **FLT-012** `square` y `circle` aceptan una diferencia de hasta `1e-6` entre `width` y `height` (FMT-011). *Hecho.*
- **FLT-013** Los campos desconocidos se ignoran y no se conservan (FMT-009).
- **FLT-014** Al escribir, `rotation` va normalizada a `[0, 2π)` y todos los campos de la spec 02 se escriben siempre (FMT-008).
- **FLT-015** Los mensajes de error indican la ruta con el patrón `shapes[3].center.x`.

### 5.2 Conformidad

- **FLT-020** `test/conformance/` recorre `fixtures/` y ejecuta FMT-080 a FMT-083:
  - `valid/` se acepta.
  - `invalid/` se rechaza.
  - `roundtrip/` conserva el significado (comparación numérica con tolerancia `1e-6`, no textual).
  - `geometry/` coincide con el resultado esperado.
- **FLT-021** Las funciones de geometría que cubren las fixtures (`anchorsOf`, `defaultLabelOffset`, `clampLabelOffset`, `leaderLineStart`, `arrowheadPoints`, `nextJointName`, `normalizeJointName`, `normalizeAngle`) se prueban importándolas desde `src/` en los tests. No hace falta exportarlas en la API pública.
- **FLT-022** Los resultados esperados de `geometry/` y los documentos de `valid/` se generan con este paquete y se revisan a mano una vez. Desde entonces son la referencia que React debe igualar.
- **FLT-024** `test/conformance/` ejecuta `fixtures/drawing-geometry/`: `computeGeometry` con `ApproximateTextMeasurer` da el `expected` de cada archivo con tolerancia `1e-6`, y `validateGeometry` no reporta errores sobre él (spec 06). Estas fixtures las genera `core`, no este paquete.
- **FLT-023** Cada requisito `FMT-xxx` y `FLT-xxx` tiene al menos un test que cita su ID.

### 5.3 Estilo de juntas

- **FLT-030** Los valores por defecto de `JointStyle` coinciden con la tabla de la spec 02, sección 12: color `#000000`, línea `2.5`, fuente base `30` con paso `4`, negrita, punta `16 × 11`, `labelPadding` `6`. Un test los verifica.
- **FLT-031** `jointNameMaxLength` es `12` por defecto y configurable. Es una regla del editor, no del decodificador (FMT-022).
- **FLT-032** La etiqueta de las juntas usa la familia `Arial` (spec 02, sección 12): `JointStyle.labelStyle` la fija por defecto. Solo afecta a las etiquetas de las juntas; el resto de la UI no cambia. *Pendiente.*

### 5.4 Calidad del paquete (pub.dev)

- **FLT-040** `pubspec.yaml` con `repository`, `issue_tracker` y `homepage` apuntando al monorepo, `topics` y `platforms` según lo probado.
- **FLT-041** `LICENSE` presente. `CHANGELOG.md` con una entrada por versión.
- **FLT-042** `README.md` con capturas: URLs absolutas HTTPS o el campo `screenshots:` del `pubspec.yaml` (máximo 10 imágenes y 4 MB en total, dentro del paquete).
- **FLT-043** Documentación `///` en toda la API pública; `dart doc` sin advertencias.
- **FLT-044** `example/` ejecutable que carga un JSON, lo edita y lo exporta.
- **FLT-045** `analysis_options.yaml` con `flutter_lints`; `flutter analyze` sin avisos; `dart format --set-exit-if-changed .` pasa.
- **FLT-046** Dependencias mínimas (hoy: `flutter` y `image`).

## 6. API pública actual (referencia)

Exportada desde `package:crux_diagram/crux_diagram.dart`:

```dart
// Modelo
DrawingDocument, ShapeElement, ShapeType, Joint, JointLabelSize, ShapeGroup, ShapeStyle,
Anchor, AnchorKind, DrawingFormatException

// Editor y visor
DrawingEditor, DrawingEditorPage, DrawingEditorController, DrawingEditorConfig,
DrawingEditorLabels, DrawingTool, DrawingResult, DrawingView, JointStyle, LeaderStyle

// Exportación
renderDrawingImage, ImageFormat

// Geometría de dibujo (spec 06)
computeGeometry, DrawingGeometry, ShapeGeometry, ShapeGeometryKind, JointGeometry,
JointTextGeometry, TextMeasurer, ApproximateTextMeasurer, FlutterTextMeasurer,
validateGeometry, GeometryError, GeometryErrorCode, geometryVersion, labelFontFamily
```

```dart
final document = DrawingDocument.fromJson(jsonString);   // lanza DrawingFormatException
final error = DrawingDocument.validate(jsonString);      // null si abre
final json = document.toJson();

DrawingView(document: document);
final image = await renderDrawingImage(document, format: ImageFormat.png);
```

## 7. Criterios de aceptación

- [ ] `test/conformance/` ejecuta todas las fixtures y pasa (FMT-080 a FMT-083).
- [ ] El codec solo escribe y lee `schemaVersion: 1`.
- [ ] `flutter analyze` y `dart format --set-exit-if-changed .` pasan.
- [ ] `flutter test` pasa completo.
- [ ] `dart pub publish --dry-run` sin errores ni advertencias.
- [ ] `example/` corre en Android, iOS y al menos una plataforma de escritorio o web.

## 8. Preguntas abiertas

- Nombre del paquete en pub.dev: `crux_diagram` (decidido el 2026-11-23; antes `soft_drawer_service`).
- ¿Publisher verificado en pub.dev (requiere dominio propio)?
- ¿Plataformas declaradas en la primera versión (móvil, web, escritorio)?
- ¿Se separa algún día un núcleo en Dart puro? Hoy el modelo usa `dart:ui` y `package:flutter`. No es requisito de esta spec.
