# Instalación guiada de Boltgun VR

Esta es la **versión 1.0.0**. El estado actual y los límites de validación se describen en [STATUS.md](STATUS.md).
El ZIP no incluye UEVR ni descarga herramientas externas por su cuenta.

1. Descarga **UEVR** desde las [versiones oficiales de praydog](https://github.com/praydog/UEVR/releases). Extráelo en una carpeta permanente; necesitarás `UEVRInjector.exe`.
2. Descomprime **todo** el ZIP de Boltgun VR y ejecuta **`Boltgun VR.cmd`**. Elige **Install or update the VR profile**, selecciona el perfil base o las opciones 3D experimentales y busca tu propio `UEVRInjector.exe`. Se admiten perfiles nuevos; el instalador guarda el estado anterior y rechaza archivos desconocidos.
3. Prepara SteamVR/OpenXR para tu visor. En el menú elige **Start Boltgun and open the UEVR frontend**. Se abrirán Boltgun por Steam y tu inyector. Selecciona Boltgun, **OpenXR** y pulsa **Inject**. **Hay que pulsar Inject manualmente en cada partida.**
4. El paquete solo ajusta el binding **Oculus Touch** que SteamVR genera para la configuración PS VR2 Sense incluida. Si aún no existe, inyecta una vez, cierra el juego y elige de nuevo **Install or update the VR profile**. No se incluyen ni validan perfiles de otros mandos.

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
