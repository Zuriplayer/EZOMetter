# EZOMetter

Addon independiente de la familia EZO preparado como base para un futuro medidor.

El objetivo de este repositorio inicial es dejar estructura, versionado, idiomas, empaquetado, GitHub Actions y publicacion Discord en modo controlado, sin implementar todavia logica de medicion que dependa de APIs de ESO no verificadas.

## Filosofia

- Addon pequeno y revisable.
- Sin input global.
- Sin keybindings iniciales.
- Sin dependencia directa de otros addons EZO.
- Textos visibles localizados en ingles y espanol.
- Scripts de empaquetado y publicacion compatibles con la familia EZO.
- Publicacion a Discord solo bajo orden explicita.

## Estructura

- `EZOMetter.txt`: manifest del addon.
- `EZOMetter.lua`: inicializacion.
- `modules/core.lua`: constantes publicas.
- `modules/effect_catalog.lua`: catalogo inicial de efectos por rol.
- `modules/meter_session.lua`: estado y calculos puros de una sesion local.
- `modules/visual_context.lua`: guard compartido para mostrar HUDs solo en HUD/HUD_UI.
- `modules/combat_summary.lua`: utilidades compartidas para resumenes del ultimo combate y tooltips HUD.
- `modules/buff_alert.lua`: aviso movible para buffs propios requeridos.
- `modules/off_balance_tracker.lua`: tracker separado de Off Balance en target/boss, con auditoria opcional en Debug Viewer.
- `modules/saved_vars.lua`: defaults y SavedVariables.
- `modules/i18n.lua`: aplicacion de idiomas.
- `modules/debug.lua`: salida tecnica opcional.
- `modules/menu.lua`: panel LibAddonMenu.
- `lang/en.lua`: textos en ingles.
- `lang/es.lua`: textos en espanol.
- `docs/architecture.md`: decisiones tecnicas iniciales.
- `docs/meter-scope.md`: propuesta de alcance para la primera iteracion del medidor.
- `docs/api-research.md`: verificacion pendiente de APIs ESO para el medidor.
- `docs/discord.md`: politica de Discord.
- `docs/integration-with-ezotools.md`: integracion futura opcional.

## Desarrollo

```powershell
.\tools\bump-version.ps1 -Check
.\scripts\ezo\build-addon-package.ps1 -Force
git diff --check
```

El remoto previsto es:

```text
https://github.com/Zuriplayer/EZOMetter.git
```
