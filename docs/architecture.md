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
modules/saved_vars.lua
modules/menu.lua
```

## Pendiente antes de implementar medicion

- Confirmar alcance exacto: combate, recursos, grupo, encounter, parse local u otro uso.
- Verificar APIs reales de ESO en UESP o cliente.
- Definir si la UI sera LAM, ventana propia, chat controlado o integracion opcional con `EZOTools`.
- Definir SavedVariables necesarias.
