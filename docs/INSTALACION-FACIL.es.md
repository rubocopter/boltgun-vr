# Instalación guiada de Boltgun VR

Esta versión es un **paquete local de pruebas**, todavía sin publicación.
El ZIP no incluye UEVR ni descarga herramientas externas por su cuenta.

1. Descarga **UEVR** desde las [versiones oficiales de praydog](https://github.com/praydog/UEVR/releases). Extráelo en una carpeta permanente; necesitarás `UEVRInjector.exe`.
2. Inicia tu copia de **Warhammer 40,000: Boltgun** desde Steam, prepara SteamVR/OpenXR para tu visor, abre el inyector oficial de UEVR y pulsa **Inject** con Boltgun seleccionado y **OpenXR** activado. Al terminar la primera inyección, **cierra por completo el juego**. Esto crea el perfil original que utiliza el instalador.
3. Descomprime **todo** el ZIP de Boltgun VR. Ejecuta **`Instalar Boltgun VR.cmd`** y elige si quieres activar las armas y la espada 3D, que siguen en fase experimental. Selecciona en el explorador tu propio `UEVRInjector.exe`. El programa comprueba los archivos y se niega a sobrescribir configuraciones desconocidas.
4. Para jugar, ejecuta **`Jugar Boltgun VR.cmd`**. Se abrirán el juego por Steam y tu propio inyector UEVR. Selecciona Boltgun, el entorno **OpenXR** y pulsa **Inject**. **De momento hay que pulsar Inject manualmente en cada partida.**

El menú de UEVR dentro del visor comienza **oculto** y puedes mostrarlo con
**Insert** o **L3+R3**. No se ha implantado ninguna inyección automática.

**Si faltan `config.txt`, `Engine.ini` o `Input.ini`**, realiza primero el
paso 2. Si falta el binding de mandos SteamVR, inicia el juego con los mandos,
inyecta UEVR una vez, cierra Boltgun y vuelve a ejecutar el instalador.
Ante archivos modificados o errores de integridad, consulta
[la guía técnica de instalación](INSTALL.md) antes de restaurar nada.

**No borres la carpeta descomprimida del mod:** ahí quedan sus herramientas
de recuperación y las copias de seguridad que genere. Los ajustes del lanzador
se guardan en `%LOCALAPPDATA%\BoltgunVR\launcher.json`. Se usan los controles
de **PS VR2 Sense**; otros mandos todavía no se han validado.
