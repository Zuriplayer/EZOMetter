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
modules/visual_context.lua
modules/buff_alert.lua
modules/off_balance_tracker.lua
modules/saved_vars.lua
modules/menu.lua
```

## Perfil de rol

`EZOMetter` guarda un perfil manual de rol (`dd`, `healer`, `tank`) para separar las metricas desde el principio.

La primera funcionalidad activa usa el perfil `dd` y comprueba buffs propios requeridos. `healer` y `tank` quedan preparados en configuracion y catalogo, pero sin metricas activas todavia.

`Banner Bearer` se trata como requisito condicional: solo aparece como buff ausente cuando alguna variante de Banner esta sloteada en la barra primaria o secundaria.

`Off Balance` vive en un tracker separado porque no es un buff propio del jugador. El primer paso muestra estado live del objetivo o boss seguido; el calculo de uptime de pelea queda para una iteracion posterior.

Para auditar si la lectura es real, el tracker puede registrar en Debug Viewer lecturas directas de `reticleover`, eventos de efecto, IDs, nombres, fuente y tiempos restantes. Esa auditoria queda desactivada por defecto y requiere tambien el modo debug general.

Los resumenes de ultimo combate y tooltips HUD reutilizan `modules/combat_summary.lua`. Nuevas funcionalidades con uptime, caidas o resumen al pasar el cursor deben consumir ese modulo comun en vez de duplicar muestreo, formato o manejo de tooltip.

## Visibilidad de HUD

Los controles visuales propios deben comportarse como HUDs de ESO, no como ventanas globales.

- Crear el TopLevelWindow oculto por defecto.
- Registrarlo mediante `ZO_SimpleSceneFragment`.
- Anadir el fragmento solo a `HUD_SCENE` y `HUD_UI_SCENE`.
- Consultar `EZOMetter_VisualContext.CanShowHud()` antes de cualquier `SetHidden(false)`.
- Refrescar visibilidad desde el callback central `SceneStateChanged`.
- No usar listas negativas de escenas.

## Pendiente antes de implementar medicion

- Confirmar alcance exacto: combate local segun `docs/meter-scope.md`, recursos, grupo, encounter, parse local u otro uso.
- Verificar APIs reales de ESO en UESP o cliente segun `docs/api-research.md`.
- Definir si la UI sera LAM, ventana propia, chat controlado o integracion opcional con `EZOTools`.
- Definir SavedVariables necesarias.
