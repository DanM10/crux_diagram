# 05 · Spec de `@diagrama-kit/react` (editor y visor)

Depende de: `02-spec-formato-json.md` y `04-spec-react-core.md`. Publicación: npm.

---

## 1. Objetivo

Componentes React para **visualizar y editar** dibujos del formato JSON v1 y exportarlos como imagen, con el **mismo comportamiento que el editor Flutter**. Usa `@diagrama-kit/core` para todo lo relacionado con el formato y la geometría.

Mientras este paquete no exista, el comportamiento de referencia es el de Flutter: sus specs (`docs/flutter-specs/01` a `06`) definen cada interacción. Esta spec no las repite: indica qué se reproduce, qué cambia por ser web y cómo se resuelve con Konva.

## 2. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| REA-O1 | Un desarrollador integra el editor con ≤ 10 líneas | Ejemplo en `examples/` |
| REA-O2 | Un dibujo hecho en Flutter se abre y edita en React, y al revés, sin pérdida | Prueba cruzada con fixtures de Flutter |
| REA-O3 | La edición es fluida con 300 figuras | Arrastre sin frames > 16 ms (perfil de rendimiento) |
| REA-O4 | El editor no contiene lógica de geometría propia | Revisión: todo cálculo viene de `core` |
| REA-O5 | La imagen exportada es fiel al dibujo y no incluye elementos de edición | Prueba visual (snapshot de imagen) |

## 3. Alcance

**Dentro:** visor, editor, deshacer/rehacer, zoom/pan, exportación a PNG/JPEG, componente de historial de versiones (listar, previsualizar y restaurar).

Funcionalidad que se reproduce de Flutter:

| Área | Referencia en Flutter |
|---|---|
| Crear figuras, seleccionar, mover, redimensionar, rotar, duplicar, orden, borrar | Spec 01 (FR-4 a FR-22) |
| Juntas: herramienta, nombres, flecha guía, arrastre de etiqueta, ajuste entre anclas | Spec 02 |
| Cuadrícula y su alineación con el paso visible | Specs 03 (GD) y 05 (GA) |
| Tamaño y visibilidad de las juntas | Spec 04 |
| Selección múltiple, rectángulo de selección y grupos | Spec 05 (MS) |
| Estilo de figuras y de juntas, sugerencias de nombre, longitud de nombre | Spec 06 |

**Fuera:** persistencia y llamadas al backend (las hace la app mediante `onChange`), historial de versiones persistente (el componente solo muestra las versiones que le pasa la app), comparación visual entre versiones (resaltar figuras y juntas añadidas, borradas o movidas; prevista para una versión posterior), colaboración en tiempo real, retroalimentación háptica (no aplica en web), entrada táctil (la v1 se usa con ratón, teclado y trackpad; ver sección 8).

## 4. Decisiones técnicas

- **Render:** `react-konva` (Canvas).
- **Estado interno:** Zustand + `zundo` para deshacer/rehacer, con historial de instantáneas (por defecto 100 entradas; un gesto continuo = una entrada).
- **React:** solo React 19. Peer dependencies `react` y `react-dom` `^19.3.0`, `react-konva` `^19.3.0` (que pide `react ^19.3.0`) y `konva` `^10.0.0`. React 18 no se soporta (decidido 2026-11-18).
- **Capas del `Stage`:** (1) fondo, (2) figuras, (3) juntas, (4) UI de edición (asas, puntos de anclaje, cuadrícula, guías). Las juntas se dibujan por encima de todas las figuras (FMT-023). La capa 4 se oculta al exportar.
- **Rotación y pivote:** cada figura usa `x,y = center` y `rotation` en grados (conversión desde y hacia radianes con `core`), así gira sobre su centro. El cuadrado y el rectángulo (`Rect`) usan además `offsetX = width/2`, `offsetY = height/2`; el círculo es una `Ellipse` con `radiusX = width/2`, `radiusY = height/2`, que Konva ya centra en `x,y`, sin offset.
- **Asas propias en lugar de `Transformer`:** el redimensionado y la rotación se implementan con asas dibujadas en la capa 4 que llaman a las operaciones de `core` (REC-077). `Transformer` escala la figura y obliga a reconvertir a `size`, lo que no reproduce el algoritmo de Flutter (esquina opuesta fija, mínimo y máximo, cuadrícula).

