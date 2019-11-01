import hyperopt
import objc
import json

# FIXME: Consider computing these files here with pyobjc-framework-CoreText

#glyphSizesFile = open("/Users/litherum/Documents/output_glyph_sizes.json", "r")
#glyphSizes = json.load(glyphSizesFile)
#
#urlsFile = open("/Users/litherum/Documents/output_glyphs.json", "r")
#urls = json.load(urlsFile)

urlCount = 37451
glyphCount = 8676
unconditionalDownloadSize = 282828
averageGlyphSize = 170.084
threshold = 8 * 170

bundle = objc.loadBundle("OptimizeFramework", globals(), bundle_path="/Users/litherum/Build/Products/Debug/OptimizeFramework.framework")
CostFunction = bundle.classNamed_("CostFunction")
function = CostFunction.alloc().initWithGlyphCount_(glyphCount)
print("Loaded bundle.")

def objective(args):
    items = sorted([(i, args[i]) for i in range(len(args))], key=lambda x:x[1])
    return function.calculate_([i[0] for i in items])

space = [hyperopt.hp.uniform("glyph " + str(i), 0, glyphCount) for i in range(glyphCount)]

best = hyperopt.fmin(objective, space, algo=hyperopt.tpe.suggest, max_evals=100)
bestArgs = hyperopt.space_eval(space, best)
bestResult = objective(bestArgs)

print(best)
print(bestArgs)
print("On average, downloaded " + str(bestResult / urlCount) + " bytes per url")
print("On average, downloaded " + str((bestResult / urlCount - (unconditionalDownloadSize + threshold)) / averageGlyphSize) + " glyphs per URL")
print("On average, downloaded " + str(100 * (bestResult / urlCount - (unconditionalDownloadSize + threshold)) / averageGlyphSize / glyphCount) + "% of glyph data per URL")
