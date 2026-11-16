"""Convierte las fuentes TTF del diseño (licencia OFL) en fuentes de mapa de bits BMFont
(.fnt de texto + .png) para Connect IQ, con antialias y solo los glifos que usa la app.

Uso (desde la raíz del repositorio; normalmente lo llama scripts/make_fonts.ps1):

    ml\\.venv\\Scripts\\python.exe -I scripts\\make_fonts.py [--check]

- Lee las TTF variables oficiales de assets/fonts/ (google/fonts, sin modificar) y crea
  con fontTools una instancia estática de cada peso (y tamaño óptico, en Inter).
- Dibuja cada glifo con Pillow (antialias de FreeType) y lo recorta a su tinta. El avance
  de cada glifo es el exacto de la fuente (tabla hmtx, sin el redondeo del hinting) más el
  espaciado de la tabla FONTS, redondeado al píxel.
- Escribe en resources/fonts/ un .fnt y un .png por fuente y fonts.xml con sus <font>
  (antialias="true").
- --check solo comprueba que los textos de resources*/strings/strings.xml caben en el
  juego de caracteres y no escribe nada.

Es reproducible: con las mismas TTF y las mismas versiones de Pillow y fontTools
(ml/requirements.txt) genera archivos idénticos byte a byte. Diseño de cada fuente:
docs/DISENO.md §3.
"""
import argparse
import html
import io
import re
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / 'assets' / 'fonts'
OUTPUT = ROOT / 'resources' / 'fonts'

# TTF variables de google/fonts (ofl/<familia>/), renombradas sin corchetes.
SPACE_GROTESK = 'SpaceGrotesk-VF.ttf'   # ejes: wght 300–700
INTER = 'Inter-VF.ttf'                  # ejes: opsz 14–32, wght 100–900
JETBRAINS_MONO = 'JetBrainsMono-VF.ttf' # ejes: wght 100–800

DIGITS = '0123456789'

# Letras de español e inglés, dígitos y signos de los textos de la app (strings.xml).
TEXT_CHARS = (
    ' !"%\'()+,-./:;?'
    + DIGITS
    + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    + 'abcdefghijklmnopqrstuvwxyz'
    + 'ÁÉÍÓÚÜÑáéíóúüñ'
    + '¡¿·–—…‘’“”'
)

# Cifras en JetBrains Mono: dígitos, "%" y los separadores decimales ("93,3%", "1.9").
NUMBER_CHARS = DIGITS + '%,.'

# Título de la alerta: solo las letras de "¡DESPIERTA!" y "WAKE UP!".
ALERT_TITLE_CHARS = '¡DESPIERTA!' + 'WAKE UP!'

# (id del recurso, archivo de salida, TTF, peso, tamaño en px, caracteres, espaciado en px)
#
# Pesos y espaciados medidos en las referencias del diseño web (docs/img/referencia/, a
# 390 px) con los avances exactos de cada fuente:
#   - hora "10:50": 189 px de ancho y 56 px de alto; Space Grotesk Bold 76 mide 196 px
#     → −2 px por carácter (≈ −0,025 em);
#   - "¡DESPIERTA!": 231 px; Space Grotesk Bold 42 mide 235 → −0,4 px;
#   - "Iniciar guardia" (Inter Bold 18), "Nivel 1 de 3 · vibración suave" (SemiBold 15),
#     "Monitoreo en pausa" (SemiBold 13) y "Estoy despierto" (ExtraBold 22) coinciden sin
#     espaciado (±2 px);
#   - la fecha y el motivo de la alerta tienen el trazo de Inter Medium (500).
FONTS = [
    ('TimeBold76', 'space_grotesk_bold_76', SPACE_GROTESK, 700, 76, DIGITS + ':', -2.0),
    ('AlertBold42', 'space_grotesk_bold_42', SPACE_GROTESK, 700, 42, ALERT_TITLE_CHARS, -0.4),
    ('TitleBold22', 'space_grotesk_bold_22', SPACE_GROTESK, 700, 22, TEXT_CHARS, 0.0),
    ('InterMedium13', 'inter_medium_13', INTER, 500, 13, TEXT_CHARS, 0.0),
    ('InterSemiBold13', 'inter_semibold_13', INTER, 600, 13, TEXT_CHARS, 0.0),
    ('InterMedium15', 'inter_medium_15', INTER, 500, 15, TEXT_CHARS, 0.0),
    ('InterSemiBold15', 'inter_semibold_15', INTER, 600, 15, TEXT_CHARS, 0.0),
    ('InterBold18', 'inter_bold_18', INTER, 700, 18, TEXT_CHARS, 0.0),
    ('InterExtraBold22', 'inter_extrabold_22', INTER, 800, 22, TEXT_CHARS, 0.0),
    ('MonoSemiBold14', 'jetbrains_mono_semibold_14', JETBRAINS_MONO, 600, 14, NUMBER_CHARS, 0.0),
    ('MonoSemiBold22', 'jetbrains_mono_semibold_22', JETBRAINS_MONO, 600, 22, NUMBER_CHARS, 0.0),
]

