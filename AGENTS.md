# EZOMetter - AI Development Rules


<!-- EZO-SHARED-LAM-START -->
## Estándar LAM compartido

Antes de crear o modificar ajustes LibAddonMenu, leer y aplicar:
`E:\DEV\EZOFamilyDocs\docs\ezo-lam-settings-style.md`

Las reglas específicas de este addon tienen prioridad. Si el archivo compartido
no está accesible, no modificar LAM e indicarlo explícitamente.
<!-- EZO-SHARED-LAM-END -->

### Refresco dinámico obligatorio de LAM

- Todo `setFunc` que cambie un valor leído por otro control mediante `disabled`,
  `hidden`, `choices` o una condición dinámica debe llamar a
  `EZOMetter_Menu.RequestSettingsRefresh(true)` después de guardar el valor y
  aplicar el cambio runtime.
- El refresco forzado debe seguir cubriendo ambos hosts: reconstrucción diferida
  mediante `EZOCore:RefreshSettingsPanel(true)` y
  `LibAddonMenu2.util.RequestRefreshIfNeeded(panel)` para LAM independiente.
- Síntoma de incumplimiento: el primer valor cambia, pero los controles
  dependientes conservan el estado gris/anterior hasta reabrir Ajustes o usar
  `/reloadui`.

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
- Para metricas de combate, priorizar `LibCombat` como primera fuente si expone el dato necesario; usar calculos propios solo como fallback o complemento documentado.
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

## Documentación

- Toda modificación funcional, de configuración, comportamiento, alcance o requisitos debe incluir en el mismo trabajo la revisión y actualización de `README.md` y `README.es.md`.
- Ambos README deben mantenerse equivalentes y sincronizados.
- Ningún README debe anunciar funciones, límites o requisitos que no coincidan con el código actual.
- Deben actualizarse las secciones afectadas: funciones, límites de seguridad, requisitos, instalación y pruebas.
- Antes de cerrar cualquier cambio se debe comprobar expresamente que ambos README siguen completos y actualizados.

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

<!-- EZO-ESO-UPDATE-START -->
## Baseline obligatorio de ESO

Antes de analizar, modificar, validar, versionar o publicar este proyecto, leer
`..\EZOFamilyDocs\docs\eso-updates\current.md` y aplicar la política enlazada.

Baseline vigente: `U51-PTS-v12.1.0`.

- La matriz por addon vive en `..\EZOFamilyDocs\data\eso-update-baseline.json`.
- U51 sigue siendo PTS provisional hasta que exista verificación explícita.
- No cambiar `## APIVersion` por inferencia; verificarla en el cliente o en una
  fuente fiable de API.
- Si estos archivos no están disponibles, detener el trabajo sensible a
  compatibilidad e indicar el bloqueo.

Fuente remota de respaldo:
https://github.com/Zuriplayer/EZOFamilyDocs/blob/main/docs/eso-updates/current.md
<!-- EZO-ESO-UPDATE-END -->
