# API Research

Notas de verificacion para no introducir APIs inventadas en `EZOMetter`.

## Estado

Investigacion inicial hecha el 2026-06-11.

La busqueda publica localizo paginas de UESP ESO Data para API `101049`:

- `OnCombatEvent`: https://esoapi.uesp.net/101049/data/o/n/c/OnCombatEvent.html
- `OnPlayerCombatState`: https://esoapi.uesp.net/101049/data/o/n/p/OnPlayerCombatState.html

La lectura automatica directa de esas paginas quedo bloqueada por Cloudflare, asi que estas APIs no se consideran confirmadas para runtime todavia.

## Senales secundarias

Referencias publicas apuntan a estas piezas como candidatas:

- `EVENT_PLAYER_COMBAT_STATE` para detectar entrada/salida de combate.
- `EVENT_COMBAT_EVENT` para recibir resultados de combate.
- `REGISTER_FILTER_COMBAT_RESULT` y `REGISTER_FILTER_IS_ERROR` como filtros habituales sobre eventos de combate.
- Resultados habituales para el MVP: `ACTION_RESULT_DAMAGE`, `ACTION_RESULT_CRITICAL_DAMAGE`, `ACTION_RESULT_DOT_TICK`, `ACTION_RESULT_DOT_TICK_CRITICAL`, `ACTION_RESULT_HEAL`, `ACTION_RESULT_CRITICAL_HEAL`, `ACTION_RESULT_HOT_TICK`, `ACTION_RESULT_HOT_TICK_CRITICAL`.

Estas senales salen de ejemplos y proyectos publicos, no sustituyen la verificacion final en UESP o cliente.

## Pendiente antes de codigo runtime

Confirmar dentro del cliente ESO o con UESP accesible:

- firma exacta actual de `EVENT_COMBAT_EVENT`;
- firma exacta actual de `EVENT_PLAYER_COMBAT_STATE`;
- si `REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE` o un filtro equivalente permite aislar al jugador local;
- valores reales para identificar fuente local frente a mascota, aliado o entorno;
- comportamiento en live y pts;
- si `hitValue` representa dano/sanacion final para todos los resultados del MVP;
- diferencias esperadas en PvE/PvP por restricciones de informacion.

## Decision provisional

No se registra ningun evento de combate hasta completar la verificacion anterior.

El siguiente paso seguro es crear un modulo de dominio puro que pueda sumar muestras ya normalizadas, sin depender todavia del API de ESO. Ese modulo permitira probar el calculo de totales, DPS y HPS antes de conectar eventos reales.

## Off Balance

Investigacion adicional hecha el 2026-06-13.

Conclusiones actuales:

- `Off Balance` debe mostrarse como estado del objetivo/boss, no como buff propio.
- En bosses el ciclo esperado es `Off Balance` activo durante 7 segundos y despues una ventana de 15 segundos en la que el mismo target no puede volver a entrar en `Off Balance`.
- Esa ventana no significa inmunidad al dano; en UI se debe rotular como `Cooldown OB`, no como `Inmune`.
- El cooldown es por target. En combates con varios enemigos puede haber Off Balance en objetivos distintos de forma solapada.
- Las estadisticas de otros addons pueden no ser comparables con el uptime de un boss unico: Combat Metrics suma uptime por unidades seleccionadas y puede dividir por `totalUnitTime`, no siempre por toda la duracion del combate.
- El tracker live debe mostrar fuente de lectura:
  - `directa`: lectura actual de `GetUnitBuffInfo("reticleover", index)`;
  - `evento`: dato recibido por `EVENT_EFFECT_CHANGED` para boss/target conocido;
  - `estimada`: cooldown sintetico de 15s tras terminar Off Balance;
  - `memoria`: ultimo estado retenido al no estar mirando el target.
- Para verificar el dato real en cliente, el tracker incluye una auditoria opcional:
  - requiere `Modo depuracion` general y `Registrar Off Balance`;
  - registra en Debug Viewer lecturas directas, eventos `EVENT_EFFECT_CHANGED`, `abilityId`, nombre, unidad, estado y tiempo restante;
  - el boton `Escanear objetivo ahora` vuelca todos los buffs de `reticleover` para confirmar IDs/nombres en dummy o boss real.
- Inspirado por `OffBalanceTracker`, el tracker mantiene `Boss Focus`, prioridad del boss bajo reticula, cooldown sintetico cuando expira `Off Balance`, colores por estado y un pulso visual breve al entrar en estado activo.

Fuentes revisadas:

- UESP `Online:Off Balance`.
- ESOUI `Off Balance Tracker`, que monitoriza el estado activo y el cooldown de 15 segundos.
- Bandits UI, que muestra Off Balance en reticula desde `GetUnitBuffInfo("reticleover", index)`.
- ESOUI `OdyHybridHeal`, que diferencia listo, activo y cooldown/inmunidad.
- Combat Metrics, codigo fuente GitHub, para entender el calculo de uptime por unidades seleccionadas.
- Discusiones publicas de ZOS/ESO sobre el cambio a 7 segundos activo y 15 segundos de no reaplicacion por target.

### Exploiter

Investigacion adicional hecha el 2026-07-07.

Conclusiones actuales:

