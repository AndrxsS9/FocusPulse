"""Convierte las fuentes TTF del diseño (licencia OFL) en fuentes de mapa de bits BMFont
(.fnt de texto + .png) para Connect IQ, con antialias y solo los glifos que usa la app.

Uso (desde la raíz del repositorio; normalmente lo llama scripts/make_fonts.ps1):

    ml\\.venv\\Scripts\\python.exe -I scripts\\make_fonts.py [--check]

- Lee las TTF variables oficiales de assets/fonts/ (google/fonts, sin modificar) y fija el
  peso (y el tamaño óptico de Inter) con los ejes de variación.
- Escribe en resources/fonts/ un .fnt y un .png por fuente y fonts.xml con sus <font>
  (antialias="true").
- --check solo comprueba que los textos de resources*/strings/strings.xml caben en el
  juego de caracteres de Inter y no escribe nada.

Es reproducible: con las mismas TTF y la misma versión de Pillow (ml/requirements.txt)
genera archivos idénticos byte a byte. Diseño de cada fuente: docs/DISENO.md §3.
"""
import argparse
import html
import re
import sys
from pathlib import Path

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

# (id del recurso, archivo de salida, TTF, peso, tamaño en px, caracteres)
FONTS = [
    ('TimeBold76', 'space_grotesk_bold_76', SPACE_GROTESK, 700, 76, DIGITS + ':'),
    ('AlertBold42', 'space_grotesk_bold_42', SPACE_GROTESK, 700, 42, ALERT_TITLE_CHARS),
    ('TitleBold22', 'space_grotesk_bold_22', SPACE_GROTESK, 700, 22, TEXT_CHARS),
    ('InterSemiBold13', 'inter_semibold_13', INTER, 600, 13, TEXT_CHARS),
    ('InterSemiBold15', 'inter_semibold_15', INTER, 600, 15, TEXT_CHARS),
    ('InterBold18', 'inter_bold_18', INTER, 700, 18, TEXT_CHARS),
    ('InterExtraBold22', 'inter_extrabold_22', INTER, 800, 22, TEXT_CHARS),
    ('MonoSemiBold14', 'jetbrains_mono_semibold_14', JETBRAINS_MONO, 600, 14, NUMBER_CHARS),
    ('MonoSemiBold22', 'jetbrains_mono_semibold_22', JETBRAINS_MONO, 600, 22, NUMBER_CHARS),
]

# Ancho de página del PNG y separación entre glifos (px).
PAGE_WIDTH = 256
SPACING = 1

# Textos que no se dibujan con las fuentes propias (menús de depuración y guía de estilo).
SKIP_STRING_PREFIXES = ('StyleGuide', 'TypeRole', 'Debug')


def unique(chars):
    """Caracteres sin repetir, en orden de código (salida estable)."""
    return sorted(set(chars), key=ord)


def load_font(ttf, weight, size):
    font = ImageFont.truetype(str(SOURCES / ttf), size)
    axes = font.get_variation_axes()
    values = []
    for axis in axes:
        name = axis['name'].decode() if isinstance(axis['name'], bytes) else axis['name']
        if name == 'Weight':
            values.append(weight)
        elif name == 'Optical size':
            # Inter: tamaño óptico igual al tamaño en px, dentro de su rango (14–32).
            values.append(min(max(size, axis['minimum']), axis['maximum']))
        else:
            values.append(axis['default'])
    font.set_variation_by_axes(values)
    return font


def render_glyph(font, char):
    """Bitmap en escala de grises del glifo y sus medidas BMFont (respecto a la línea
    base y al origen del trazo)."""
    left, top, right, bottom = font.getbbox(char, anchor='ls')
    width, height = right - left, bottom - top
    advance = round(font.getlength(char))
    if width <= 0 or height <= 0:
        return None, 0, 0, advance
    image = Image.new('L', (width, height), 0)
    ImageDraw.Draw(image).text((-left, -top), char, font=font, fill=255, anchor='ls')
    return image, left, top, advance


def pack(glyphs):
    """Coloca los glifos en filas dentro de una página de PAGE_WIDTH px (de más alto a
    más bajo, para desperdiciar menos). Devuelve la posición de cada uno y el alto."""
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


def build(resource_id, name, ttf, weight, size, chars):
    font = load_font(ttf, weight, size)
    ascent, descent = font.getmetrics()
    glyphs = []
    for char in unique(chars):
        image, left, top, advance = render_glyph(font, char)
        glyphs.append({'id': ord(char), 'image': image, 'xoffset': left,
                       'yoffset': ascent + top, 'advance': advance, 'x': 0, 'y': 0})
    height = max(1, pack(glyphs))
    page = Image.new('L', (PAGE_WIDTH, height), 0)
    for glyph in glyphs:
        if glyph['image'] is not None:
            page.paste(glyph['image'], (glyph['x'], glyph['y']))
    page.save(OUTPUT / f'{name}.png', optimize=True)

    family = font.getname()[0]
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
    print(f'{resource_id:18} {family} {weight} {size:>2} px: {len(glyphs):>3} glifos, '
          f'alto de línea {ascent + descent}, base {ascent}, página {PAGE_WIDTH}×{height}, '
          f'{inked} px de glifos')
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
    print('Todos los caracteres de strings.xml están en el juego de Inter.')
    if args.check:
        return 0

    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = sum(build(*spec) for spec in FONTS)
    write_resources()
    print(f'{len(FONTS)} fuentes en {OUTPUT.relative_to(ROOT)}, {total} px de glifos en total.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
