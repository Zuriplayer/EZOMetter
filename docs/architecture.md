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
modules/role_detector.lua
modules/dd_effective_stats.lua
modules/buff_alert.lua
modules/off_balance_tracker.lua
modules/coral_tracker.lua
modules/dd_stats_tracker.lua
modules/observed_metric_panel.lua
modules/observed_damage_tracker.lua
modules/observed_healing_tracker.lua
modules/ability_tracker.lua
modules/combat_reporter.lua
modules/saved_vars.lua
modules/menu.lua
```

## Perfil de rol

`EZOMetter` guarda un perfil manual de rol (`dd`, `healer`, `tank`) para separar las metricas desde el principio.

El rol puede quedar en modo manual o automatico. El modo automatico no lee un rol oficial del juego: infiere `dd`, `healer` o `tank` mediante una heuristica conservadora basada en armas equipadas y habilidades sloteadas. Si no hay senales claras, cae a `dd`. El detector debe actualizar el perfil al cambiar barras, armas o equipo, y despues refrescar los modulos visuales.

La alerta de buffs usa el perfil activo y lee el catalogo de efectos por rol. `dd` mantiene sus buffs ofensivos propios y `healer` empieza con Major Sorcery/Major Prophecy como imprescindibles propios basicos. `tank` queda preparado en configuracion y catalogo, pero sin checklist activo hasta definir una lista conservadora.

`Banner Bearer` se trata como requisito condicional: solo aparece como buff ausente cuando alguna variante de Banner esta sloteada en la barra primaria o secundaria.

`Off Balance` vive en un tracker separado porque no es un buff propio del jugador. El primer paso muestra estado live del objetivo o boss seguido; el calculo de uptime de pelea queda para una iteracion posterior.

Para auditar si la lectura es real, el tracker puede registrar en Debug Viewer lecturas directas de `reticleover`, eventos de efecto, IDs, nombres, fuente y tiempos restantes. Esa auditoria queda desactivada por defecto y requiere tambien el modo debug general.

`Coral Riptide` vive en otro tracker separado porque no es un buff binario. Se detecta desde equipo con `modules/equipment_sets.lua` y estima el bonus de Weapon/Spell Damage por stamina perdida. No intenta atribuir dano real por hit, porque Coral modifica el stat usado por las habilidades en vez de producir un evento de dano independiente.

Los sets unicos de soporte quedan como funcionalidad futura independiente del perfil de rol. El diseno previsto es un panel propio que detecte si el jugador lleva el set equipado y, solo entonces, mida su estado/uptime/proc. Esto aplica a casos como Pillager's Profit, Powerful Assault, Roaring Opportunist, Alkosh, Crimson Oath, Turning Tide o equivalentes. No deben mezclarse con los paneles base de DD/healer/tank ni tratarse como obligatorios por rol.

`DD Stats` vive en una ventana propia para no mezclar caps y objetivos de stats con alertas de buffs. Lee stats ofensivos propios mediante `GetPlayerStat` cuando las constantes existen, muestra el mayor Weapon/Spell Damage, critico, penetracion y dano critico, y guarda min/media/max por combate. Penetracion y dano critico se tratan como posibles sobrecaps; dano ofensivo y critico alto son informacion positiva o contextual, no fallo estricto.

`Dano observado` y `Curacion observada` viven en ventanas propias basadas en `LibCombat` opcional. Ambas usan `modules/observed_metric_panel.lua` como motor comun para ventana, baseline de combate, lectura de fight recap, tooltip y reporte. `Dano observado` configura campos DPS/dano y `Curacion observada` configura campos HPS/curacion; los datos de grupo se etiquetan siempre como observados porque dependen de los eventos recibidos y clasificados por el cliente.

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
