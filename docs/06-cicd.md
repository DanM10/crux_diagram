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
├── release-js-core.yml  ← publica @crux-diagram/core (tag js-core-v*)
└── release-js-react.yml ← publica @crux-diagram/react (tag js-react-v*)
```

### 3.1 CI

| Workflow | Se ejecuta si cambia | Pasos |
|---|---|---|
| `ci-dart` | `dart/**`, `spec/**`, `fixtures/**` | `flutter pub get`, `dart format --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test` (incluye conformidad), `flutter test` en `dart/example`, `flutter pub publish --dry-run` |

> El paquete depende del SDK de Flutter, así que el CI instala Flutter (no solo Dart) y usa `flutter analyze` / `flutter test`; `dart test` no puede cargar `flutter_test`.
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
| JS core | `js-core-v1.2.0` | npm `@crux-diagram/core` |
| JS react | `js-react-v1.2.0` | npm `@crux-diagram/react` |

- **CI-010** Los tags antiguos del repo importado llevan prefijo `dart-legacy-` y no coinciden con ningún patrón (ver `01-migracion-monorepo.md`).
- **CI-011** Todo workflow de release **verifica** que la versión del tag coincide con `pubspec.yaml` / `package.json` y que el commit del tag está en `main`; si no, falla.
- **CI-012** Todo release corre primero el CI completo del paquete.

## 4. Publicar en pub.dev

### 4.1 Configuración (una sola vez)

pub.dev solo automatiza paquetes que ya existen: "To create a new package, you must publish the first version using `dart pub publish`" ([dart.dev](https://dart.dev/tools/pub/automated-publishing)).

**Primera publicación manual:**

1. **Fijar el nombre del paquete.** El nombre de pub.dev es permanente: una versión publicada no se borra y el nombre no se puede cambiar ni reutilizar. Decidido: `crux_diagram` (antes `soft_drawer_service`).
2. Revisar `pubspec.yaml` (`name`, `description`, `version`, `repository`, `issue_tracker`), `README.md`, `CHANGELOG.md` y `LICENSE`.
3. Desde `dart/`, en `main` y con el árbol limpio:
   ```bash
   flutter analyze && flutter test
   flutter pub publish --dry-run    # debe terminar con 0 warnings
   flutter pub publish              # pide login con Google en el navegador la primera vez
   ```
   La cuenta de Google que publica queda como *uploader*. Opcional: crear antes un *verified publisher* (requiere un dominio verificado) y transferir el paquete.
4. Etiquetar el commit publicado: `git tag dart-v0.1.0 && git push origin dart-v0.1.0`. Hacerlo **antes** de que exista `release-dart.yml`, o el push del tag intentará publicar otra vez `0.1.0` (pub.dev la rechazaría por estar ya publicada).

**Publicación automática:**

5. En pub.dev → *Admin* del paquete → **Automated publishing** → habilitar GitHub Actions, repositorio `DanM10/crux_diagram` y patrón de tag `dart-v{{version}}`.
6. Opcional pero recomendado: **Require GitHub Actions environment** con nombre `pub.dev`, y crear un environment con el mismo nombre en GitHub (con *required reviewers* si se quiere aprobación manual). El workflow debe declarar `environment: pub.dev`.

No hay tokens que guardar: la autenticación es por OIDC entre GitHub y pub.dev.

### 4.2 Workflow

```yaml
name: release-dart
on:
  push:
    tags: ['dart-v[0-9]+.[0-9]+.[0-9]+*']

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: pub.dev       # si se configuró un environment
    permissions:
      contents: read
      id-token: write          # necesario para OIDC
    defaults:
      run:
        working-directory: dart
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1     # configura el token OIDC de pub.dev
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter pub publish --force
```

> **Pendiente de verificar en la sesión de release.** El workflow reutilizable `dart-lang/setup-dart/.github/workflows/publish.yml` que recomienda pub.dev ejecuta `dart pub publish` y su documentación no menciona Flutter; por eso este paquete usa un workflow propio que instala Flutter. Que `flutter pub publish` use el token OIDC que deja `setup-dart` es una suposición que se debe comprobar en el primer release automático.

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
      - run: npm test --workspace @crux-diagram/core
        working-directory: js
      - run: npm publish --workspace @crux-diagram/core --provenance --access public
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
- [ ] Crear `js-core-v0.1.1` publica `@crux-diagram/core@0.1.1` con provenance visible en npm.
- [ ] Un intento de publicar desde una rama distinta de `main` falla.

## 9. Preguntas abiertas

- ¿Release manual (crear tags a mano) o automatizado con release-please/Changesets?
- ¿Se exige aprobación manual (environment protegido) antes de publicar en producción?
- ¿Gestor de workspaces de JS: npm workspaces, pnpm o yarn?
- ¿Se publica documentación (GitHub Pages) generada a partir de las specs y de `dart doc`/TypeDoc?
