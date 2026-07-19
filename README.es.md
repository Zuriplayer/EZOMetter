# EZOMetter

HUD de visibilidad de combate para *The Elder Scrolls Online*, centrado en comprobaciones propias por rol, seguimiento de estados relevantes para DD y resúmenes ligeros post-combate.

Prefer English? Read the [README in English](README.md).

Para soporte, errores y sugerencias, únete a Discord: https://discord.gg/ekw8zUAcRm


## Estado

EZOMetter está en beta pública. El addon es utilizable, pero varias métricas de combate dependen de eventos del cliente de ESO, del estado visible del objetivo y de librerías opcionales. Trata los valores como información práctica de apoyo, no como sustituto completo de un analizador de logs de combate.

Versión actual: **0.1.35**.

## Requisitos

- *The Elder Scrolls Online* para PC.
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) es obligatorio para el panel de configuración.
- Librerías opcionales:
  - `LibCombat` habilita los paneles de daño/curación observados, los resúmenes de estadísticas DD ponderados por daño, la atribución de daño durante Off Balance y el seguimiento preferente de stacks de Z'en.
  - `LibChatMessage` mejora la salida del addon en chat.
  - `LibDebugLogger` y `DebugLogViewer` se usan para logs técnicos y para la salida opcional del informe post-combate.
  - `EZOCore` proporciona acceso central desde Ajustes > EZO y control compartido de disposición de interfaz.

## Instalación

1. Descarga la última beta desde GitHub o clona este repositorio.
2. Copia la carpeta `EZOMetter` dentro de la carpeta de addons de ESO.
3. Instala y activa `LibAddonMenu-2.0`.
4. Activa `EZOMetter` desde la pantalla de complementos del juego.
5. Con EZOCore activo, configura el addon desde Ajustes > EZO > EZOMetter. Sin EZOCore, usa Ajustes > Addons > EZOMetter.

## Funciones principales

### Ajustes generales

- Localización en inglés y español, con detección automática del idioma del cliente o selección manual.
- Selección manual de perfil de rol: DD, Healer o Tank.
- Detección automática opcional de rol según armas equipadas y habilidades sloteadas. Usa una puntuación conservadora de tank/healer y vuelve a DD si no hay una señal clara.
- Opción global temporal para desbloquear el HUD y mover todos los paneles de EZOMetter en escenas normales de HUD/HUD UI. Con EZOCore, la misma superficie agregada participa en el control global o individual de disposición de la familia.
- Ajuste común de tamaño de texto HUD que escala las ventanas visuales de EZOMetter y su texto a la vez para mantener una distribución proporcional.
- Controles compartidos de apariencia HUD para opacidad del fondo, visibilidad del borde y color de borde/acento, aplicados de forma consistente a todos los paneles visuales.
- Informe post-combate opcional con fecha, personaje, tipo de contenido, zona, contexto de boss/trash, dificultad cuando está disponible y secciones de los trackers activos.
- Modo debug para salida técnica mediante `LibDebugLogger`/`DebugLogViewer` si están instalados.
- El panel de configuración usa cabeceras informativas moradas para la ayuda general de cada sección, mientras cada campo conserva su propio tooltip para el comportamiento específico.

### Avisos de buffs por rol

- Aviso movible para buffs propios requeridos que falten en el rol seleccionado.
- DD comprueba actualmente Major Brutality, Major Sorcery, Major Savagery, Major Prophecy y Banner Bearer cuando hay una habilidad de Banner sloteada.
- Healer comprueba actualmente Major Sorcery y Major Prophecy.
- Tank no tiene actualmente una lista de buffs propios requeridos.
- El aviso registra uptime del último combate para las comprobaciones requeridas cuando el informe de combate está activado.

### Tracker de Off Balance

- HUD movible separado para Off Balance en el objetivo actual o boss seguido.
- Distingue Off Balance real del cooldown/ciclo estimado de Off Balance.
- Mantiene un título explícito de Off Balance en el panel, con el temporizador activo/cooldown y los contadores del combate actual o del último debajo.
- El foco en boss puede seguir el estado de bosses conocidos aunque apartes brevemente la mirada.
- Visibilidad opcional solo en bosses y solo en combate.
- Colores configurables para estado listo, activo y cooldown.
- Pulso opcional cuando empieza Off Balance.
- Escaneo debug de buffs del objetivo actual y eventos de Off Balance.
- Detecta la estrella de Champion Point Exploiter cuando está disponible, comprueba si está equipada, lee los puntos invertidos y estima su valor a partir del daño hecho durante Off Balance real.
- La estimación de Exploiter se basa en daño; ESO no expone un evento nativo separado de "daño añadido por Exploiter".

