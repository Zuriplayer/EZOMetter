# EZOMetter

HUD de visibilidad de combate para *The Elder Scrolls Online*, centrado en comprobaciones propias por rol, seguimiento de estados relevantes para DD y resúmenes ligeros post-combate.

Prefer English? Read the [README in English](README.md).

Para soporte, errores y sugerencias, únete a Discord: https://discord.gg/ekw8zUAcRm


## Estado

EZOMetter está en beta pública. El addon es utilizable, pero varias métricas de combate dependen de eventos del cliente de ESO, del estado visible del objetivo y de librerías opcionales. Trata los valores como información práctica de apoyo, no como sustituto completo de un analizador de logs de combate.

Versión actual: **0.1.74**.

## Requisitos

- *The Elder Scrolls Online* para PC (actualización 51, API de addons `101051`).
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
- Los tooltips del último combate se dibujan sobre los paneles HUD de EZOMetter, incluida la superficie de barras de habilidades personalizadas.
- Informe post-combate opcional con fecha, personaje, tipo de contenido, zona, contexto de boss/trash, dificultad cuando está disponible y una unica entrada `Info` consolidada por combate. Cada tracker tiene su propio selector de inclusion, habilitado por defecto; se omiten las secciones desactivadas o no relevantes, y los trackers de sets requieren que su bono de 5 piezas haya estado disponible durante el encuentro.
- Modo debug para salida técnica mediante `LibDebugLogger`/`DebugLogViewer` si están instalados.
- El panel de configuración usa cabeceras informativas moradas para la ayuda general de cada sección, mientras cada campo conserva su propio tooltip para el comportamiento específico.
- Los ajustes con controles dependientes se actualizan inmediatamente al cambiar su valor maestro, tanto en Ajustes > EZO como en el panel independiente de LibAddonMenu; no es necesario reabrir Ajustes ni usar `/reloadui`.

### Avisos de buffs por rol

- Aviso movible para buffs propios requeridos que falten en el rol seleccionado.
- DD comprueba actualmente Major Brutality y Major Savagery, además de Banner Bearer cuando hay una habilidad de Banner sloteada. Banner Bearer usa el estado activo de la propia barra de acciones, por lo que el Banner de un aliado no satisface la comprobación.
- Healer comprueba actualmente Major Brutality y Major Savagery. Mientras Spaulder of Ruin esté equipado, también muestra el icono de la hombrera equipada hasta que Aura of Pride esté activa. Aura of Pride se sigue mediante su evento nativo de combate Spaulders of Ruin, no se infiere a partir de crouch/Prowl ni de la lista normal de buffs del jugador. No se exige sin ese mítico.
- En U51, Major Brutality cubre el daño físico y mágico (`61665`), y Major Savagery ambas probabilidades de crítico (`61667`). Se han retirado las comprobaciones obsoletas de Major Sorcery y Major Prophecy.
- Tank no tiene actualmente una lista de buffs propios requeridos.
- El aviso registra uptime del último combate para las comprobaciones requeridas cuando el informe de combate está activado.

### Tracker de Off Balance

- HUD movible separado para Off Balance en el objetivo actual o boss seguido.
- Distingue Off Balance real del cooldown/ciclo estimado de Off Balance.
- Mantiene un título explícito de Off Balance en el panel, con el temporizador activo/cooldown y los contadores del combate actual o del último debajo.
- El foco en boss puede seguir el estado de bosses conocidos aunque apartes brevemente la mirada.
- Selector de visualización para desactivar Off Balance, mostrar solo el panel, mostrar solo el icono independiente o mostrar panel e icono.
- El panel no tiene filtros de visibilidad: si su superficie está seleccionada en el modo de visualización, se muestra siempre.
- El icono flotante tiene tres filtros exclusivos que se combinan: mostrar solo en combate, mostrar solo en bosses y mostrar solo si la estrella de Puntos de Campeón Explotador está equipada.
- El icono independiente empieza a 50 px y sigue siendo ajustable entre 10 y 100 px.
- La superficie seleccionada de Off Balance sigue los filtros de combate, boss, perfil de rol y CP Explotador. Si la visibilidad solo en combate y solo en bosses están desactivadas, las superficies seleccionadas permanecen visibles en estado listo fuera de combate.
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

### Tracker de Centinela de las Tierras Altas (Highland Sentinel)

