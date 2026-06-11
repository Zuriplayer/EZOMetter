# Discord

`EZOMetter` queda preparado con la misma estructura de secretos que los addons EZO recientes.

Los nombres de secretos estan en `ezo-addon.json`:

- `EZO_CODEX_DOWNLOADS`
- `EZO_CODEX_RELEASES`
- `EZO_CODEX_STATUS`
- `EZO_CODEX_ANNOUNCER`
- `EZO_CODEX_BETA_BUILDS`
- `CODEX_LOG`
- `EZO_CODEX_BUG_REPORTS`

## Regla operativa

No se publica nada en Discord sin una orden explicita.

Los workflows y scripts deben poder ejecutarse en modo dry-run. En GitHub Actions, publicar requiere introducir `PUBLISH` en el input de confirmacion.
