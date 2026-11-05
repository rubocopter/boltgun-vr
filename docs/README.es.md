# Boltgun VR

Mod de **Warhammer 40,000: Boltgun** para PCVR mediante UEVR/OpenXR, desarrollado
con **PS VR2 Sense**. Incluye controles adaptados, rueda de armas y modelos 3D
opcionales para diez armas de fuego y la espada sierra.

## Estado actual

El candidato instalado localmente el **5 de noviembre de 2026** es el **arsenal
revisión 27 / chainsword paquete 12**, con perfil Sense v7. No es una nueva
versión publicada. Sus indicadores globales de validación en VR siguen en falso.

| Función | Estado real |
| --- | --- |
| Retícula del propio juego en el punto de apuntado | La revisión 26 colocó la mira en el mundo, pero el vídeo muestra pérdidas intermitentes. La 27 admite impactos válidos muy cerca del cañón y evita la mira centrada si el disparo parte dentro de un obstáculo. Pendiente de comprobar en VR. |
| Manos blindadas azules, negras y doradas | El usuario aprobó el encaje derecho. El guante izquierdo gira sobre el mango de la espada. Ambos conjuntos se centran en el agarre de su mando. Falta comprobar el alcance y la orientación en visor. |
| Halo rojo al recibir daño | Aspecto aprobado por el mantenedor en el candidato 24; esos archivos se conservan en el candidato 26. Quedan transiciones y recuperación por comprobar. |
| Menús estables | Estabilidad comunicada por el mantenedor. El puente para apuntar, pasar por encima y pulsar con un mando no está implementado. |
| Disparos y efectos | Mejor alineación comunicada y algunos fogonazos corregidos; siguen efectos desviados. No se considera resuelto para todas las armas. |
| Daño físico de la espada | Adaptador conectado, pero no se ha demostrado daño adicional. Exige mantener el gatillo izquierdo; los últimos diagnósticos inspeccionados no avanzaban de esa condición. Los ataques L2 originales siguen activos. |
| Volver al menú | La sesión registrada de la revisión 26 terminó normalmente. Falta repetir la transición de forma controlada. |
| Muerte | Se ocultan los antiguos sprites de brazos y también las manos 3D. No existe una presentación de manos/brazos 3D al morir. |

No hay recargas físicas, animación de dedos ni brazos articulados completos.
El contacto o gesto de espada con el gatillo izquierdo suelto no activa el
adaptador. El apuntado desde el arma y el modo a dos manos son opciones
experimentales desactivadas por defecto; los rayos de Volkite/Gravgun tienen
una activación independiente.

La versión publicada **v1.0.2** conserva el runtime de **revisión 20 / paquete 5**,
validado en las partidas con PS VR2 Sense del 16 de octubre. Su cambio de
instalador permite continuar si SteamVR genera un SystemButton incompatible,
conservando ese binding y dejando Options/Create para asignar manualmente.
Esa validación histórica no certifica los cambios nuevos ni todo el DLC/otros
mandos. El [paquete publicado](https://github.com/rubocopter/boltgun-vr/releases/latest)
no incluye el juego ni UEVR.

## Instalación y documentación

Consulta la [instalación guiada](INSTALACION-FACIL.es.md) o la
[guía avanzada y restauración](INSTALL.md). La rueda se usa manteniendo R3,
inclinando el stick derecho y soltando; vuelve al centro para cancelar.
El instalador verifica hashes y conserva calibraciones compatibles; no inyecta
automáticamente. Necesitas el juego, UEVR y un entorno PCVR/OpenXR propios.

| Jugadores | Desarrollo y seguimiento |
| --- | --- |
| [Controles Sense](CONTROLS.md) | [Estado y evidencia](STATUS.md) |
| [Manos](HANDS.md) · [Daño](COMFORT.md) | [Pendiente de probar e implementar](PENDING.md) |
| [Solución de problemas](TROUBLESHOOTING.md) | [Arquitectura](ARCHITECTURE.md) · [Arsenal](ARSENAL.md) |
| [Copias y recuperación](REINSTALL.md) | [Compilación y pruebas](BUILD.md) |
| [Retícula](RETICLE.md) · [Menús](MENU.md) | [Créditos y licencias](SOURCE-AND-NOTICES.md) |

Proyecto de aficionados sin afiliación con los titulares del juego, UEVR o los
fabricantes de visores. Código original: **GPL-3.0-or-later**. Espada de Kaiser-E:
**CC BY 4.0**. Guantelete de Grab3D: **CC0**. Se conservan sus avisos; no se
redistribuyen recursos extraídos del juego. Véanse [licencia](../LICENSE) y
[términos de reutilización](../COPYRIGHT_AND_REUSE.md).