### Tracker de Coral Riptide

- Panel movible separado para Coral Riptide.
- Detecta piezas equipadas de Coral Riptide o Perfected Coral Riptide mediante coincidencia de nombres de set y considera activo el bonus con 5 piezas.
- Estima el bonus de daño según la stamina faltante, hasta +600 al 50% de stamina o menos.
- Muestra bandas de estado: cap, OK, medio, bajo, malo e inactivo.
- Tamaño, visibilidad solo DD y visibilidad solo en combate configurables.
- Escaneo debug opcional de equipo para nombres e IDs de set.
- El resumen del último combate incluye bonus medio estimado y tiempo en bandas útiles, malas o inactivas.

### Tracker de Rugido de Alkosh

- Panel movible separado para Rugido de Alkosh, desactivado por defecto.
- Detecta Rugido de Alkosh equipado mediante una lectura de itemLink canónico del set, con coincidencia por slots/nombre como respaldo.
- Se oculta automáticamente por debajo de tres piezas equipadas de Rugido de Alkosh; la edición de HUD y la previsualización siguen disponibles.
- Sigue Alkosh por abilityId, usando Line Breaker y el aura del Trial Dummy como fuentes principales de timing de 10 segundos.
- Usa los IDs de penetración usados por CombatMetrics como señales observadas de proc/cálculo, no como reloj principal de uptime.
- Muestra estado equipado, último proc en combate, duración restante limitada a los 10 segundos del set, eficiencia frente al uptime posible observado y objetivo afectado cuando ESO expone un objetivo legible.
- Mantiene visible la última eficiencia válida después del combate hasta que nuevos datos de combate la sustituyen; el proc vivo y el tiempo restante se reinician a estado neutro fuera de combate.
- Ofrece modos Off, Avisar y Bloqueo visual. Bloqueo visual es solo un aviso, aparece únicamente cuando hay una sinergia visible y no intercepta el input de sinergias.
- Registro debug opcional de eventos.
- El tooltip/informe del último combate incluye eficiencia de Alkosh, tiempo posible observado y los últimos datos observados de objetivo/proc.

### Tracker de Reparación de Z'en

- Panel movible separado de Z'en para configuraciones de soporte DPS/healer.
- El modo Auto muestra el panel si llevas al menos 3 piezas; On lo fuerza visible para pruebas.
- Usa `LibCombat` como fuente preferente de stacks de Z'en cuando está disponible, con un contador interno de DoTs propios como fallback.
- Cuenta tus efectos propios de daño en el tiempo sobre el objetivo seguido como stacks potenciales, incluyendo visibilidad fallback con menos de 5 piezas.
- Sigue Touch de Z'en por abilityId y solo muestra valor efectivo cuando el Touch de 5 piezas está activo.
- Muestra piezas, stacks potenciales, valor efectivo, tiempo restante de Touch, objetivo, fuente de stacks y una barra de stacks.
- Registro debug opcional de eventos.
- El tooltip/informe del último combate incluye uptime de Touch, medias potencial/efectiva, tiempo en cap y datos de objetivo.

### Estadísticas DD

- Panel movible separado para estadísticas DD:
  - mayor valor entre Weapon Damage y Spell Damage,
  - probabilidad de crítico,
  - penetración,
  - daño crítico.
- Muestra valores propios, efectivos y máximos calculados cuando procede.
- La penetración efectiva y el daño crítico efectivo incluyen supuestos configurados y debuffs detectados en el objetivo.
- Umbrales configurables de daño ofensivo, crítico, penetración propia, daño crítico, resistencia del objetivo, Crusher, Alkosh y Tremorscale.
- Visibilidad solo DD y visibilidad solo en combate configurables.
- Usa la primera distribución de ventana EZO compartida con varias columnas, ampliando los valores efectivo y máximo para mejorar la legibilidad.
- El tooltip/informe del último combate incluye resúmenes por tiempo y ponderados por daño cuando hay datos.

### Daño y curación observados

