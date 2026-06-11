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
