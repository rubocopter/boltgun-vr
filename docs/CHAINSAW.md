> Maintained paths: see [repository layout](REPOSITORY.md) and [build guide](BUILD.md).
> Historical commands/evidence below describe development snapshots; local research archives are not shipped.

# Chainsword externa de Kaiser-E

## Codex del jugador â€” revisiÃ³n 2

Se identificaron las animaciones originales `BP_PlayerAnimation_Idle_Opening`,
`Reading` y `PageTurn`, con materiales/texturas en las tres carpetas de
`/Game/Art/Animations/Player/Codex/`. Solo durante esas fases se reduce la escala
del sprite secundario al 65%, conservando su animaciÃ³n y seguimiento. Reduce
el tamaÃ±o aparente; no modifica la distancia fÃ­sica al visor ni crea un libro 3D.

La escala se restaura al terminar la animaciÃ³n, salir de VR, abrir UEVR,
desactivar el mÃ³dulo o recuperar un reset. Si el juego ya ha escrito una escala
nueva, se conserva. `chainsword3d.book` registra la identidad exacta de la sesiÃ³n
y los valores originales antes de modificar el plano. La comparaciÃ³n contempla
la precisiÃ³n float32 para evitar encoger repetidamente el sprite.

Opciones de `data/chainsword3d.settings`: `book_scale=0.65`, `book_enabled=1`.
`book_enabled=0` o `book_scale=1` conserva el tamaÃ±o original. Las claves ausentes
usan estos valores, sin cambiar la calibraciÃ³n de la espada. 21 pruebas del
mÃ³dulo pasan offline; falta comprobar aspecto y legibilidad en el visor.

