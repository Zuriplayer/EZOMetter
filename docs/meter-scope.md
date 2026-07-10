# Meter Scope

Este documento fija una propuesta de alcance inicial para que `EZOMetter` pueda avanzar sin convertirse en una copia grande de otros medidores.

## Objetivo del MVP

La primera iteracion debe orientarse a DD y empezar por senales locales seguras:

- avisar cuando falten buffs propios basicos de DD;
- mostrar Off Balance en un tracker separado de objetivo/boss, sin mezclarlo con buffs propios;
- preparar perfiles de rol para `DD`, `Healer` y `Tank`;
- mantener `Tank` sin checklist activo hasta definir sus metricas;
- iniciar `Healer` con imprescindibles propios basicos y una lectura HPS observada mediante LibCombat.

La primera iteracion de medidor de combate debe ser un medidor local ligero:

- medir sesiones de combate del jugador local;
- registrar dano realizado, sanacion realizada y duracion de sesion;
- calcular DPS y HPS basicos a partir de totales locales;
- mostrar resultados de forma discreta y controlada;
- conservar el addon funcional aunque no haya otros addons EZO instalados.

El MVP no debe intentar resolver todavia comparativas completas de grupo, rankings, historial profundo ni UI persistente compleja.

## Alcance soporte Tank/Healer y Minors

La siguiente iteracion de soporte debe ampliar el addon sin mezclar responsabilidades:

- revisar tambien el flujo DD si se detecta que falta algun imprescindible;
- anadir catalogo y UI para buffs/debuffs relevantes de `Tank`;
- anadir catalogo y UI para buffs relevantes de `Healer`, separando los propios imprescindibles de la cobertura de grupo;
- anadir un panel vertical independiente de `Minor` configurables;
- conservar todos los paneles como HUD/HUD_UI, movibles con el desbloqueo global;
- reutilizar `modules/combat_summary.lua` para resumenes y tooltips.

La ventana principal especifica de cada rol debe contener solo imprescindibles de ese rol y, especialmente, efectos que dependen del propio jugador. No debe llenarse con buffs que normalmente aporta el grupo. Si un efecto es importante pero lo aporta otro jugador, debe vivir en un panel de grupo/minors/target o quedar como opcion configurada, no como falta principal del rol.

La implementacion debe separar el origen de cada senal:

- `player`: buffs propios del jugador;
- `group`: cobertura sobre `player` y `group1..groupN`;
- `target/boss`: debuffs o estados aplicados al objetivo/boss;
- `configured`: efectos opcionales que solo se evaluan si el usuario los activa en LAM.

Para `Tank`, esta iteracion se centra en efectos propios defensivos y debuffs de boss ligados a su labor directa. No debe exigir sets unicos, buffs de healer ni buffs genericos que normalmente aporta el grupo. Los debuffs de boss no se deben tratar como buffs propios.

Para `Healer`, esta iteracion se centra en imprescindibles que el healer debe aportar o mantener directamente y en HPS observado. La cobertura de grupo puede mostrarse en panel separado o tooltip, pero la alerta principal no debe convertirse en una lista de todos los buffs buenos que pueda recibir el grupo. No debe exigir sets unicos ni ultimates puntuales.

El panel vertical de `Minor` debe ser discreto y configurable:

- ventana propia, movible, por defecto alineada al lado derecho;
- visibilidad individual por efecto en LAM;
- pocos efectos visibles por defecto;
- lectura actual compacta y resumen al pasar el cursor si hay datos de combate.

Quedan fuera de esta iteracion:

- sets unicos de soporte como Pillager's Profit, Powerful Assault, Roaring Opportunist, Alkosh, Crimson Oath o Turning Tide;
- `Aggressive Horn`, `War Horn` y otros ultimates puntuales de raid timing;
- rankings, comparativas completas de grupo o sincronizacion entre clientes;
- automatizar recomendaciones de gear, CP o rotacion.

Los sets unicos de soporte se implementaran mas adelante en un panel independiente del rol. Ese panel debe detectar si el set esta equipado y solo entonces mostrar estado, uptime, cooldown o proc.

## Fuera de alcance inicial

- Keybindings.
- Intercepcion de input.
- Overlay persistente complejo.
- Menu lateral heredado de `EZOTools`.
- Dependencia directa de `EZOTools`.
- Parse de grupo completo.
- Sincronizacion entre clientes.
- Publicacion automatica de resultados.

## UI inicial

La configuracion seguira viviendo en LibAddonMenu.

Antes de crear una ventana propia, se debe confirmar el formato de lectura deseado:

- salida corta a chat bajo accion explicita;
- ventana minima de resultados;
- integracion opcional futura con una API pequena de `EZOTools`;
- otra superficie definida por el usuario.

El tracker live de Off Balance queda aceptado como UI runtime independiente porque responde a estado de objetivo/boss, no a resultados del medidor.

## Datos previstos

Los datos runtime deben mantenerse en memoria mientras no haya una razon clara para persistirlos.

SavedVariables solo deberia guardar configuracion, por ejemplo:

- idioma;
- perfil de rol;
- modo debug;
- posicion y bloqueo de avisos;
- preferencias de visibilidad cuando exista UI;
- formato de salida cuando exista reporte.

No guardar historiales de combate por defecto en el MVP.

## APIs pendientes de verificar

Antes de implementar medicion real, confirmar en UESP ESO Data o en el cliente:

- evento adecuado para cambios de estado de combate;
- evento adecuado para resultado de combate;
- campos reales disponibles para dano, sanacion, critico, objetivo y fuente;
- identificacion fiable del jugador local como fuente;
- restricciones o diferencias entre live y pts.

La implementacion no debe introducir nombres de eventos, constantes ni parametros no verificados.

## Criterio para empezar runtime

Se puede empezar a programar la medicion cuando esten confirmadas estas decisiones:

- el MVP medira combate local del jugador;
- la primera salida sera chat, ventana minima o ambas;
- las APIs anteriores estan verificadas;
- se acepta que el primer parse sea efimero y no persistente.
