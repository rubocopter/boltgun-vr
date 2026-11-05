# Boltgun VR

Mod de **Warhammer 40,000: Boltgun** para PCVR mediante UEVR/OpenXR, desarrollado
con **PS VR2 Sense**. Incluye controles adaptados, rueda de armas y modelos 3D
opcionales para diez armas de fuego y la espada sierra.

## Estado actual

La versión **v1.1.0** incluye el arsenal 3D revisión **27**, la espada sierra
paquete **12** y el perfil Sense **v7**. En la sesión del 5 de noviembre, el
mantenedor confirmó en visor el agarre de ambas manos y el alcance de las armas.

| Función | Estado real |
| --- | --- |
| Retícula del propio juego en el punto de apuntado | Sigue la trayectoria nominal de disparo en armas compatibles. Admite impactos válidos cerca del cañón. Quedan por comprobar la visibilidad en ambos ojos y la recuperación en las transiciones. |
| Manos blindadas azules, negras y doradas | Ambas manos se ajustan al agarre de su arma y a la posición del mando. Se confirmaron la colocación y la distancia con PS VR2 Sense. |
| Halo rojo al recibir daño | Aspecto aprobado por el mantenedor en el candidato 24; esos archivos se conservan en v1.1.0. Quedan transiciones y recuperación por comprobar. |
| Menús estables | Estabilidad comunicada por el mantenedor. El puente para apuntar, pasar por encima y pulsar con un mando no está implementado. |
| Disparos y efectos | El **cañón grav** y el **arcabuz volkite** fueron las únicas armas que se desviaron en la última partida. Mejoraron algunos fogonazos en pruebas anteriores. Queda por comprobar el origen de cada efecto por separado. |
| Daño físico de la espada | Adaptador conectado, pero no se ha demostrado daño adicional. Exige mantener el gatillo izquierdo; los últimos diagnósticos inspeccionados no avanzaban de esa condición. Los ataques L2 originales siguen activos. |
| Volver al menú | La sesión registrada de la revisión 26 terminó normalmente. Falta repetir la transición de forma controlada. |
| Muerte | Se ocultan los antiguos sprites de brazos y también las manos 3D. No existe una presentación de manos/brazos 3D al morir. |

No hay recargas físicas, animación de dedos ni brazos articulados completos.
El contacto o gesto de espada con el gatillo izquierdo suelto no activa el
adaptador. El apuntado desde el arma y el modo a dos manos son opciones
experimentales desactivadas por defecto; los rayos de Volkite/Gravgun tienen
una activación independiente.

La validación cubre las funciones observadas con PS VR2 Sense. Quedan
pendientes el daño por contacto, las transiciones repetidas y la cobertura
completa de variantes, DLC y otros mandos. El
[paquete publicado](https://github.com/rubocopter/boltgun-vr/releases/latest)
requiere una instalación propia del juego y UEVR.

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
