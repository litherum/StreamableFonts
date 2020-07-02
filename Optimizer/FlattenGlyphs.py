from fontTools.ttLib.ttFont import TTFont
from fontTools.ttLib.tables import ttProgram

def flattenGlyphs(input, fontNumber, output):
    font = TTFont(input, fontNumber=fontNumber)
    if "glyf" in font:
        for glyphName in font.getGlyphOrder():
            glyph = font["glyf"][glyphName]
            coordinates, endPtsOfContours, flags = glyph.getCoordinates(font["glyf"])
            glyph.numberOfContours = len(endPtsOfContours)
            glyph.coordinates = coordinates
            glyph.endPtsOfContours = endPtsOfContours
            glyph.flags = flags
            glyph.program = ttProgram.Program()
            font["glyf"][glyphName] = glyph

    font.save(output)
