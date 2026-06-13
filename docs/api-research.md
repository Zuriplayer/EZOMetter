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