- `Exploiter` es una estrella slottable de Warfare que aumenta el dano contra enemigos realmente `Off Balance` en 2% por etapa, maximo 10% con 50 puntos.
- El cooldown/no reaplicacion de `Off Balance` no aporta valor directo a `Exploiter`; solo sirve para medir cadencia de aplicacion del grupo.
- No se ha encontrado una lectura nativa separada de "dano aportado por Exploiter". El evento de dano entrega el valor final ya modificado.
- La medicion viable es estimada:
  - detectar si `Exploiter` esta slottado con `GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)`;
  - leer puntos con `GetNumPointsSpentOnChampionSkill(starId)`;
  - medir dano saliente mientras el target seguido esta en `Off Balance` real;
  - calcular valor ponderado por dano: proporcion de dano durante OB real por bonus de Exploiter;
  - calcular dano extra estimado desde dano final: `danoDuranteOB * bonus / (100 + bonus)`.
- El patron de deteccion de CP se apoya en LibCombat, WizardsWardrobe y Bandits UI, que usan `GetSlotBoundId`/`GetNumPointsSpentOnChampionSkill` para leer CP slottados sin abrir la escena de Champion Points.

Fuentes revisadas:

- ESO-Hub `Exploiter`.
- UESP `Online:Exploiter` y `Online:Off Balance`.
- ESOUI forum `PTS Get equipped champion skill ID`.
- LibCombat, WizardsWardrobe, Bandits UI y Combat Metrics instalados localmente.

## Coral Riptide

Investigacion adicional hecha el 2026-06-13.

Conclusiones actuales:

- `Coral Riptide` y `Perfected Coral Riptide` se tratan como equivalentes para EZOMetter: el extra perfected aporta critico, pero el bonus dinamico que nos importa es el mismo.
- El bonus actual documentado por ESO-Hub para ambas versiones es hasta `600` Weapon/Spell Damage en funcion de stamina perdida, alcanzando el maximo al `50%` de stamina.
- No hay una lectura directa fiable de "dano causado por Coral" como evento independiente. Coral modifica el stat de dano de habilidades, asi que el tracker estima el bonus de stat: `600 * min((100 - staminaPct) / 50, 1)`.
- El resumen de combate reporta `bonus medio estimado`, suponiendo que el jugador estuvo haciendo dano durante la ventana medida. No intenta convertir ese bonus de stat a dano final real, porque eso depende de skill, critico, penetracion, buffs, target y mitigacion.
- La deteccion de equipo usa `GetItemLinkSetInfo(itemLink, true)` sobre `BAG_WORN`. El modo debug de Coral registra nombres y `setId` para poder fijar IDs si la localizacion del cliente devuelve nombres no previstos.
- Estados HUD:
  - `CAP`: stamina <= 50%, bonus +600;
  - `OK`: stamina <= 55%, bonus >= +540;
  - `Medio`: stamina <= 65%;
  - `Bajo`: stamina <= 80%;
  - `Malo`: stamina > 80%;
  - `Inactivo`: no hay 5 piezas activas.

Fuentes revisadas:

- ESO-Hub `Coral Riptide`.
- ESO-Hub `Perfected Coral Riptide`.
- UESP `Online:Coral Riptide` y `Online:Perfected Coral Riptide`.
- ESOUI/foros sobre `GetItemLinkSetInfo(itemLink, true)`.

## DD Stats

Investigacion adicional hecha el 2026-06-13.

Conclusiones actuales:

- La primera ventana de stats DD usa solo stats propios del jugador, no escanea debuffs del target ni intenta calcular penetracion efectiva final del grupo.
- Dano ofensivo usa el mayor entre `STAT_WEAPON_POWER` y `STAT_SPELL_POWER`, porque el escalado hibrido usa el stat ofensivo mas alto para la mayoria de habilidades.
- Critico usa el mayor entre `STAT_CRITICAL_STRIKE` y `STAT_SPELL_CRITICAL` cuando `GetPlayerStat` los expone. Si el valor llega como rating, se normaliza con el divisor documentado publicamente de `21918` rating para 100 puntos porcentuales.
- Penetracion usa el mayor entre `STAT_PHYSICAL_PENETRATION` y `STAT_SPELL_PENETRATION`. El objetivo por defecto `7200` representa un DD en trial veterana organizada donde soportes/debuffs cubren el resto hasta la armadura PvE instanciada de `18200`.
- Dano critico se lee primero desde `GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE)`, siguiendo el patron de LibCombat/Combat Metrics. Ese valor avanzado es bonus sobre el 50% base, asi que el tracker lo convierte a total con `50 + percentValue`. Si la API no existe, queda un fallback defensivo con constantes `STAT_*`.
- Defaults de corte:
  - dano ofensivo: objetivo `5000`, sin cap duro;
  - critico: objetivo `50%`, alto contextual `70%`;
  - penetracion: objetivo `7200`, alto `7700`;
  - dano critico: objetivo/cap `125%`.

Fuentes revisadas:

- UESP ESO Data `GetPlayerStat`.
- UESP ESO Data `self.SetupAdvancedStats()`.
- LibCombat/Combat Metrics, que usan `GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE)` para crit damage.
- ESOUI `Dynamic Stats`, que muestra mayor Weapon/Spell Damage, critico, penetracion y dano critico.
- Hyperioxes U50 penetration calculator.
- Hyperioxes U50 critical damage/chance calculator.
- ESO-Hub critical damage guide.