La primera versiÃ³n usa la descarga autorizada por el usuario de
[Wh-40k-chainsword](https://sketchfab.com/3d-models/wh-40k-chainsword-2976e3debf33494a831253b160f7d2c9),
de Kaiser-E, CC BY 4.0. La atribuciÃ³n se incluye en `assets/chainsword/CREDITS.txt` y se
copia junto al modelo al perfil instalado.

Ambos formatos descargados contienen la misma malla: 8.014 vÃ©rtices con
separaciÃ³n por UV/normales y 7.814 triÃ¡ngulos. No hay rig, animaciones ni
una cadena separada. Se conservan sus caras de doble sentido con 15.628
triÃ¡ngulos de renderizado, porque el material cocinado tiene opciones estÃ¡ticas.
La geometrÃ­a se normaliza a 95 cm, con origen estimado
en la empuÃ±adura y ejes para sostenerla verticalmente con el mando izquierdo.
El tamaÃ±o y agarre son iniciales, pendientes de calibrar en PSVR2.

El clip del usuario `clip_1.791.532.998.772.mp4` confirma la apariciÃ³n y el
seguimiento de la mano de esta primera versiÃ³n. El registro de UEVR del
9 de octubre, 10:01:35, confirma la carga de geometrÃ­a, material y textura.
El usuario seÃ±ala que el lado de la cadena queda invertido: se ha aplicado
`yaw=180` tanto en el perfil instalado como en los ajustes predeterminados.
El giro mantiene el eje longitudinal y el origen de agarre; su sentido final
todavÃ­a necesita confirmaciÃ³n en el visor. No cambia geometrÃ­a ni DLL.

## Carga y comportamiento

El juego incluye `/Script/ProceduralMeshComponent`. Un plugin independiente
de UEVR entrega una sola secciÃ³n mediante `CreateMeshSection` despuÃ©s de
comprobar ejecutable exacto, hilo del motor, pawn y propietario del componente,
funciÃ³n nativa, parÃ¡metros de referencia constantes y tamaÃ±os UE4 reflejados.
Los buffers temporales se asignan y liberan con el FMalloc del propio motor.
No se interceptan funciones ni se cambian paquetes del juego. La geometrÃ­a
se carga una sola vez desde el perfil, con lÃ­mites, Ã­ndices y valores finitos
comprobados antes de usarla.

Lua crea un componente propio sin colisiones, vinculado a la mano izquierda.
SÃ³lo continÃºa si `GetNumSections()` confirma la secciÃ³n y si una textura 2K
se importa y queda asignada al parÃ¡metro `BC` de un material dinÃ¡mico propio.
Se reutiliza el material unlit de los pickups de Boltgun; no hay metalizado
PBR ni mapa normal aplicado en esta primera versiÃ³n. Los originales de
Sketchfab permanecen intactos en Descargas.

Se reconoce el sprite de Chainsword por su material o su textura BC en
`/Game/Art/Animations/Weapons/Chainsword/`. Se oculta Ãºnicamente ese sprite;
si el plano secundario muestra otro efecto, se restaura y se esconde
temporalmente la espada 3D. No se toca el plano del arma derecha. Los fallos
de carga dejan la sierra original y detienen nuevos intentos en esa instancia.
Un registro de propiedad permite retirar/restaurar durante una recarga del
script, siempre en el tick del motor y sobre identidades verificadas.

Se mantienen L2, las reglas de ataque, los sonidos y los efectos del juego.
No se aÃ±aden ataques por gestos ni se recolocan las chispas. El movimiento
visible sigue el mando. La malla externa carece de rig, pero el puente nativo
identifica 24 piezas geomÃ©tricas independientes de la cadena, incluidas
las de la punta, y aplica una oscilaciÃ³n progresiva de hasta 0,38 cm
al mantener el gatillo izquierdo de UEVR (`/actions/default/in/Trigger`, L2).
El movimiento de dientes se actualiza como mÃ¡ximo unas 25 veces por segundo
mediante `UpdateMeshSection`, conservando la hoja, empuÃ±adura, normales,
textura y ausencia de colisiones. Al soltar L2 se restaura la malla exacta.
No se modifica la activaciÃ³n de la habilidad del juego.

La actualizaciÃ³n usa el mismo control de hilo, pawn, propietario, tipo y
parÃ¡metros reflejados del puente original. Un identificador izquierdo cero es
vÃ¡lido en OpenXR. Si el modelo no contiene las piezas esperadas, falta la
acciÃ³n o `UpdateMeshSection` no cumple el contrato, la espada permanece
estÃ¡tica y se registra el motivo. La animaciÃ³n, sus tiempos y la sincronÃ­a
visual con la habilidad **aÃºn deben probarse en PSVR2/UEVR**; los tests
offline solo verifican transformaciÃ³n, reversibilidad y llamadas de puente.

## InstalaciÃ³n y ajustes

Con el juego cerrado: `scripts/Chainsword3D.ps1 -Mode install`. DespuÃ©s abrir Boltgun
e inyectar UEVR normalmente; no requiere lanzador durante cada partida.
`-Mode status` comprueba hashes, y `-Mode off` permite desactivar. No borrar
el script a mano mientras su modelo estÃ© en uso.

En `data/chainsword3d.settings`, `scale` controla el tamaÃ±o; `x/y/z` son
desplazamientos en ejes GLM de UObjectHook y `pitch/yaw/roll` son grados.
Se leen cada 250 ms. La instalaciÃ³n preserva ajustes existentes.

## VerificaciÃ³n

`test_prepare.py` comprueba agarre, longitud y validaciÃ³n del conversor.
`Build.ps1` compila el plugin y ejecuta tests del parser real y del puente
real con reflexiÃ³n/allocator simulados. `tests/test_chainsword_preview.py`
cubre carga diferida, mano izquierda, fallback, efectos secundarios,
retirada, recuperaciÃ³n y ausencia de accesos Unreal desde reset/carga Lua.

**La apariciÃ³n inicial estÃ¡ confirmada por el usuario. La correcciÃ³n de
orientaciÃ³n no se ha probado en visor.** Las pruebas locales no demuestran
ausencia de crashes nativos,
ergonomÃ­a, comportamiento con cambios de nivel o alineaciÃ³n de las chispas.
En `log.txt`, buscar `[Boltgun Chainsword 3D]` para la primera prueba.

Referencias tÃ©cnicas:
[CreateMeshSection UE4.27](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Plugins/ProceduralMeshComponent/UProceduralMeshComponent/CreateMeshSection?application_version=4.27),
[ImportFileAsTexture2D](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/Kismet/UKismetRenderingLibrary/ImportFileAsTexture2D?application_version=4.27).
