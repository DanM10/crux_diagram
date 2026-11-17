# crux_diagram

Editor y visor de dibujos de figuras con juntas, basado en un **formato JSON abierto**, con dos implementaciones que hablan el mismo formato:

- **Dart / Flutter** → paquete `soft_drawer_service`, publicado en pub.dev. **Ya existe y es funcional**; es la implementación de referencia.
- **TypeScript / React** → paquetes en npm (`core` sin dependencias de React + componente `react`). **Todavía no existe**; se adapta al formato y al comportamiento de Flutter.

Un dibujo creado en un lado se abre y se edita en el otro. El formato es el producto; los paquetes son implementaciones de él.

---

## 1. Estructura del monorepo

```
crux_diagram/
├── README.md                  ← este archivo
├── docs/
│   ├── 01-migracion-monorepo.md
│   ├── 06-cicd.md
│   └── flutter-specs/         ← specs 00 a 06 del paquete Flutter (comportamiento de referencia)
├── spec/
│   ├── 02-spec-formato-json.md        ← fuente de verdad del formato
│   ├── 03-spec-flutter.md
│   ├── 04-spec-react-core.md
│   ├── 05-spec-react-editor.md
│   └── schema/drawing.v1.schema.json  ← JSON Schema (pendiente de crear)
├── fixtures/                  ← pruebas compartidas por TODAS las implementaciones
│   ├── valid/
│   ├── invalid/
│   ├── roundtrip/
│   └── geometry/
├── dart/                      ← paquete Flutter (historial del repo actual vive aquí)
└── js/
    ├── core/                  ← @diagrama-kit/core
    └── react/                 ← @diagrama-kit/react
```

## 2. Cómo está pensada esta documentación (enfoque ODD)

Interpretación usada: **Outcome-Driven Development**. Se define primero *qué resultado verificable debe existir* y solo después cómo construirlo. Cada documento de spec sigue la misma estructura:

1. **Objetivo**: para qué existe.
2. **Resultados esperados (outcomes)**: qué debe ser verdad cuando esté terminado, con cómo se verifica.
3. **Alcance y fuera de alcance**.
4. **Requisitos con ID** (`FMT-010`, `FLT-020`, `REC-030`, `REA-040`): cada uno es una afirmación comprobable.
5. **Criterios de aceptación**: pruebas concretas que los demuestran.
6. **Preguntas abiertas**.

### Flujo de trabajo

```
Outcome → Requisito con ID → Fixture / test que lo prueba → Implementación
```

- Ninguna funcionalidad se considera hecha hasta que su requisito tiene un test.
- Los tests citan el ID en su nombre o comentario (`// FMT-031`), así se puede medir cobertura de la spec.
- Si el código y la spec discrepan, **se corrige la spec primero** (en un PR aparte o el mismo, pero visible).
- Cambios al formato requieren actualizar `spec/02`, las fixtures y ambas implementaciones.
- **Flutter manda en el comportamiento.** Mientras React no exista, cualquier duda sobre cómo debe comportarse algo se resuelve mirando Flutter y sus specs (`docs/flutter-specs/`). Si React necesita algo distinto, se discute y se actualiza la spec.

## 3. Decisiones tomadas

| # | Decisión | Motivo |
|---|---|---|
| D1 | El formato JSON es la fuente de verdad. Su contenido es el que Flutter ya lee y escribe | Flutter está avanzado y funcional; React se adapta |
| D2 | Cada figura se ubica por su **centro** (`center`) y su tamaño sin rotar (`size`) | La rotación gira alrededor del centro; es lo que ya usa Flutter |
| D3 | Las juntas se ligan a **anclas** de una figura (`shapeId` + `anchorId`), no a coordenadas | Siguen a la figura al moverla o rotarla |
| D4 | La etiqueta de una junta se posiciona con `labelOffset` desde el ancla y nunca rota | Texto siempre horizontal |
| D5 | Sin campo `computed` en v1. La geometría de las juntas se recalcula en cada lado | Las funciones son puras y están cubiertas por fixtures. Si un backend necesita dibujar sin medir texto, se agrega después |
| D6 | **Hay rotación** (radianes, sentido horario, normalizada a `[0, 2π)`) | Ya existe en Flutter |
| D7 | Tamaño de etiqueta de las juntas: `small`, `medium`, `large` para todo el documento | Ya existe en Flutter (`jointDisplay`) |
| D8 | Historial persistente = snapshots completos por guardado, en el backend de cada consumidor | Simple y restaurable |
| D9 | Publicación solo por **tag** con prefijo por paquete | Restricción de pub.dev y control de versiones |
| D10 | Fixtures compartidas obligatorias para ambas implementaciones | Evita que Dart y TS calculen distinto |
| D11 | Colores como entero ARGB de 32 bits (`0xAARRGGBB`) | Ya es el formato de Flutter. Documentado con sus trampas (CSS usa RGBA; Java necesita `long`) |
| D12 | Los campos desconocidos se ignoran al leer y no se conservan | Simplicidad mientras ambos lados estén bajo nuestro control |
| D13 | Se arranca de cero con `schemaVersion: 1`; se descartan las versiones 1 a 4 previas | Estamos en desarrollo, no hay documentos que migrar |
| D14 | La conformidad exige aceptar o rechazar, no coincidir en mensajes de error | Cada lado mantiene sus mensajes |

## 4. Preguntas abiertas globales

| # | Pregunta | Supuesto actual |
|---|---|---|
| Q1 | Nombres de los paquetes y licencia | El monorepo se llama `crux_diagram`. Falta decidir el nombre del paquete Dart (hoy `soft_drawer_service`) y el scope de npm (en las specs, `@diagrama-kit/*` es provisional). Licencia: MIT |
| Q2 | ¿El repo Flutter actual contiene código privado o secretos? | Debe auditarse antes de hacerlo público (ver `docs/01`) |
| Q3 | ¿Se agrega `computed` por junta para backends que dibujan sin medir texto? | No en v1 |
| Q4 | ¿Se conservan campos desconocidos al guardar? | No en v1 |

## 5. Glosario

- **Figura (shape):** objeto del dibujo (`square`, `rectangle`, `circle`).
- **Ancla (anchor):** punto fijo de una figura (vértice, punto medio de un lado o punto cardinal de un círculo), identificado por un id local como `tr` o `lc`.
- **Junta (joint):** ancla con nombre. Se dibuja como etiqueta con flecha guía hacia el ancla.
- **Flecha guía (leader arrow):** línea de la etiqueta de una junta al ancla, con punta en el ancla.
- **Desplazamiento de etiqueta (`labelOffset`):** vector del ancla al centro de la etiqueta.
- **Grupo (group):** conjunto de figuras que se seleccionan, mueven y eliminan juntas.
- **Fixture:** archivo JSON de prueba compartido, con su resultado esperado.
- **Conformidad:** una implementación es conforme si pasa todas las fixtures.
