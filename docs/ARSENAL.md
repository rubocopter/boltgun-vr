> Maintained paths: see [repository layout](REPOSITORY.md) and [build guide](BUILD.md).
> Historical commands/evidence below describe development snapshots; local research archives are not shipped.

# Arsenal 3D del Boltgun original — revisión 13

## Retroceso visual del Bolter

La revisión 13 añade un retroceso ligero de la malla al crear un proyectil real,
con recuperación suave y acumulación limitada en ráfagas. Solo se aplica al
Bolter y su variante Machine Spirit. Una malla invisible de referencia mantiene
el origen del proyectil y los fogonazos compatibles; la cámara y los mandos no
reciben animación. Las otras nueve armas conservan su comportamiento anterior.

Los ajustes distribuidos incluyen `recoil_enabled=1`; `recoil_enabled=0` vuelve
al modelo estático. La opción requiere `muzzle_enabled=1`. Si la configuración
personalizada no tiene esta clave, sigue desactivada hasta añadirla. La revisión
está preparada en el repositorio y pendiente de instalación/prueba en PS VR2.
Consulta [los cambios y pruebas pendientes](2026-10-09-revision13.md).

## Arsenal y puente de origen

El perfil experimental utiliza las **mallas 3D de pickups del propio juego**:
Bolter, escopeta, plasma, bolter pesado, lanzador Vengeance, rifle de fusiÃ³n,
Volkite, gravitÃ³n y, con el DLC, Multi-Melta y lanzamisiles. Las variantes
Machine Spirit comparten sus respectivos modelos.

Al equipar una de estas diez armas con UEVR y mandos activos, el script
comprueba la clase nativa y carga la malla exacta una sola vez si todavÃ­a no
estÃ¡ en memoria. Crea un componente visual anclado al **mando derecho**, sin
colisiÃ³n ni sombras; **solo cuando aparece ese componente** oculta
`WeaponRenderer.PrimaryRenderPlane`, el sprite de primera persona. El plano
secundario de la motosierra no se altera: actualmente no hay un modelo nativo
3D de esta arma en el catÃ¡logo de pickups verificado.

Cambiar de arma restaura el sprite anterior, destruye el componente propio y
crea el siguiente. MenÃº UEVR, pÃ©rdida de seguimiento, desactivaciÃ³n y reinicio
siguen los mecanismos de restauraciÃ³n/journal ya probados para el Bolter.
Cuando falta una malla o falla su carga, el sprite se mantiene visible y se
suspende la prueba hasta volver a desactivar y activar el modo experimental.
La activaciÃ³n no modifica el PAK ni archivos ejecutables del juego.

La escala y la empuÃ±adura **del Bolter** conservan los ajustes anteriores;
en las nueve armas adicionales las dimensiones y el agarre son estimaciones
iniciales tomadas de los pickups. Ajustar mÃ¡s adelante en VR. El puente nativo
de origen del proyectil y fogonazos compatibles ahora acepta las **diez armas**.
Cada una tiene un punto propio medido en la geometrÃ­a del caÃ±Ã³n. Proyectil y
fogonazo comparten ese punto; no se copian las coordenadas del Bolter.
Multi-Melta utiliza el punto medio entre sus dos caÃ±ones. La direcciÃ³n y la
dispersiÃ³n se conservan. Las mallas de pickup no tienen animaciÃ³n de recarga.

En `data/bolter3d.settings`, cada arma tiene `ID_muzzle_x/y/z` y
`ID_muzzle_enabled`: IDs `shotgun`, `plasma`, `heavy_bolter`, `vengeance`,
`melta`, `volkite`, `graviton`, `multi_melta` y `missile`. El Bolter conserva
`muzzle_x/y/z`. `muzzle_enabled=0` desactiva todas las correcciones sin retirar
las mallas. Los ajustes se leen cada 250 ms y son centÃ­metros locales UE.

Se exige arma equipada, malla exacta, propietario, tracking, hilo del motor,
ABI y ejecutable verificados. Los efectos de enemigo, impactos y casquillos
no se redirigen. Los Niagara adjuntos y las rutas de haz/hitscan que eviten el
helper de proyectiles mantienen su comportamiento original. Por tanto, falta
comprobar en VR quÃ© efectos quedan alineados en cada arma.

La instalaciÃ³n mantiene `bolter3d.mode=preview` y el nombre heredado del
script por compatibilidad con perfiles ya instalados. Se utiliza
`Bolter3D.ps1 -Mode preview` o `Probar bolter 3D.cmd` una vez; en adelante
solo hay que iniciar Boltgun e inyectar UEVR. `Bolter3D.ps1 -Mode off` desactiva
todo el arsenal. Se conserva una copia de seguridad de la versiÃ³n anterior
en `backups/bolter3d/`.

**VerificaciÃ³n nueva**: 136 pruebas Python/Lua y dos harnesses C++ pasan offline.
Los modelos ya fueron vistos por el usuario en VR; los ajustes de proyectiles,
fogonazos y libro de la revisiÃ³n 12 necesitan una prueba con visor.
