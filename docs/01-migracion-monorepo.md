# 01 · Migración a monorepo conservando el historial de Flutter

## 1. Objetivo

Crear un repositorio mayor (`crux_diagram`) que contenga Flutter y React, **sin perder el historial** del repo actual que solo tiene la app/paquete Flutter.

## 2. Resultados esperados

| ID | Resultado | Verificación |
|---|---|---|
| MIG-O1 | El historial de commits del repo Flutter es visible en el monorepo | `git log -- dart/` muestra los commits antiguos |
| MIG-O2 | Ningún secreto ni dato privado queda en el historial público | Escaneo con `gitleaks` sin hallazgos |
| MIG-O3 | El repo antiguo queda archivado y referenciado, no borrado | README del repo antiguo apunta al nuevo |
| MIG-O4 | El CI del monorepo corre desde el primer commit migrado | Workflow verde en `main` |

## 3. Paso previo obligatorio: decidir qué se hace público

El plan es hacerlo open source. Antes de migrar, responder:

1. **¿El repo actual es una app con lógica de negocio privada?** Si es así, **no** conviene publicar todo su historial. Opciones:
   - Extraer solo la parte reutilizable (la del editor de diagramas) con su historial (Estrategia C).
   - Mantener la app en un repo privado y consumir el paquete publicado.
2. **¿Quién es el dueño del código?** Si fue escrito para un empleador o cliente, confirmar que se puede publicar.
3. **Auditar el historial**, no solo el estado actual: un secreto borrado hace meses sigue estando en commits viejos.

```bash
# Buscar secretos en TODO el historial
gitleaks detect --source . --log-opts="--all"
```

Si hay secretos: rotarlos (invalidarlos) **y** limpiarlos del historial. Rotar es lo que realmente protege.

## 4. Estrategias

### Estrategia A (recomendada): importar con reescritura de rutas

Mueve todo el historial bajo `dart/` para que `git log dart/lib/...` funcione.

```bash
# 1. Clon limpio del repo Flutter (filter-repo debe correr en un clon nuevo)
git clone <url-repo-flutter> flutter-tmp
cd flutter-tmp
pip install git-filter-repo
git filter-repo --to-subdirectory-filter dart \
  --tag-rename '':'dart-legacy-'

# 2. Repo nuevo
cd ..
mkdir crux_diagram && cd crux_diagram
git init -b main

# 3. Traer e integrar
git remote add flutter-old ../flutter-tmp
git fetch flutter-old
git merge flutter-old/main --allow-unrelated-histories \
  -m "chore: import flutter history under dart/"
git remote remove flutter-old
```

- Los **hashes de commit cambian** (se reescribe el historial). Es inevitable con esta estrategia.
- Los tags antiguos quedan con prefijo `dart-legacy-` para no chocar con los futuros tags de publicación (`dart-v1.0.0`).

### Estrategia B: convertir el repo actual en el monorepo

Más simple y **conserva los hashes**, pero el repo conserva su nombre y su URL (se puede renombrar).

```bash
cd repo-flutter
mkdir dart
git mv $(ls -A | grep -v -e '^\.git$' -e '^dart$') dart/
git commit -m "chore: move flutter code under dart/"
mkdir spec fixtures docs js
```

- `git log --follow dart/archivo` sigue los renombres, pero las herramientas web a veces muestran el historial cortado en el movimiento.
- Si el repo está en Bitbucket, hay que moverlo a GitHub igualmente (Actions y OIDC de pub.dev lo requieren): `git remote set-url` + `git push --mirror`.

### Estrategia C: importar solo una parte del repo

Para quedarse únicamente con el historial de ciertas carpetas (por ejemplo el código del editor):

```bash
git clone <url-repo-flutter> flutter-tmp && cd flutter-tmp
git filter-repo --path lib/diagram --path test/diagram \
  --path-rename lib/diagram:lib/src \
  --to-subdirectory-filter dart
```

Después se integra igual que en la Estrategia A (pasos 2 y 3). Es la opción más segura si el repo mezcla código privado y reutilizable.

### Comparación

| | A | B | C |
|---|---|---|---|
| Conserva historial | Sí | Sí | Solo de las rutas elegidas |
| Conserva hashes | No | Sí | No |
| `git log dart/` funciona | Sí | Con `--follow` | Sí |
| Seguro para open source | Con auditoría | Con auditoría | Sí, si eliges bien las rutas |
| Esfuerzo | Medio | Bajo | Medio |

## 5. Pasos posteriores a la migración

1. Crear las carpetas `spec/`, `fixtures/`, `docs/`, `js/` y copiar esta documentación.
2. Ajustar `dart/pubspec.yaml`: `repository:` apuntando a la URL del monorepo y `homepage`/`issue_tracker`.
3. Agregar `LICENSE` en la raíz (y copia o enlace en `dart/` y `js/*`, porque cada paquete publicado debe incluirla).
4. Crear el workflow de CI (ver `06-cicd.md`) y confirmar que pasa en `main`.
5. Archivar el repo antiguo con un README que apunte al nuevo.
6. Proteger `main`: PR obligatorio y CI verde para fusionar.

## 6. Criterios de aceptación

- [ ] `git log --oneline -- dart/ | wc -l` es igual o mayor al número de commits relevantes del repo original.
- [ ] `gitleaks detect --log-opts="--all"` sin hallazgos.
- [ ] `cd dart && dart pub get && dart test` pasa en un clon nuevo del monorepo.
- [ ] El repo antiguo está archivado y enlaza al nuevo.

## 7. Preguntas abiertas

- ¿El repo actual es la app completa o ya es un paquete? (determina A, B o C)
- ¿Dónde está alojado hoy (Bitbucket del empleador, GitHub personal)? ¿Quién autoriza publicarlo?
- ¿Se quiere conservar la app como `dart/example/` o mantenerla fuera del monorepo?

## 8. Estado de la migración

Hecho (estrategia A, repositorio `crux_diagram`):

- [x] Historial de Flutter importado bajo `dart/` (68 commits conservados). Los hashes cambiaron, como se esperaba.
- [x] Auditoría con `gitleaks detect --log-opts="--all"` antes de migrar: sin hallazgos.
- [x] `fixtures/` y `docs/flutter-specs/` movidos a la raíz; `cd dart && flutter test` y `flutter analyze` pasan.
- [x] Specs y documentación en `spec/` y `docs/`; `LICENSE` en la raíz.

Pendiente:

- [ ] Crear el repositorio en GitHub, agregar el remoto y hacer el primer push.
- [ ] `repository`, `issue_tracker` y `homepage` en `dart/pubspec.yaml`.
- [ ] Workflow de CI (`ci-dart.yml`) y verificarlo en `main` (MIG-O4).
- [ ] Archivar el repo antiguo con un README que apunte al nuevo (MIG-O3).
- [ ] Proteger `main`.
