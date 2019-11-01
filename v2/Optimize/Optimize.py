import hyperopt
import json

# FIXME: Consider computing these files here with pyobjc-framework-CoreText

glyphSizesFile = open("/Users/litherum/Documents/output_glyph_sizes.json", "r")
glyphSizes = json.load(glyphSizesFile)

urlsFile = open("/Users/litherum/Documents/output_glyphs.json", "r")
urls = json.load(urlsFile)

#urlCount = 37451
urlCount = 3745
#glyphCount = 8676
glyphCount = 867
unconditionalDownloadSize = 282828
averageGlyphSize = 170.084
threshold = 8 * 170

def objective(args):
    items = sorted([(i, args[i]) for i in range(len(args))], key=lambda x:x[1])
    result = 0
    for i in range(urlCount):
        result += unconditionalDownloadSize + threshold
        url = urls[i];
        necessaryGlyphs = set(url["Glyphs"])
        state = 0
        unnecessarySize = 0
        for item in items:
            glyph = item[0]
            size = glyphSizes[glyph]
            if glyph in necessaryGlyphs:
                result += size
                if state == 0:
                    result += min(unnecessarySize, threshold)
                state = 1
            else:
                if state == 0:
                    unnecessarySize += size
                else:
                    unnecessarySize = size
                state = 0
    return result

space = [hyperopt.hp.uniform("glyph " + str(i), 0, glyphCount) for i in range(glyphCount)]

best = hyperopt.fmin(objective, space, algo=hyperopt.tpe.suggest, max_evals=100)
bestArgs = hyperopt.space_eval(space, best)
bestResult = objective(bestArgs)

print(best)
print(bestArgs)
print("On average, downloaded " + str(bestResult / urlCount) + " bytes per url")
print("On average, downloaded " + str((bestResult / urlCount - (unconditionalDownloadSize + threshold)) / averageGlyphSize) + " glyphs per URL")
print("On average, downloaded " + str(100 * (bestResult / urlCount - (unconditionalDownloadSize + threshold)) / averageGlyphSize / glyphCount) + "% of glyph data per URL")