- Paneles opcionales mediante `LibCombat` para daño y curación salientes observados.
- Daño observado muestra DPS actual, DPS medio, proporción observada del grupo y daño/proporción en boss cuando está disponible.
- Curación observada muestra HPS actual, HPS medio y proporción de curación observada del grupo cuando está disponible.
- Ambos paneles admiten visibilidad solo en combate y visibilidad por rol.
- Los totales de grupo son valores observados por el cliente y dependen de los eventos recibidos localmente.

### Ayuda para Fatecarver

- Barra horizontal de canalización para Fatecarver, Exhausting Fatecarver y Pragmatic Fatecarver del Arcanista.
- Detecta Fatecarver en cualquiera de las dos barras de acción.
- Sigue el tiempo de canalización activo mediante eventos de combate y efectos del jugador.
- Ventana de aviso para cancelar configurable en milisegundos.
- El resumen del último combate informa lanzamientos, canalizaciones completadas, cancelaciones OK, cortes tempranos y tiempos de corte temprano.

## Límites de seguridad

- EZOMetter no automatiza combate, rotaciones, uso de habilidades, movimiento, selección de objetivos, bloqueo, cambios de equipo, cambios de Champion Points ni keybinds.
- No intercepta input global.
- No reemplaza elementos de la interfaz original del juego.
- Los elementos HUD están diseñados para aparecer solo en escenas normales de HUD/HUD UI y no en menús como inventario, mapa, crafting, Champion Points o Tales of Tribute.
- El daño/curación de grupo observados y el valor de Exploiter son estimaciones basadas en eventos disponibles para el cliente.
- El modo Bloqueo visual de Alkosh es solo informativo; EZOMetter no bloquea, consume ni cancela el input de sinergias.
- El addon incluye scripts de publicación en Discord para mantenimiento del proyecto, pero no se publica nada en Discord sin autorización explícita.

## Pruebas recomendadas

Antes de cerrar cambios de código:

```powershell
.\tools\bump-version.ps1 -Check
git diff --check
```

Comprobaciones recomendadas dentro del juego:

- `/reloadui` con paneles bloqueados y desbloqueados.
- Tamaño común de texto HUD en valores mínimo, por defecto y máximo, comprobando que los paneles escalan junto con su texto y siguen siendo movibles.
- Apertura del panel dentro de Ajustes > EZO cuando EZOCore está activo, sin una entrada duplicada en la lista estándar de Addons.
- Apertura del fallback independiente de LibAddonMenu cuando EZOCore no está disponible.
- Tooltips de ayuda general por sección y ayuda específica por campo en el panel de configuración.
- Selección de idioma inglés/español y modo automático de idioma.
- Visibilidad del HUD en combate, fuera de combate, inventario, mapa, crafting, Champion Points, Tales of Tribute y configuración de addons.
- Avisos de buffs DD con y sin los buffs requeridos.
- Aviso de Banner Bearer cuando hay una habilidad de Banner sloteada y cuando no hay ninguna.
- Off Balance en dummy/boss, incluyendo tiempo activo real, cooldown/ciclo e informe de Exploiter.
- Coral Riptide con menos de 5 piezas, con 5 piezas y con distintos niveles de stamina.
- Rugido de Alkosh con 0-2 piezas (oculto), con 3-4 piezas (visible sin el bonus de 5 piezas), con 5 piezas, modo Avisar, modo Bloqueo visual, debuff de Trial Dummy y objetivo normal cuando esté disponible.
- Reparación de Z'en con 3-4 piezas, con 5 piezas, varios DoTs, refrescos de Touch, cambios de objetivo, cambios de barra y con/sin `LibCombat`.
- Valores propios/efectivos/máximos de Estadísticas DD y tooltip después del combate.
- Daño/curación observados con `LibCombat` instalado y sin `LibCombat`.
- Inicio, finalización, corte temprano y color de aviso de Fatecarver.

## Reportar problemas

Incluye si es posible:

- Versión de EZOMetter.
- Idioma del cliente de ESO.
- Librerías opcionales instaladas.
- Rol/perfil del personaje.
- Pasos para reproducir el problema.
- Capturas o salida de DebugLogViewer cuando sea relevante.

Soporte, errores y sugerencias: https://discord.gg/ekw8zUAcRm
## Licencia

MIT. Ver [LICENSE](LICENSE).

Desarrollado y mantenido por Zuriplayer.
