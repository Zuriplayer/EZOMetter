# EZOMetter - AI Development Rules

Este proyecto es un addon para The Elder Scrolls Online (ESO).

El entorno Lua de ESO es limitado y no equivale a Lua estandar. El objetivo inicial es mantener `EZOMetter` pequeno, estable y facil de revisar dentro de la familia EZO.

## Alcance

- Addon independiente: `EZOMetter`.
- Panel LibAddonMenu como interfaz de configuracion.
- Dos idiomas: ingles y espanol, con opcion `Automatico`.
- Sin menu lateral.
- Sin overlay complejo persistente hasta que se defina el diseno.
- Sin keybindings.
- Sin interceptar input.
- Sin integraciones directas con otros addons salvo APIs pequenas y opcionales.

## Reglas obligatorias

- No inventar APIs de ESO.
- Verificar cualquier API nueva en UESP ESO Data o en el cliente antes de usarla.
- No usar librerias externas salvo indicacion expresa.
- Usar correctamente `LibAddonMenu-2.0`; `LibChatMessage`, `LibDebugLogger` y `DebugLogViewer` son opcionales.
- Mantener cambios pequenos y revisables.
- No anadir modulos heredados de `EZOTools` salvo necesidad clara.
- Si se anade un archivo runtime, anadirlo a `EZOMetter.txt` en orden logico.
- Evitar globals innecesarias; usar `EZOMetter = EZOMetter or {}`.
- Usar prefijo de eventos/globales propio: `EZOMetter_` o `EZOM_`.

## Versionado

Para cambios visibles del addon, actualizar version con:

- `.\tools\bump-version.ps1 -Patch`
- o `.\tools\bump-version.ps1 -Version x.y.z`

La version visible debe quedar sincronizada entre:

- `EZOMetter.txt` (`## Version`)
- `modules/core.lua` (`EZOMetter.ADDON_VERSION`)

`## AddOnVersion` debe incrementarse cuando cambia la version visible.

No adivinar `## APIVersion`; cambiarlo solo si el valor actual esta verificado.

Antes de commit, ejecutar:

- `.\tools\bump-version.ps1 -Check`
- `git diff --check`

## Localizacion

- Usar `lang/en.lua` y `lang/es.lua`.
- No hardcodear textos visibles en modulos.
- Usar IDs `EZOM_*`.
- Cada clave debe existir en ambos idiomas.

## Discord y publicaciones

- La configuracion de webhooks vive en `ezo-addon.json`.
- Los scripts de `scripts/ezo` pueden hacer dry-run.
- No publicar en Discord sin autorizacion explicita.
- No hacer push sin autorizacion explicita.

## No hacer

- No crear menu lateral heredado de `EZOTools`.
- No crear `Bindings.xml` sin una decision explicita.
- No registrar keybindings.
- No tocar input global.
- No copiar overlay, gamepad dialogs, quick utility ni side menu desde `EZOTools`.
- No convertir `EZOTools` en dependencia directa.

## Checklist de pruebas

Siempre indicar:

- Carga del addon sin errores Lua.
- `/reloadui`.
- Apertura del panel de configuracion LAM.
- Persistencia de idioma.
- Persistencia de debug.
- Teclado y gamepad sin cambios de input.
