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

def reorderFont(input, fontNumber, desiredGlyphOrder, output):
    font = TTFont(input, fontNumber=fontNumber)

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