## 5. Requisitos

### 5.1 Componentes

- **REA-001** `<DrawingViewer document={d} jointStyle? />`: solo lectura, ajusta el lienzo al contenedor con fondo blanco, figuras y juntas, igual que `DrawingView` de Flutter.
- **REA-002** `<DrawingEditor value={d} onChange={fn} readOnly? config? />`: componente **controlado**; emite un `DrawingDocument` nuevo (inmutable) en cada cambio confirmado.
- **REA-007** Un `value` distinto del documento del editor nunca borra el historial por sí solo:
  - si es un documento que el editor ya emitió y la app todavía no adoptó (adopción con retraso), se ignora;
  - en otro caso se aplica como un cambio que se puede deshacer, sin llamar a `onChange`.

  Para abrir otro dibujo con el historial vacío, la app cambia la `key` del editor o llama a `reset(documento)` (REA-004).
- **REA-003** Un arrastre continuo emite `onChange` solo al soltar (y opcionalmente `onPreview` durante el arrastre).
- **REA-004** Referencia imperativa (`ref`): `undo()`, `redo()`, `canUndo`, `canRedo`, `exportImage(options)`, `fitToScreen()`, `getDocument()`, `reset(documento)` (reemplaza el documento y vacía el historial, sin llamar a `onChange`).
- **REA-005** `readOnly` desactiva selección, arrastre y atajos.
- **REA-006** `config` replica `DrawingEditorConfig` de Flutter: `gridSize`, `showGrid`, `gridMajorEvery`, `rotationSnapStep`, `rotationSnapTolerance`, `shapeStyle`, `jointNameMaxLength` (12 por defecto), `jointNameSuggestions`, `canvasSize`.

### 5.2 Interacción con figuras

- **REA-010** Selección por clic (la figura más alta que contiene el punto, con rotación). Selección múltiple y grupos como en Spec 05 de Flutter (MS-1 a MS-8).
- **REA-011** Arrastrar mueve la figura o la selección; el centro se restringe al lienzo (FR-10). Con cuadrícula, se ajusta como en GA-1 a GA-8.
- **REA-012** Redimensionar con asas propias: cuadrados y círculos mantienen `width == height` exactamente (REC-072). Sin asas de borde en `square` y `circle`.
- **REA-013** Rotar con una asa sobre el borde superior, con ajuste suave a múltiplos de 15° dentro de 5° (configurable), y la acción "girar 90°".
- **REA-019** Detalle de REA-012 y REA-013, de Flutter (FR-7, FR-11 a FR-18, MS-5): solo una figura seleccionada sin grupo tiene asas; con varias o con un grupo no hay asas ni "girar 90°". El radio táctil de una asa es de 24 px de pantalla, el visual de 6 px y el tallo de la asa de giro mide 32 px sobre el borde superior. Las asas se prueban antes que las figuras, y un toque sobre una asa no cambia la selección. El borde de selección de una figura sola sigue su rotación. Un gesto de redimensionar o girar es una entrada de historial. El ajuste a anclas al redimensionar es de REA-026. "Girar 90°" es una orden del editor sin tecla (`rotate90`), que usará la barra de herramientas (REA-053).
- **REA-014** `Supr` y `Backspace` eliminan. Eliminar una figura elimina sus juntas (REC-071).
- **REA-015** Atajos: `Ctrl/Cmd+Z`, `Ctrl/Cmd+Shift+Z`, `Ctrl/Cmd+D` (duplicar con nuevo `id`), flechas del teclado para mover 1 unidad (`Shift` = 10).
- **REA-018** *Supuesto (2026-11-18), Flutter no tiene atajos:* los atajos y las flechas actúan solo cuando el editor tiene el foco (contenedor enfocable con `tabIndex`) y nunca mientras un campo de texto tiene el foco. Cada pulsación de flecha es una entrada de historial, mueve la selección sin ajuste a cuadrícula y con el centro restringido al lienzo (FR-10). `Ctrl/Cmd+D` duplica como FR-20 (copias desplazadas 20 unidades y seleccionadas). La selección no entra en el historial.
- **REA-016** Zoom con la rueda del ratón y con el pellizco del trackpad (evento `wheel` con `ctrlKey`) entre 1× y 4×; pan con arrastre en fondo cuando el zoom supera el ajustado, o con barra espaciadora. Las coordenadas del puntero se convierten a coordenadas del lienzo. Botón "ajustar a pantalla" con indicador de porcentaje (Spec 03, ZM-1, ZM-2).
  *Detalles (2026-11-18):* el factor de la rueda es `exp(-deltaY × k)` con `k` = 0.002 para el ratón y 0.01 con `ctrlKey` (un `deltaMode` de líneas cuenta 33 px por línea), centrado en el puntero (`pinchZoom` de core); el pan se limita siempre con `clampZoom` (core). El arrastre en el fondo hace pan solo con zoom mayor que 1× y sin modo selección (con él, el fondo dibuja el rectángulo, MS-3); la barra espaciadora hace pan en cualquier caso y un toque con ella pulsada no cambia la selección. El botón y el porcentaje (`round(zoom × 100)`) aparecen con zoom > 1.005 (ZM-1, ZM-2); `fitToScreen()` y el botón vuelven a 1× con pan cero al instante, sin la animación de 200 ms de ZM-7. Sin pellizco táctil de dos dedos (FR-2 de Flutter): queda fuera de esta versión. Con `readOnly` la rueda y el botón siguen funcionando; el arrastre y la barra espaciadora no.
