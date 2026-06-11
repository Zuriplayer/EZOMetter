# EZOMetter Architecture

`EZOMetter` nace como esqueleto minimo de addon EZO.

## Decisiones iniciales

- No se implementa medicion todavia.
- No se copian modulos de `EZOTools`.
- No hay keybindings ni interceptacion de input.
- La configuracion visible vive en LAM.
- Los textos visibles pasan por `lang/en.lua`, `lang/es.lua` y `modules/i18n.lua`.
- La salida tecnica usa `LibDebugLogger` si esta disponible y si el modo debug esta activado.

## Runtime inicial

```text
lang/en.lua
lang/es.lua
modules/i18n.lua
EZOMetter.lua
modules/debug.lua
modules/core.lua
modules/effect_catalog.lua
modules/meter_session.lua
modules/buff_alert.lua
modules/saved_vars.lua
modules/menu.lua
```

## Perfil de rol

`EZOMetter` guarda un perfil manual de rol (`dd`, `healer`, `tank`) para separar las metricas desde el principio.

La primera funcionalidad activa usa el perfil `dd` y comprueba buffs propios requeridos. `healer` y `tank` quedan preparados en configuracion y catalogo, pero sin metricas activas todavia.

## Pendiente antes de implementar medicion

- Confirmar alcance exacto: combate local segun `docs/meter-scope.md`, recursos, grupo, encounter, parse local u otro uso.
- Verificar APIs reales de ESO en UESP o cliente segun `docs/api-research.md`.
- Definir si la UI sera LAM, ventana propia, chat controlado o integracion opcional con `EZOTools`.
- Definir SavedVariables necesarias.