- Panel movible separado para Highland Sentinel.
- Detecta piezas equipadas mediante coincidencia de nombres de set y considera activo el bonus con 5 piezas.
- Lee los stacks de "Ojo del centinela" para calcular y mostrar en tiempo real el bono de probabilidad de crítico.
- Tamaño, visibilidad solo DD y visibilidad solo en combate configurables.
- Informa de stacks medios, bono crítico medio estimado, uptime activo y uptime a stacks máximos del último combate.
- Registro debug opcional para verificar eventos de stacks e IDs de habilidad.

### Tracker de Azureblight Reaper

- Panel movible separado con el icono de Blight Seed, número bruto de cargas, segundos restantes y barra de duración.
- Lee Blight Seed (`abilityId 126631`) directamente en el objetivo bajo la retícula y en `boss1` a `boss6`.
- Conserva el debuff observado al cambiar de barra; la barra activa nunca reinicia ni oculta una lectura directa válida.
- Muestra las cargas sin asumir un máximo `/20`, porque el umbral de explosión cambia cuando hay más usuarios de Azureblight.
- No estima cargas ausentes, no atribuye cargas a DoTs concretos ni calcula el daño de Azureblight.
- Tamaño y visibilidad solo en combate configurables, con previsualización de cinco segundos y diagnóstico opcional de eventos directos.

### Tracker de Rugido de Alkosh

- Panel movible separado para Rugido de Alkosh, desactivado por defecto.
- Detecta Rugido de Alkosh equipado mediante una lectura de itemLink canónico del set, con coincidencia por slots/nombre como respaldo.
- Se oculta automáticamente por debajo de tres piezas equipadas de Rugido de Alkosh; la edición de HUD y la previsualización siguen disponibles.
- Sigue Alkosh por abilityId y usa los `beginTime`/`endTime` directos del efecto Line Breaker como reloj autoritativo de 10 segundos. Solo acepta el aura del Trial Dummy cuando ESO la atribuye al jugador.
- Mantiene los IDs de penetración usados por CombatMetrics como señales observadas de cálculo; no pueden iniciar ni reiniciar el reloj del ciclo.
- Usa `EVENT_SYNERGY_ABILITY_CHANGED` y la API de lista de sinergias actual para observar cada oferta utilizable con su nombre y abilityId, con fallback al aviso actual en versiones anteriores de la API.
- Permite configurar el inicio y final de la ventana de activación. La barra muestra el tiempo restante de Line Breaker observado directamente, baja hasta cero al expirar y cambia entre Espera, Ventana, Activa ahora, Tarde y Expirado.
- Correlaciona cada proc con la oferta principal que acaba de desaparecer. Los procs sin coincidencia se muestran como sinergia desconocida sin inventar el tipo.
- Cuenta por combate y tipo de sinergia las ofertas, activaciones dentro/fuera de la ventana y ofertas observadas en la ventana que desaparecen sin un proc correlacionado.
- Mientras la ventana de activación está abierta, el panel muestra si hay una sinergia utilizable en ese momento y el número acumulado de ofertas detectadas dentro de las ventanas configuradas.
- Calcula el uptime de combate como tiempo activo de Line-Breaker dividido entre todo el tiempo de combate.
- Muestra la eficiencia de ofertas como tiempo activo real dividido entre el uptime simulado internamente que permitían las sinergias utilizables recibidas realmente.
- Mantiene las últimas métricas y contadores por tipo en el tooltip/informe hasta que otro combate los sustituye.
- Ofrece modos Off, Monitor y Asistente de ciclo. El asistente es únicamente visual y nunca intercepta ni activa sinergias.
- Muestra el aviso independiente de activación con estilo rojo/naranja de warning para la primera sinergia del combate, las ofertas dentro de la ventana configurada, la primera oferta tardía cuando no apareció ninguna sinergia durante esa ventana y cualquier oferta utilizable después de expirar Line Breaker.
- Registro debug opcional del timing directo del efecto y de las ofertas de sinergia.
- El tooltip/informe del último combate incluye uptime real, eficiencia de ofertas, datos de objetivo/proc y el desglose por sinergia.

### Tracker de Reparación de Z'en

