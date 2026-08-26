# Imágenes de marca

## Archivos que usa la app

| Archivo | Dónde se usa | Widget |
|---|---|---|
| `logo.svg` | Tarjeta de membresía, menú lateral, inicio de invitado | `CelfixLogo` |
| `x.svg` | Centro del QR, tarjetas de promos | `CelfixMark` |

Ambos son vectoriales: se ven nítidos a cualquier tamaño y densidad de
pantalla, sin necesidad de variantes `2.0x` / `3.0x`.

Los dos están declarados **archivo por archivo** en `pubspec.yaml`. Si agregas
una imagen nueva, hay que listarla ahí o no se incluye en el build. Es a
propósito: declarar la carpeta completa metería también este README y los
originales sin usar.

## De dónde salió `x.svg`

Se extrajo de `logo.svg`, que es el wordmark completo "CELFIX". Las tres rutas
del extremo derecho (`x` de 400.80 a 498.41) forman la "X"; el resto son las
letras C-E-L-F-I y el tagline. El `viewBox` quedó recortado al bounding box
real de esas curvas: `400.80 4.61 97.61 95.76`.

Si algún día cambia el logo, hay que repetir la extracción — no basta con
reemplazar `logo.svg`.

## Color

Las rutas de `logo.svg` vienen todas en el cyan de marca **`#019ADA`** (el
archivo declaraba blanco y azul marino `#002D5F` en su `<style>`, pero no los
usa). Sobre fondos azules el logo se perdería, así que ambos widgets aceptan un
parámetro `color` que lo repinta:

```dart
const CelfixLogo(height: 30, color: Colors.white)  // sobre la tarjeta azul
const CelfixLogo(height: 46)                       // cyan, sobre fondo claro
```

## Por qué `logo.svg` está modificado

El archivo que exportó Illustrator definía sus colores en un bloque `<style>`
con clases CSS (`.st2 { fill: #019ADA }`). **`flutter_svg` no aplica bloques
`<style>`**: renderizaba el logo en negro en cualquier pantalla donde no se le
pasara un `color` explícito — login, splash e inicio de invitado.

Se inlinearon esos estilos como atributos `fill` en cada ruta. El resultado es
visualmente idéntico. El export original quedó intacto en `logo.src.svg`, que
no se incluye en el build.

Si reemplazas `logo.svg` con un export nuevo de Illustrator, hay que repetir
esta normalización o el logo volverá a salir negro.

## Archivos sin usar

`x.png` (60×60) fue el isotipo original en mapa de bits. Se reemplazó por
`x.svg` porque a 3x de densidad se veía suave. Sigue en la carpeta pero no se
incluye en el build.

## Ícono de la app

El ícono del launcher es aparte de esto — vive en `android/app/src/main/res/`,
`ios/Runner/Assets.xcassets/` y `web/icons/`. Se genera desde un PNG cuadrado de
1024×1024.