- **REA-017** Un cambio de zoom, pan o cuadrícula no crea entrada de historial ni marca el documento como modificado.

### 5.3 Juntas

- **REA-020** Herramienta de juntas: muestra las anclas de todas las figuras como puntos; tocar una ancla libre crea una junta con nombre automático (`nextJointName`) y abre el editor de nombre; tocar una ocupada la selecciona.
  *Detalles (2026-11-18):* la herramienta (`tool`: `'select'` o `'joint'`) es estado de vista, fuera del historial y sin botón hasta REA-053; con la de juntas no hay mover, redimensionar ni girar (JT-1) y las anclas se dibujan como puntos de 5 px de radio, rellenos si tienen junta. El radio táctil es de 22 px de pantalla y, con una diferencia menor de 2 px entre anclas, gana la figura de arriba (JT-4). La junta nueva se muestra como vista previa hasta confirmar el nombre, de modo que crear y nombrar es una sola entrada de historial (DL-3); un nombre vacío cancela la creación (NM-1). Tocar el fondo deselecciona la junta; Supr/Retroceso borra la junta seleccionada (DL-1, una entrada) y elegir una junta deselecciona las figuras y al revés. Con la junta seleccionada se dibuja un anillo en su ancla (AW-7).
- **REA-021** Editor de nombre: un campo de una línea con recorte por *grapheme clusters* (REC-061), y las sugerencias de `jointNameSuggestions` como botones (Spec 06, NS-1 a NS-8).
  *Detalles (2026-11-18):* Intro o perder el foco confirman; Escape cancela; un clic en una sugerencia confirma con ese nombre (NS-3). Una sugerencia que ya es el nombre de otra junta se oculta, sin contar el nombre de la junta que se renombra, y si todas están usadas no se muestra el área (NS-4); escribir un nombre repetido sigue permitido (NS-5). El texto de los controles queda en inglés hasta que REA-053 decida cómo se exponen las etiquetas.
- **REA-022** La etiqueta es arrastrable en cualquier herramienta; al soltar solo se actualiza `labelOffset` (restringido al lienzo) y es una entrada de historial.
  *Detalles (2026-11-18):* la etiqueta se prueba después de las asas y antes de las figuras (y antes de las anclas con la herramienta de juntas); arrastrarla no cambia la selección y un arrastre que termina donde empezó no crea entrada. Tocarla selecciona su junta (AW-7) y quita la selección de figuras; dos toques sobre la misma etiqueta en 300 ms abren el editor de nombre (NM-2) y el primero actúa al instante (ZM-4). La caja de la etiqueta es el rectángulo con relleno de `placeJoints`; la flecha no se prueba.