- Panel movible separado de Z'en para configuraciones de soporte DPS/healer.
- El modo Auto muestra el panel si llevas al menos 3 piezas; On lo fuerza visible para pruebas.
- Usa `LibCombat` como fuente preferente de stacks de Z'en cuando está disponible, con un contador interno de DoTs propios como fallback.
- Cuenta tus efectos propios de daño en el tiempo sobre el objetivo seguido como stacks potenciales, incluyendo visibilidad fallback con menos de 5 piezas.
- Sigue Touch de Z'en directamente por abilityId y mantiene su valor efectivo durante la duración detectada de Touch aunque un cambio de arma reduzca el número de piezas de Z'en equipadas en ese momento.
- Rechaza la pseudo-unidad `offline` de ESO como nombre de objetivo, prioriza objetivos con Touch/DoTs activos y vuelve al contador interno de DoTs en cuanto LibCombat informa que Touch ha terminado.
- Muestra piezas, stacks potenciales, valor efectivo, tiempo restante de Touch, objetivo, fuente de stacks y una barra de stacks.
- Muestra un icono propio de Touch proyectado desde el mundo sobre el enemigo coincidente mientras permanece bajo la retícula, siguiendo el patrón de renderizado establecido por `EZOCustomSupportIcons`. No utiliza marcadores nativos de grupo y se oculta de forma segura cuando ESO deja de exponer ese enemigo mediante un `unitTag` estable.
- Diagnóstico opcional que registra para comparar impactos de ataques ligeros/pesados propios y una única entrada de equipo estable por cambio de barra, pero solo correlaciona la aplicación inicial de Touch con un ataque ligero al mismo objetivo y su estado de 5 piezas. La breve ventana diferida admite que ESO informe Touch poco antes del impacto ligero y nunca atribuye un ataque pesado anterior.
- Incluye escaneo manual del objetivo bajo la retícula para Touch/DoTs propios y un botón directo para abrir DebugLogViewer. No utiliza marcadores nativos de grupo.
- El tooltip/informe del último combate incluye uptime de Touch, medias potencial/efectiva, tiempo en cap, datos de objetivo y el número de piezas de aplicación/máximo junto con la fuente de stacks observada durante el combate, no solo la barra final.

### Estadísticas DD

- Panel movible separado para estadísticas DD:
  - mayor valor entre Weapon Damage y Spell Damage,
  - probabilidad de crítico,
  - penetración,
  - daño crítico.
- La columna Own muestra las estadísticas instantáneas del jugador en vivo; las columnas Effective y Max Calc reflejan tu último combate. Si aún no hay datos de combate, Effective iguala a Own y Max Calc queda vacío.
- La penetración efectiva y el daño crítico efectivo incluyen supuestos configurados y debuffs detectados en el objetivo.
- Umbrales configurables de daño ofensivo, crítico, penetración propia, daño crítico, resistencia del objetivo, Crusher, Alkosh y Tremorscale.
- Visibilidad solo DD y visibilidad solo en combate configurables.
- Usa la primera distribución de ventana EZO compartida con varias columnas, ampliando los valores efectivo y máximo para mejorar la legibilidad.
- El tooltip/informe del último combate incluye resúmenes por tiempo y ponderados por daño cuando hay datos.

### Daño y curación observados

- Paneles opcionales mediante `LibCombat` para daño y curación salientes observados.
- Daño observado muestra DPS actual, DPS medio, proporción observada del grupo y daño/proporción en boss cuando está disponible.
- Curación observada muestra HPS actual, HPS medio y proporción de curación observada del grupo cuando está disponible.
- Curación observada puede mantenerse visible también con los perfiles Tank y DD.
- Ambos paneles admiten diseño compacto, con un icono sutil de DPS/Healer sobre los valores y distinto tinte de texto, además de visibilidad solo en combate y por rol.
- Los totales de grupo son valores observados por el cliente y dependen de los eventos recibidos localmente.

### Ayuda para Fatecarver

- Sus ajustes están agrupados bajo una cabecera propia de Fatecarver dentro del submenú Habilidades.
- Barra horizontal de canalización para Fatecarver, Exhausting Fatecarver y Pragmatic Fatecarver del Arcanista.
- Detecta Fatecarver en cualquiera de las dos barras de acción.
- Sigue el tiempo de canalización activo mediante eventos de combate y efectos del jugador.
- Ventana de aviso para cancelar configurable en milisegundos.
- El resumen del último combate informa lanzamientos, canalizaciones completadas, cancelaciones OK, cortes tempranos y tiempos de corte temprano.

### Ayuda para Magma Fist