# Ancho de página del PNG y separación entre glifos (px).
PAGE_WIDTH = 256
SPACING = 1

# Textos que no se dibujan con las fuentes propias (menús de depuración y guía de estilo).
SKIP_STRING_PREFIXES = ('StyleGuide', 'TypeRole', 'Debug')


def unique(chars):
    """Caracteres sin repetir, en orden de código (salida estable)."""
    return sorted(set(chars), key=ord)


def static_instance(ttf, weight, size):
    """Instancia estática de la TTF variable con el peso dado (Inter: tamaño óptico igual
    al tamaño en px, dentro de su rango)."""
    font = TTFont(SOURCES / ttf)
    location = {}
    for axis in font['fvar'].axes:
        if axis.axisTag == 'wght':
            location['wght'] = weight
        elif axis.axisTag == 'opsz':
            location['opsz'] = min(max(size, axis.minValue), axis.maxValue)
    return instantiateVariableFont(font, location, updateFontNames=False)


def render_glyph(pil_font, char, size):
    """Bitmap del glifo recortado a su tinta y su posición respecto al origen del trazo y
    a la línea base (izquierda, arriba; arriba es negativo)."""
    pad = size
    canvas = Image.new('L', (size * 3, size * 3), 0)
    ImageDraw.Draw(canvas).text((pad, 2 * pad), char, font=pil_font, fill=255, anchor='ls')
    box = canvas.getbbox()
    if box is None:
        return None, 0, 0
    left, top = box[0], box[1]
    return canvas.crop(box), left - pad, top - 2 * pad


def pack(glyphs):
    """Coloca los glifos en filas dentro de una página de PAGE_WIDTH px (de más alto a
    más bajo, para desperdiciar menos). Devuelve el alto de la página."""
    order = sorted((g for g in glyphs if g['image'] is not None),
                   key=lambda g: (-g['image'].height, g['id']))
    x = y = row = 0
    for glyph in order:
        w, h = glyph['image'].size
        if x + w > PAGE_WIDTH:
            x = 0
            y += row + SPACING
            row = 0
        glyph['x'], glyph['y'] = x, y
        x += w + SPACING
        row = max(row, h)
    return y + row