- **REA-023** La flecha guía y la etiqueta se dibujan con el estilo de referencia (spec 02, sección 12) y el medidor de texto de la sección 5.4.
- **REA-024** Barra de visualización: tamaño `small/medium/large` y mostrar/ocultar (Spec 04, JS y JV). Ocultar no borra juntas.
  *Detalles (2026-11-18):* `<JointDisplayBar />` (Flutter JD-1 a JD-4) muestra, en este orden, Small, Medium, Large y un botón Hide/Show. Los tres tamaños son una sola elección: el activo lleva `aria-pressed="true"` y pulsar otro aplica `setJointDisplay` (una entrada de historial, JS-4); pulsar el activo no cambia nada. Hide/Show alterna la visibilidad (una entrada, JV-6), lleva `aria-pressed="true"` mientras las juntas están ocultas y su texto pasa de "Hide" a "Show" (con título "Hide joints" / "Show joints", JD-3). Ocultar quita la selección de junta y deja la de figuras (JV-3). Los tres tamaños siguen activos con las juntas ocultas (JD-4). Con una junta seleccionada la barra añade Rename (abre el editor de nombre, NM-2) y Delete (una entrada, DL-1) tras los cuatro botones (JD-1). La barra no cambia la herramienta: Flutter la muestra solo con la herramienta de juntas, y aquí es la barra de herramientas (REA-053) quien decide cuándo mostrarla.
- **REA-025** Con las juntas ocultas, tocar una ancla ocupada en modo juntas las vuelve a mostrar y selecciona esa junta (Spec 05, FU-1).
- **REA-026** Ajuste entre anclas al mover figuras (`anchorSnapThreshold` de 12 px de pantalla, Spec 02 de Flutter, SN-1 a SN-4).
  *Detalles (2026-11-18):* el umbral se convierte a unidades de lienzo con la escala de la vista al empezar el gesto; `null` lo desactiva. Al mover, gana el par de anclas más cercano entre las de las figuras movidas y las demás, y sustituye al ajuste a cuadrícula (SN-3, GA-7); con varias figuras se mueven rígidas (MS-4). Al redimensionar solo participa la ancla bajo el asa arrastrada y solo si puede quedar exacta (un círculo no tiene ancla bajo sus asas de esquina); al girar no hay ajuste (SN-2). Mientras hay ajuste se dibuja un anillo en el ancla destino y no se guarda nada (SN-3, SN-4).

### 5.4 Texto

- **REA-030** Las etiquetas de las juntas se dibujan en `Arial` negrita, igual que en Flutter (spec 02, sección 12). La fuente es fija, no se configura por prop. El medidor del editor es `CanvasTextMeasurer` con esa **misma fuente**. El resto de la UI del editor no usa esta regla.
- **REA-031** La edición de nombre usa un `<input>` HTML superpuesto, alineado y con la misma fuente (`Arial` negrita) y el mismo tamaño.
- **REA-032** Se espera a que las fuentes estén cargadas (`document.fonts.ready`) antes de medir y antes de exportar.

### 5.5 Exportación

- **REA-040** `exportImage({ format: 'png' | 'jpeg', pixelRatio = 1, quality = 0.92, transparentBackground = false })` devuelve `Promise<Blob>` y opcionalmente dispara la descarga.
- **REA-041** El fondo es blanco por defecto en ambos formatos. `transparentBackground` solo es válido con PNG (Spec 06, EX-4 y EX-5).
- **REA-042** La imagen tiene el tamaño del lienzo multiplicado por `pixelRatio`, sin cuadrícula, asas ni puntos de anclaje (se oculta la capa 4). Con las juntas ocultas no se dibujan.
- **REA-043** Se rechaza un `pixelRatio` no positivo, una calidad fuera de rango o una imagen que supere un máximo de píxeles configurable (por defecto 16 megapíxeles), antes de renderizar.
  *Detalles (2026-11-18):* `format` es obligatorio; `download` es un nombre de archivo opcional: si se da, tras codificar se descarga la imagen con ese nombre (se añade `.png` o `.jpg` si falta la extensión) y la promesa sigue devolviendo el `Blob`. Todos los rechazos son `RangeError` y ocurren antes de renderizar: `format` distinto de `png`/`jpeg`, `pixelRatio` no finito o no positivo, `quality` fuera de [0, 1] (solo se valida con JPEG; con PNG se ignora, EX-3), `transparentBackground` con JPEG (EX-5) y un total de `ancho × alto × pixelRatio²` por encima de `config.exportMaxPixels` (16 000 000 por defecto). Se exporta el documento confirmado, nunca una vista previa, tras `document.fonts.ready` (un fallo de carga no lo impide, REA-032). La imagen se dibuja en un `Stage` aparte, sin el del editor, con solo las capas de fondo, figuras y juntas.