- Sus ajustes están agrupados bajo una cabecera propia de Magma Fist dentro del submenú Habilidades.
- Icono independiente y movible de Magma Fist que permanece visible en escenas normales del HUD siempre que la habilidad esté sloteada, también fuera de combate, con un badge de `0-3` acumulaciones de Heat Shock.
- Lee directamente las acumulaciones y el final de Heat Shock (`abilityId 134340`) aplicado por el jugador mediante eventos de efecto.
- Un único contador centrado muestra el tiempo restante de Heat Shock leído directamente, para que su caducidad sea visible mientras se acumulan o mantienen las 3 cargas.
- Leyenda del borde: gris con menos de 3 cargas, ámbar siempre que haya que mantener o usar las 3 cargas, verde durante la ventana potenciada de 6 segundos y rojo durante los últimos 1,5 segundos de Heat Shock o de esa ventana. El borde exterior usa un trazo más grueso y visible.
- Los datos públicos del cliente identifican actualmente Heat Shock y Magma Fist, pero no un abilityId separado para el buff personal de 6 segundos. Por ello, EZOMetter deriva la ventana de un evento directo gained/updated de Heat Shock, deduplicado, cuando el objetivo ya estaba observado en 3 acumulaciones, y la consume con el siguiente impacto observado de Magma Fist o renovación de Heat Shock.
- Usa directamente la expiración de Heat Shock cuando está disponible. Si el evento no incluye un `endTime` válido, conserva esa observación directa de stacks durante la duración documentada de 7 segundos.
- Incluye tamaño configurable, posición mediante el modo de disposición del HUD, previsualización simulada y diagnóstico opcional de eventos.

## Límites de seguridad

- Al desbloquear el HUD, cada panel compatible se mueve con el botón derecho;
  el clic izquierdo mantiene su comportamiento y el modo no intercepta el
  input global.
- EZOMetter no automatiza combate, rotaciones, uso de habilidades, movimiento, selección de objetivos, bloqueo, cambios de equipo, cambios de Champion Points ni keybinds.
- No intercepta input global.
- No reemplaza elementos de la interfaz original del juego.
- Los elementos HUD están diseñados para aparecer solo en escenas normales de HUD/HUD UI y no en menús como inventario, mapa, crafting, Champion Points o Tales of Tribute.
- El daño/curación de grupo observados y el valor de Exploiter son estimaciones basadas en eventos disponibles para el cliente.
- La ventana de 6 segundos de Magma Fist es un aviso derivado de eventos hasta confirmar en el cliente un ID de efecto propio; las acumulaciones y la expiración de Heat Shock sí son lecturas directas.
- El Asistente de ciclo de Alkosh es solo informativo; EZOMetter observa la lista de sinergias disponibles, pero no bloquea, consume, activa ni cancela su input.
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
- Avisos de buffs de rol Healer con Spaulder of Ruin equipado: Aura of Pride aparece mientras está inactiva, desaparece cuando se observa su efecto nativo y no aparece tras desequipar el mítico.
- En PvP, activa una habilidad de escribanía que otorgue Major Savagery: debe desaparecer su único aviso mientras la hoja de personaje muestra ambas bonificaciones de crítico. Comprueba por separado Major Brutality frente a ambas bonificaciones de daño.
- Banner Bearer con la habilidad sloteada: lanza tu propio Banner y confirma que desaparece el aviso; permanece en el Banner de un aliado sin lanzar el tuyo y confirma que el aviso continúa activo.
- Off Balance en dummy/boss, incluyendo tiempo activo real, cooldown/ciclo e informe de Exploiter.
- Coral Riptide con menos de 5 piezas, con 5 piezas y con distintos niveles de stamina.
- Azureblight Reaper en la barra principal, DoTs de la barra secundaria haciendo ticks después de ambos cambios de barra, cambios de objetivo, refrescos del efecto y uno o varios usuarios del set.
- Rugido de Alkosh con 0-2 piezas (oculto), con 3-4 piezas (visible sin el bonus de 5 piezas), con 5 piezas, modos Monitor/Asistente, actualizaciones repetidas de un mismo proc, activaciones antes/dentro/después de la ventana, una sinergia disponible tras expirar, ofertas perdidas dentro de la ventana, debuff de Trial Dummy y objetivo normal cuando esté disponible.
- Reparación de Z'en con 3-4 piezas y con 5 piezas; ataques ligeros y pesados desde ambas barras; varios DoTs; aparición, renovación y desaparición de Touch; cambios de objetivo; cambios de barra; escaneos manuales de retícula; y con/sin `LibCombat`. Comprueba que solo un ataque ligero con 5 piezas resuelve la correlación inicial de Touch, también cuando Touch precede al impacto; los ataques pesados deben quedar como no candidatos.
- Valores propios/efectivos/máximos de Estadísticas DD y tooltip después del combate.
- Daño/curación observados con `LibCombat` instalado y sin `LibCombat`.
- Inicio, finalización, corte temprano y color de aviso de Fatecarver.
- Lanzamientos 1-3 de Magma Fist con la cuenta atrás de Heat Shock, el siguiente golpe a máximo abriendo la cuenta central de 6 segundos, el lanzamiento posterior consumiéndola, ambas caducidades, cambios de objetivo y ambas barras de armas.

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
