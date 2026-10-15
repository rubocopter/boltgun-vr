# Boltgun VR

Mod de **Warhammer 40,000: Boltgun** para PCVR basado en UEVR/OpenXR, desarrollado con **PS VR2 Sense**. Añade controles adaptados, una rueda para elegir grupos de armas y, como opciones experimentales, modelos 3D de las diez armas de fuego y una espada sierra que sigue la mano izquierda.

**Estado: pre-alfa.** El código actual corresponde al **perfil Sense v7, arsenal 3D revisión 17 y chainsword paquete 4**. Se han probado en visor las mecánicas básicas, el Bolter y el seguimiento de la espada en revisiones anteriores. La revisión 17 y los efectos de disparo actuales todavía necesitan una nueva prueba real.

Está publicada la **versión 1.0.0** en [GitHub Releases](https://github.com/rubocopter/boltgun-vr/releases/latest), con un ZIP que incluye el menú en inglés y los plugins nativos compilados. No incluye el juego ni UEVR. El código fuente y las herramientas de compilación están en este repositorio.

## Qué puedes probar

- Movimiento orientado con la cabeza, giro configurable y controles Sense.
- Rueda de armas: mantén R3, inclina el stick derecho y suelta para elegir; vuelve al centro para cancelar.
- Armas 3D opcionales: usan mallas del juego instalado. Dos requieren el DLC. El prototipo restaura el arma original cuando no puede cargar una malla.
- Espada sierra 3D opcional en la mano izquierda, conservando ataques y daño originales.
- Retroceso visual y vibración en disparos interceptados, todavía sujetos a validación; ciertos efectos, rayos e impactos conservan las rutas originales.

No hay recargas físicas ni daño causado por gestos con la espada. El modo de apuntado a dos manos se distribuye desactivado.

## Instalación y documentación

Consulta la [instalación guiada](INSTALACION-FACIL.es.md) o la [guía avanzada y restauración](INSTALL.md) (en inglés). El menú permite instalar, iniciar, activar módulos, revisar el perfil y restaurar copias. El instalador comprueba hashes y no inyecta automáticamente. Necesitas el juego original, un visor PCVR, SteamVR/OpenXR y UEVR por separado.

| Jugadores | Desarrollo |
| --- | --- |
| [Controles Sense](CONTROLS.md) | [Arquitectura](ARCHITECTURE.md) |
| [Problemas conocidos](STATUS.md) | [Compilación y pruebas](BUILD.md) |
| [Solución de problemas](TROUBLESHOOTING.md) | [Arsenal](ARSENAL.md) |
| [Copias y recuperación de Windows](REINSTALL.md) | [Créditos y licencias](SOURCE-AND-NOTICES.md) |

Proyecto de aficionados, sin afiliación con los titulares del juego, UEVR o los fabricantes de visores. La espada externa es de Kaiser-E (CC BY 4.0) y conserva sus créditos. **El código propio todavía no tiene una licencia general elegida**; consulta [los avisos de terceros](SOURCE-AND-NOTICES.md).
