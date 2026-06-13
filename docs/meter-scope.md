# Meter Scope

Este documento fija una propuesta de alcance inicial para que `EZOMetter` pueda avanzar sin convertirse en una copia grande de otros medidores.

## Objetivo del MVP

La primera iteracion debe orientarse a DD y empezar por senales locales seguras:

- avisar cuando falten buffs propios basicos de DD;
- mostrar Off Balance en un tracker separado de objetivo/boss, sin mezclarlo con buffs propios;
- preparar perfiles de rol para `DD`, `Healer` y `Tank`;
- dejar `Healer` y `Tank` sin checklist activo hasta definir sus metricas.

La primera iteracion de medidor de combate debe ser un medidor local ligero:

- medir sesiones de combate del jugador local;
- registrar dano realizado, sanacion realizada y duracion de sesion;
- calcular DPS y HPS basicos a partir de totales locales;
- mostrar resultados de forma discreta y controlada;
- conservar el addon funcional aunque no haya otros addons EZO instalados.

El MVP no debe intentar resolver todavia comparativas completas de grupo, rankings, historial profundo ni UI persistente compleja.

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
