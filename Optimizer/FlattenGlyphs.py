from fontTools.ttLib.ttFont import TTFont
from fontTools.ttLib.tables import ttProgram
from fontTools.misc import psCharStrings

class FlattenError(Exception):
  """We couldn't figure out the range requests to send."""

def inlineProgram(localSubrs, globalSubrs, program):
    if len(program) < 2:
        return program

    inlinedProgram = []
    context = program[0]
    for i in range(1, len(program)):
        if program[i] == "callsubr":
            index = context + psCharStrings.calcSubrBias(localSubrs)
            inlinedProgram.extend(inlineProgram(localSubrs, globalSubrs, localSubrs[index].program))
            context = None
        elif program[i] == "callgsubr":
            index = context + psCharStrings.calcSubrBias(globalSubrs)
            inlinedProgram.extend(inlineProgram(localSubrs, globalSubrs, globalSubrs[index].program))
            context = None
        elif program[i] == "return":
            if context is not None:
                inlinedProgram.append(context)
            return inlinedProgram
        else:
            if context is not None:
                inlinedProgram.append(context)
            context = program[i]
    if context is not None:
        inlinedProgram.append(context)
    return inlinedProgram

  
def flattenGlyphs(input, fontNumber, output):
    font = TTFont(input, fontNumber=fontNumber)
    font.recalcBBoxes = False
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
    elif "CFF " in font:
        cff = font["CFF "]
        fontName = cff.cff.fontNames[0]
        topDict = cff.cff[fontName]
        for glyphID in range(len(font.getGlyphOrder())):
            charString = topDict.CharStrings.charStringsIndex[glyphID]
            charString.decompile()
            localSubrs = getattr(charString.private, "Subrs", [])
            globalSubrs = charString.globalSubrs
            inlinedProgram = inlineProgram(localSubrs, globalSubrs, charString.program)
            charString.program = inlinedProgram
        if "Private" in topDict.rawDict and "Subrs" in topDict.Private.rawDict:
            topDict.Private.Subrs
            del topDict.Private.rawDict["Subrs"]
            del topDict.Private.Subrs
        topDict.GlobalSubrs.items = []
    else:
        raise FlattenError("Could not flatten glyphs.")

    font.save(output)