def build(resource_id, name, ttf, weight, size, chars, tracking):
    instance = static_instance(ttf, weight, size)
    data = io.BytesIO()
    instance.save(data)
    pil_font = ImageFont.truetype(io.BytesIO(data.getvalue()), size)

    upem = instance['head'].unitsPerEm
    scale = size / upem
    hhea = instance['hhea']
    ascent = round(hhea.ascent * scale)
    descent = round(-hhea.descent * scale)
    cmap = instance.getBestCmap()
    hmtx = instance['hmtx']

    glyphs = []
    for char in unique(chars):
        if ord(char) not in cmap:
            raise SystemExit(f'{ttf} no tiene el carácter {char!r} (U+{ord(char):04X})')
        advance = round(hmtx[cmap[ord(char)]][0] * scale + tracking)
        image, left, top = render_glyph(pil_font, char, size)
        glyphs.append({'id': ord(char), 'image': image, 'xoffset': left,
                       'yoffset': ascent + top, 'advance': advance, 'x': 0, 'y': 0})
    height = max(1, pack(glyphs))
    page = Image.new('L', (PAGE_WIDTH, height), 0)
    for glyph in glyphs:
        if glyph['image'] is not None:
            page.paste(glyph['image'], (glyph['x'], glyph['y']))
    page.save(OUTPUT / f'{name}.png', optimize=True)

    family = pil_font.getname()[0]
    lines = [
        f'info face="{family}" size=-{size} bold={1 if weight >= 700 else 0} italic=0 '
        f'charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 '
        f'spacing={SPACING},{SPACING} outline=0',
        f'common lineHeight={ascent + descent} base={ascent} scaleW={PAGE_WIDTH} '
        f'scaleH={height} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0',
        f'page id=0 file="{name}.png"',
        f'chars count={len(glyphs)}',
    ]
    for g in glyphs:
        w, h = g['image'].size if g['image'] is not None else (0, 0)
        lines.append(f'char id={g["id"]} x={g["x"]} y={g["y"]} width={w} height={h} '
                     f'xoffset={g["xoffset"]} yoffset={g["yoffset"]} '
                     f'xadvance={g["advance"]} page=0 chnl=15')
    (OUTPUT / f'{name}.fnt').write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')

    inked = sum(g['image'].width * g['image'].height for g in glyphs if g['image'] is not None)
    print(f'{resource_id:18} {family} {weight} {size:>2} px ({tracking:+.1f}): '
          f'{len(glyphs):>3} glifos, alto de línea {ascent + descent}, base {ascent}, '
          f'página {PAGE_WIDTH}x{height}, {inked} px de glifos')
    return inked


def write_resources():
    lines = [
        '<!--',
        '    Fuentes propias en mapa de bits (BMFont), generadas por scripts/make_fonts.ps1.',
        '    No editar a mano: cambia scripts/make_fonts.py y vuelve a generarlas.',
        '    Licencias (SIL OFL 1.1): resources/fonts/LICENSES/.',
        '-->',
        '<resources>',
        '    <fonts>',
    ]
    for resource_id, name, *_ in FONTS:
        lines.append(f'        <font id="{resource_id}" filename="{name}.fnt" antialias="true"/>')
    lines += ['    </fonts>', '</resources>']
    (OUTPUT / 'fonts.xml').write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')


def check_strings():
    """Caracteres de los textos de la app que faltan en el juego de Inter."""
    used = set()
    for path in (ROOT / 'resources' / 'strings' / 'strings.xml',
                 ROOT / 'resources-spa' / 'strings' / 'strings.xml'):
        text = path.read_text(encoding='utf-8')
        for match in re.finditer(r'<string id="([^"]+)"[^>]*>(.*?)</string>', text, re.S):
            if match.group(1).startswith(SKIP_STRING_PREFIXES):
                continue
            # Quita los marcadores de Lang.format ($1$, $2$…).
            used.update(re.sub(r'\$\d+\$', '', html.unescape(match.group(2))))
    used.discard('\n')
    return sorted(used - set(TEXT_CHARS), key=ord)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true',
                        help='solo comprueba que los textos caben en el juego de caracteres')
    args = parser.parse_args()

    missing = check_strings()
    if missing:
        print('Faltan glifos para estos caracteres de strings.xml: '
              + ' '.join(f'{c!r} (U+{ord(c):04X})' for c in missing))
        return 1
    print('Todos los caracteres de strings.xml están en el juego de caracteres de texto.')
    if args.check:
        return 0

    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = sum(build(*spec) for spec in FONTS)
    write_resources()
    print(f'{len(FONTS)} fuentes en {OUTPUT.relative_to(ROOT)}, {total} px de glifos en total.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
