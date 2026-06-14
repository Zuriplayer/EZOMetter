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
modules/combat_summary.lua
modules/equipment_sets.lua
modules/buff_alert.lua
modules/off_balance_tracker.lua
modules/coral_tracker.lua
modules/dd_stats_tracker.lua
modules/observed_damage_tracker.lua
modules/ability_tracker.lua
modules/saved_vars.lua
modules/menu.lua
```

## Perfil de rol

`EZOMetter` guarda un perfil manual de rol (`dd`, `healer`, `tank`) para separar las metricas desde el principio.

La primera funcionalidad activa usa el perfil `dd` y comprueba buffs propios requeridos. `healer` y `tank` quedan preparados en configuracion y catalogo, pero sin metricas activas todavia.

`Banner Bearer` se trata como requisito condicional: solo aparece como buff ausente cuando alguna variante de Banner esta sloteada en la barra primaria o secundaria.

`Off Balance` vive en un tracker separado porque no es un buff propio del jugador. El primer paso muestra estado live del objetivo o boss seguido; el calculo de uptime de pelea queda para una iteracion posterior.

Para auditar si la lectura es real, el tracker puede registrar en Debug Viewer lecturas directas de `reticleover`, eventos de efecto, IDs, nombres, fuente y tiempos restantes. Esa auditoria queda desactivada por defecto y requiere tambien el modo debug general.

`Coral Riptide` vive en otro tracker separado porque no es un buff binario. Se detecta desde equipo con `modules/equipment_sets.lua` y estima el bonus de Weapon/Spell Damage por stamina perdida. No intenta atribuir dano real por hit, porque Coral modifica el stat usado por las habilidades en vez de producir un evento de dano independiente.

`DD Stats` vive en una ventana propia para no mezclar caps y objetivos de stats con alertas de buffs. Lee stats ofensivos propios mediante `GetPlayerStat` cuando las constantes existen, muestra el mayor Weapon/Spell Damage, critico, penetracion y dano critico, y guarda min/media/max por combate. Penetracion y dano critico se tratan como posibles sobrecaps; dano ofensivo y critico alto son informacion positiva o contextual, no fallo estricto.

`Dano observado` vive en una ventana propia basada en `LibCombat` opcional. Muestra DPS propio, proporcion sobre grupo observado y resumen de combate al pasar el cursor. El dato de grupo se etiqueta siempre como observado porque depende de los eventos recibidos y clasificados por el cliente.

`Habilidades` vive en un tracker separado para avisos de canal/cast concretos. La primera habilidad soportada es Fatecarver/Exhausting Fatecarver/Pragmatic Fatecarver. El tracker sigue el patron de addons especificos de Arcanist como Custom Beam Tracker: detecta `ACTION_RESULT_BEGIN` de los abilityId de Fatecarver y usa `hitValue` como duracion real del canal, de modo que morphs y Crux quedan mejor cubiertos que con un timer fijo.

Los resumenes de ultimo combate y tooltips HUD reutilizan `modules/combat_summary.lua`. Nuevas funcionalidades con uptime, caidas o resumen al pasar el cursor deben consumir ese modulo comun en vez de duplicar muestreo, formato o manejo de tooltip.

## Visibilidad de HUD

Los controles visuales propios deben comportarse como HUDs de ESO, no como ventanas globales.

- Crear el TopLevelWindow oculto por defecto.
- Registrarlo mediante `ZO_SimpleSceneFragment`.
- Anadir el fragmento solo a `HUD_SCENE` y `HUD_UI_SCENE`.
- Consultar `EZOMetter_VisualContext.CanShowHud()` antes de cualquier `SetHidden(false)`.
- Refrescar visibilidad desde el callback central `SceneStateChanged`.
- No usar listas negativas de escenas.

El modo mover es global: `general.unlockHud` muestra todos los paneles visuales en HUD/HUD_UI y permite arrastrarlos individualmente. No hay botones de test, reset ni desbloqueo por panel en LAM.

## Pendiente de medicion avanzada

- Validar en juego el comportamiento de LibCombat en trials grandes y separar claramente `boss` frente a `total`.
- Decidir si se anade integracion opcional con `LibGroupCombatStats` para datos compartidos por jugador.