### 5.6 Rendimiento y calidad

- **REA-050** Solo se vuelven a renderizar las figuras cuyo dato cambió (`React.memo` por figura, selectores de Zustand).
- **REA-051** Con más de 1 000 figuras se documenta el uso de capas separadas para estático y dinámico.
- **REA-052** Accesibilidad básica: el lienzo expone una descripción alternativa y un listado de figuras para lectores de pantalla.
- **REA-053** Sin dependencias de estilos globales; los controles de herramienta son componentes listos para usar, exportados aparte (`<Toolbar />`, `<JointDisplayBar />`), que llaman a la misma API que la referencia imperativa (REA-004).
  *Detalles (2026-11-18, suposiciones):* los controles se renderizan **dentro** del editor para leer su estado sin una API de suscripción pública: `DrawingEditor` acepta `children`, que se muestran en una columna encima del lienzo (el lienzo ocupa el resto), y `<Toolbar />` y `<JointDisplayBar />` leen el editor que los contiene; fuera de un editor lanzan un error. Llaman a las mismas operaciones que el `ref` (`undo`, `redo`, `fitToScreen`) y a las de los atajos, sin estilos globales (estilos en línea, `<button type="button">`). Los textos salen de `labels` (prop de `DrawingEditor`, parcial, en inglés por defecto como `DrawingEditorLabels` de Flutter, LB-1): `fitToScreen`, `rename`, `delete`, `small`, `medium`, `large`, `hide`, `show`, `hideJoints`, `showJoints`; cada botón lleva su texto corto visible y el título largo como `title`. El estado "se puede deshacer / rehacer" es observable con un hook interno (`useHistoryAvailability`) que reacciona a la pila de historial, porque `canUndo`/`canRedo` del `ref` son getters sin señal de cambio (R3-canundo-not-observable).
  *`<Toolbar />` (2026-11-18, de Flutter TB-1 a TB-3, MS-1, JD-1, PL-1, PL-2, FR-4, FR-5):* dos filas, la de selección encima de la de creación, que no cambian de altura ni de orden al seleccionar (TB-2). Creación, siempre en este orden: Square, Rect, Circle, Joint (alterna la herramienta de juntas, `aria-pressed`), Grid (alterna la cuadrícula, se omite con `gridSize: null`), Undo y Redo (deshabilitados sin historial, siguen en su sitio). Selección: el botón Select (modo selección, `aria-pressed`, MS-1) va primero y siempre está; con una figura seleccionada siguen Rotate (solo con una figura sin grupo, MS-5), Copy, Front, Back y Delete; con la herramienta de juntas la fila es `<JointDisplayBar />` (JD-1) y no lleva Select; sin selección solo queda Select. Un botón de figura añade una figura del tamaño por defecto (cuadrado 160 × 160, rectángulo 240 × 140, círculo de diámetro 160), con `config.shapeStyle`, encima de todas, una sola entrada de historial, y la selecciona. Su centro es el centro visible (PL-1): el del área del lienzo con el zoom y la panorámica actuales, ajustado a `gridSize` si existe y, si ya hay una figura del mismo tipo exactamente ahí, desplazado +20/+20 mientras esté ocupado; si el siguiente paso saldría del lienzo (centro fuera de él), se reinicia desde el punto de partida con −20/−20 (PL-2) y, si ambos sentidos se agotan, se usa el punto de partida. Sin área medida todavía (antes del primer render del lienzo) el centro visible es el centro del lienzo. Front, Back, Copy y Delete actúan sobre toda la selección como sus equivalentes de teclado, una entrada cada uno, y no hacen nada si el orden no cambia.
