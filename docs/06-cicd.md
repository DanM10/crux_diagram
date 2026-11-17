# 06 · CI/CD del monorepo

Plataforma: **GitHub Actions**. Destinos: **pub.dev** (Dart) y **npm** (JS).

---

## 1. Objetivo

Verificar automáticamente cada cambio y publicar cada paquete de forma independiente, segura y repetible, disparando la publicación **con un tag**.

> pub.dev no publica por push a una rama: la publicación automática se dispara por **tag**. Es una restricción de pub.dev y además permite decidir exactamente qué versión sale.

## 2. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| CI-O1 | Un PR no puede fusionarse si rompe pruebas, análisis o conformidad | Protección de rama + checks obligatorios |
| CI-O2 | Cambiar solo `dart/` no ejecuta el CI de JS, y viceversa | Filtros por ruta |
| CI-O3 | Cambiar `spec/` o `fixtures/` ejecuta **ambos** CI | Filtros por ruta |
| CI-O4 | Publicar un paquete = crear un tag; no se guardan tokens en el repositorio | OIDC (pub.dev) y trusted publishing (npm) |
| CI-O5 | Un tag que no coincide con la versión del paquete falla antes de publicar | Paso de verificación |

## 3. Workflows

```
.github/workflows/
├── ci-dart.yml          ← pruebas y análisis de Dart
├── ci-js.yml            ← pruebas y análisis de JS
├── conformance.yml      ← fixtures contra Dart y JS (job de síntesis)
├── release-dart.yml     ← publica en pub.dev (tag dart-v*)
├── release-js-core.yml  ← publica @diagrama-kit/core (tag js-core-v*)
└── release-js-react.yml ← publica @diagrama-kit/react (tag js-react-v*)
```

### 3.1 CI

| Workflow | Se ejecuta si cambia | Pasos |
|---|---|---|
| `ci-dart` | `dart/**`, `spec/**`, `fixtures/**` | `dart pub get`, `dart format --set-exit-if-changed`, `dart analyze`, `dart test` (incluye conformidad), `dart pub publish --dry-run` |
| `ci-js` | `js/**`, `spec/**`, `fixtures/**` | instalar, `tsc --noEmit`, lint, tests (Node y navegador), build, `npm pack --dry-run`, verificar schema generado |
| `conformance` | `spec/**`, `fixtures/**` | Orquesta ambos y falla si alguno no pasa las fixtures |

- **CI-001** Los jobs usan caché de dependencias (`pub-cache`, `npm`).
- **CI-002** Matriz mínima: Dart/Flutter estable; Node LTS vigentes.
- **CI-003** `ci-dart`, `ci-js` y `conformance` son **checks obligatorios** en la protección de `main`.
- **CI-004** Al usar filtros por ruta, los checks obligatorios deben seguir "pasando" cuando no corren (patrón: un job final de síntesis que siempre se ejecuta y decide), o se configuran con rutas siempre activas.

### 3.2 Tags de publicación

| Paquete | Patrón de tag | Destino |
|---|---|---|
| Dart | `dart-v1.2.0` | pub.dev |
| JS core | `js-core-v1.2.0` | npm `@diagrama-kit/core` |
| JS react | `js-react-v1.2.0` | npm `@diagrama-kit/react` |

- **CI-010** Los tags antiguos del repo importado llevan prefijo `dart-legacy-` y no coinciden con ningún patrón (ver `01-migracion-monorepo.md`).
- **CI-011** Todo workflow de release **verifica** que la versión del tag coincide con `pubspec.yaml` / `package.json` y que el commit del tag está en `main`; si no, falla.
- **CI-012** Todo release corre primero el CI completo del paquete.

## 4. Publicar en pub.dev

### 4.1 Configuración (una sola vez)

1. La **primera versión se publica manualmente** (`dart pub publish`) para que el paquete exista en pub.dev.
2. En pub.dev → *Admin* del paquete → **Automated publishing** → habilitar GitHub Actions, indicar el repositorio y el patrón de tag `dart-v{{version}}`.
3. Opcional pero recomendado: exigir un *environment* de GitHub (por ejemplo `pub-dev`) con aprobación manual.

