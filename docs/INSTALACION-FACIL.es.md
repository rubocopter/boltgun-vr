# Instalación guiada de Boltgun VR

Esta versión es un **paquete local de pruebas**, todavía sin publicación.
El ZIP no incluye UEVR ni descarga herramientas externas por su cuenta.

1. Descarga **UEVR** desde las [versiones oficiales de praydog](https://github.com/praydog/UEVR/releases). Extráelo en una carpeta permanente; necesitarás `UEVRInjector.exe`.
2. Descomprime **todo** el ZIP de Boltgun VR. Ejecuta **`Instalar Boltgun VR.cmd`** y elige si quieres activar las armas y la espada 3D, que siguen en fase experimental. Selecciona tu propio `UEVRInjector.exe`. Se admiten perfiles nuevos sin archivos previos; el instalador guarda el estado anterior antes de modificarlo y rechaza archivos desconocidos.
3. Prepara SteamVR/OpenXR para tu visor. Para jugar, ejecuta **`Jugar Boltgun VR.cmd`**. Se abrirán Boltgun por Steam y tu inyector UEVR. Selecciona Boltgun, **OpenXR** y pulsa **Inject**. **Hay que pulsar Inject manualmente en cada partida.**
4. Si SteamVR aún no ha generado el binding de Boltgun, cierra el juego después de la primera inyección y ejecuta de nuevo **`Instalar Boltgun VR.cmd`** para ajustar los botones Options/Create. El binding debe generarlo SteamVR.

El menú de UEVR dentro del visor comienza **oculto** y puedes mostrarlo con
**Insert** o **L3+R3**. No se ha implantado ninguna inyección automática.

Si faltan `config.txt`, `Engine.ini` o `Input.ini`, el instalador crea
los archivos declarados. Si faltan los controles de SteamVR, sigue el paso 4.
Ante archivos modificados o errores de integridad, consulta
[la guía técnica de instalación](INSTALL.md) antes de restaurar nada.

**No borres la carpeta descomprimida del mod:** ahí quedan sus herramientas
de recuperación y las copias de seguridad que genere. Los ajustes del lanzador
se guardan en `%LOCALAPPDATA%\BoltgunVR\launcher.json`. Se usan los controles
de **PS VR2 Sense**; otros mandos todavía no se han validado.
