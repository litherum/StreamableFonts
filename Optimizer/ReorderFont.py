from fontTools.ttLib.ttFont import TTFont
from fontTools.ttLib.ttFont import reorderFontTables
from fontTools.cffLib import TopDictCompiler
from fontTools.cffLib import CharStringsCompiler
from fontTools.cffLib import IndexedStrings
from io import BytesIO

class ReorderedTopDictCompiler(TopDictCompiler):
  def getChildren(self, strings):
    result = super(ReorderedTopDictCompiler, self).getChildren(strings)
    for child in result:
        if isinstance(child, CharStringsCompiler):
            result.remove(child)
            result.append(child)
            break
    return result

def computeTableOrder(tags):
    count = 0
    if "glyf" in tags:
        count += 1
        tags.remove("glyf")
        tags.append("glyf")
    if "CFF " in tags:
        count += 1
        tags.remove("CFF ")
        tags.append("CFF ")
    if "CFF2" in tags:
        count += 1
        tags.remove("CFF2")
        tags.append("CFF2")
    return count == 1

def reorderGlyphs(glyphOrder, desiredGlyphOrder):
    if len(glyphOrder) != len(desiredGlyphOrder):
        return None
    result = []
    for desiredGlyph in desiredGlyphOrder:
        result.append(glyphOrder[desiredGlyph])
    return result

def fixLayoutCoverage(font):
    # Coverage sub tables inside of ot layout tables (GPOS, GSUB)
    # must have glyphs sorted by numeric order. FontTools does
    # not correct ordering problems on compilation, so we must
    # do it ourselves.
    if "GPOS" in font:
        dfs(font["GPOS"], font)
    if "GSUB" in font:
        dfs(font["GSUB"], font)

def dfs(table, font):
    if type(table).__name__ == "Coverage":
        fixGlyphOrder(table.glyphs, font)
        return

    if type(table) == list:
      values = table
    elif type(table) == dict:
      values = table.values()
    elif not table or type(table) == int or type(table) == str:
      values = []
    else:
      values = table.__dict__.values()

    for sub in values:
        dfs(sub, font)

def fixGlyphOrder(glyphs, font):
    glyph_ids = sorted([font.getGlyphID(gname) for gname in glyphs])
    del glyphs[:]
    glyphs.extend([font.getGlyphOrder()[gid] for gid in glyph_ids])

def fullyLoadFont(font):
    # Run the save to xml which will touch all tables and sub tables
    # forcing full decompilation of the original font.
    tmp = BytesIO()
    font.saveXML(tmp)
    return font

def reorderFont(input, fontNumber, desiredGlyphOrder, output):
    font = TTFont(input, fontNumber=fontNumber, lazy=False)
    font = fullyLoadFont(font)

    if "CFF " in font:
        cff = font["CFF "]
        fontName = cff.cff.fontNames[0]
        topDict = cff.cff[fontName]
        topDict.compilerClass = ReorderedTopDictCompiler

    glyphOrder = font.getGlyphOrder()
    reorderedGlyphs = reorderGlyphs(glyphOrder, desiredGlyphOrder)
    if reorderedGlyphs is None:
        return False

    font.setGlyphOrder(reorderedGlyphs)
    # Glyph order is cached in a few places, clear those out.
    del font["glyf"].glyphOrder
    if hasattr(font, "_reverseGlyphOrderDict"):
      del font._reverseGlyphOrderDict

    fixLayoutCoverage(font)

    tmp = BytesIO()
    font.save(tmp)

    tableOrder = font.reader.keys()
    success = computeTableOrder(tableOrder)
    if not success:
        tmp.close()
        return False
    outputStream = open(output, "wb")
    reorderFontTables(tmp, outputStream, tableOrder)
    tmp.close()
    outputStream.close()

    return True
