# Future Integration With EZOTools

`EZOMetter` debe funcionar como addon independiente.

Una integracion futura con `EZOTools` solo debe hacerse si aporta valor claro y sin convertir `EZOTools` en dependencia obligatoria.

Patron permitido:

```lua
if EZOTools and type(EZOTools.RegisterExternalTool) == "function" then
    EZOTools.RegisterExternalTool("EZOMetter", {})
end
```

Antes de anadir integracion:

- confirmar que la API existe;
- mantener `OptionalDependsOn` si se necesita orden de carga blando;
- documentar el contrato en este archivo;
- comprobar que `EZOMetter` sigue funcionando sin `EZOTools`.
