# Fuentes de origen

TTF variables oficiales de [google/fonts](https://github.com/google/fonts), sin modificar
(descargadas el 2026-11-15 de la rama `main`; solo se quitaron los corchetes del nombre).
`scripts\make_fonts.ps1` las convierte en las fuentes de mapa de bits de `resources/fonts/`.
No se empaquetan en la app.

| Archivo | Origen en google/fonts | Ejes | SHA-256 |
|---|---|---|---|
| `SpaceGrotesk-VF.ttf` | `ofl/spacegrotesk/SpaceGrotesk[wght].ttf` | wght 300–700 | `acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72` |
| `Inter-VF.ttf` | `ofl/inter/Inter[opsz,wght].ttf` | opsz 14–32, wght 100–900 | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| `JetBrainsMono-VF.ttf` | `ofl/jetbrainsmono/JetBrainsMono[wght].ttf` | wght 100–800 | `48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda` |

Licencia: SIL Open Font License 1.1 (textos completos en `resources/fonts/LICENSES/`).

- Space Grotesk — Copyright 2020 The Space Grotesk Project Authors
  (https://github.com/floriankarsten/space-grotesk). Diseño de Florian Karsten.
- Inter — Copyright 2020 The Inter Project Authors (https://github.com/rsms/inter).
  Diseño de Rasmus Andersson.
- JetBrains Mono — Copyright 2020 The JetBrains Mono Project Authors
  (https://github.com/JetBrains/JetBrainsMono).