- **REA-054** SSR seguro: importar el paquete en un entorno sin `window` no falla (el canvas se monta solo en cliente).

### 5.7 Empaquetado

- **REA-060** ESM + CJS con tipos; `react`, `react-dom`, `konva` y `react-konva` como peer dependencies.
- **REA-061** Depende de `@diagrama-kit/core` con rango de versiones compatible (`schemaVersion` manda).
- **REA-062** Storybook (o equivalente) con historias de cada componente y de los casos límite.

### 5.8 Historial de versiones

- **REA-070** `<VersionHistory versions={entries} currentVersion? onRestore={fn} />`: componente **controlado** que no lee ni guarda nada por su cuenta. La app le pasa las versiones y decide qué hacer al restaurar.
- **REA-071** Cada entrada es `{ id: string, version: number, savedAt: string (ISO 8601), author?: string, label?: string, document: DrawingDocument }`.
- **REA-072** La lista se ordena de la versión más nueva a la más antigua y marca la entrada cuyo `version` es igual a `currentVersion`.
- **REA-073** Seleccionar una entrada muestra su `document` en una vista previa de solo lectura con `<DrawingViewer>` (REA-001).
- **REA-074** "Restaurar" solo llama a `onRestore(entry)`; no cambia el editor ni el backend. El botón está desactivado en la versión actual.
- **REA-075** Sin versiones, el componente muestra un estado vacío.

## 6. API pública esperada (boceto)

```tsx
import { DrawingEditor, type DrawingEditorHandle } from '@diagrama-kit/react';

function Page() {
  const [doc, setDoc] = useState(initial);   // viene del backend
  const ref = useRef<DrawingEditorHandle>(null);

  return (
    <>
      <DrawingEditor ref={ref} value={doc} onChange={setDoc} />
      <button onClick={() => save(serialize(doc))}>Guardar</button>
      <button onClick={() => ref.current?.exportImage({ format: 'png' })}>Exportar imagen</button>
    </>
  );
}
```

La app es responsable de `save()`: enviar `serialize(doc)` al backend con el número de versión del registro (bloqueo optimista).

## 7. Criterios de aceptación

- [ ] E2E (Playwright): cargar un JSON hecho en Flutter → mover una figura → girarla → crear una junta en un vértice → renombrarla → agrupar dos figuras → deshacer ×4 → exportar PNG. El JSON resultante pasa `core.validate` y se abre en Flutter.
- [ ] Prueba cruzada: un JSON guardado por React pasa las fixtures de conformidad de Dart y viceversa.
- [ ] Cada requisito `REA-xxx` tiene test (unitario, de componente o E2E) que cita su ID.
- [ ] Snapshot visual de exportación: fondo blanco, sin asas, texto nítido.
- [ ] Perfil de rendimiento REA-O3 documentado en el repo.
- [ ] Importar el paquete en una app Next.js/SSR de prueba no produce errores.
- [ ] Test de componente de `<VersionHistory>`: orden, versión actual marcada, vista previa y `onRestore` con la entrada elegida (REA-070 a REA-075).

## 8. Preguntas abiertas

- ~~¿Soporte táctil (móvil) en la primera versión?~~ **Decidido (2026-11-17): no.** La v1 se usa con ratón, teclado y trackpad; la entrada táctil queda fuera de alcance (sección 3).
- ¿Fuente por defecto fija (para fidelidad con Flutter) o configurable? **Decidido (2026-11-17): fija, `Arial`, solo para las etiquetas de las juntas y en ambas implementaciones** (REA-030, FLT-032, spec 02 sección 12).
- ~~¿Se ofrece la barra de herramientas como componente listo o solo la API imperativa?~~ **Decidido (2026-11-17): componente listo** (REA-053).
- ¿Historial de versiones: componente de UI opcional dentro del paquete o solo documentación de cómo integrarlo? **Decidido (2026-11-17): componente** (REA-070 a REA-075): listar, previsualizar y restaurar. La comparación visual entre versiones queda para más adelante (sección 3).