No hay tokens que guardar: la autenticación es por OIDC entre GitHub y pub.dev.

### 4.2 Workflow

```yaml
name: release-dart
on:
  push:
    tags: ['dart-v[0-9]+.[0-9]+.[0-9]+*']

jobs:
  publish:
    permissions:
      id-token: write          # necesario para OIDC
    uses: dart-lang/setup-dart/.github/workflows/publish.yml@v1
    with:
      working-directory: dart
      environment: pub-dev     # si se configuró un environment
```

Antes de este job se recomienda otro que verifique tag ↔ versión (CI-011) y corra `ci-dart`.

## 5. Publicar en npm

- **CI-020** Se usa *trusted publishing* de npm (OIDC) cuando esté disponible para el paquete; la primera publicación puede requerir hacerse manualmente. Si no es posible, un token de automatización guardado como *secret* de GitHub, con alcance mínimo y rotación periódica.
- **CI-021** Publicación con `--provenance` y `--access public` para paquetes con scope.
- **CI-022** `core` se publica **antes** que `react` cuando ambos cambian (el `react` depende de él). Dos tags distintos, publicados en orden.

```yaml
name: release-js-core
on:
  push:
    tags: ['js-core-v[0-9]+.[0-9]+.[0-9]+*']

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
          registry-url: https://registry.npmjs.org
      - run: npm ci
        working-directory: js
      - run: npm test --workspace @diagrama-kit/core
        working-directory: js
      - run: npm publish --workspace @diagrama-kit/core --provenance --access public
        working-directory: js
```

## 6. Versionado

- **CI-030** Hay **dos versiones distintas**: la del *formato* (`schemaVersion` en el JSON, spec 02) y la de cada *paquete* (SemVer).
- **CI-031** Un cambio de formato que altere significado de campos existentes sube `version` del formato y exige **major** en todos los paquetes.
- **CI-032** Cada paquete mantiene su `CHANGELOG.md`. Opcional: automatizar con **release-please** (genera un PR de versión y, al aprobarlo, crea el tag) o **Changesets** para JS.
- **CI-033** La compatibilidad entre `react` y `core` se declara con un rango en `package.json` y se prueba en CI contra el `core` del propio monorepo.

## 7. Seguridad

- **CI-040** Permisos mínimos por workflow (`permissions:` explícito); `id-token: write` solo en los de release.
- **CI-041** Acciones de terceros fijadas por versión (idealmente por SHA para las de release).
- **CI-042** Protección de tags `*-v*`: solo mantenedores pueden crearlos.
- **CI-043** `gitleaks` en CI para impedir que se cuelen secretos en PRs.
- **CI-044** Dependabot (o Renovate) para Actions, pub y npm.

## 8. Criterios de aceptación

- [ ] Un PR que cambia solo `dart/` ejecuta únicamente el CI de Dart y se puede fusionar con checks en verde.
- [ ] Un PR que cambia una fixture ejecuta Dart y JS; si una implementación no la cumple, el PR queda bloqueado.
- [ ] Crear el tag `dart-v0.1.1` publica la versión `0.1.1` en pub.dev sin ningún token almacenado.
- [ ] Crear un tag con versión que no coincide con `pubspec.yaml` falla antes de publicar.
- [ ] Crear `js-core-v0.1.1` publica `@diagrama-kit/core@0.1.1` con provenance visible en npm.
- [ ] Un intento de publicar desde una rama distinta de `main` falla.

## 9. Preguntas abiertas

- ¿Release manual (crear tags a mano) o automatizado con release-please/Changesets?
- ¿Se exige aprobación manual (environment protegido) antes de publicar en producción?
- ¿Gestor de workspaces de JS: npm workspaces, pnpm o yarn?
- ¿Se publica documentación (GitHub Pages) generada a partir de las specs y de `dart doc`/TypeDoc?
