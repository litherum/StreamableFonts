from fontTools.ttLib.ttFont import TTFont
from fontTools.ttLib.ttFont import reorderFontTables
from io import BytesIO

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
