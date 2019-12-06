import hyperopt
import objc

# FIXME: Consider computing these files here with pyobjc-framework-CoreText

unconditionalDownloadSize = 282828
averageGlyphSize = 170.084
threshold = 8 * 170

bundle = objc.loadBundle("OptimizeFramework", globals(), bundle_path="/Users/litherum/Build/Products/Release/OptimizeFramework.framework")
CostFunction = bundle.classNamed_("CostFunction")
print("Initializing...")
function = CostFunction.alloc().init()
function.loadData()
urlCount = function.urlCount()
glyphCount = function.glyphCount()
function.createResources()
print("Initialized.")
print("Using " + function.deviceName())
print(str(urlCount) + " urls.")
print(str(glyphCount) + " glyphs.")

def objective(args):
    items = sorted([(i, args[i]) for i in range(len(args))], key=lambda x:x[1])
    return function.calculate_([i[0] for i in items])

space = [hyperopt.hp.uniform("glyph " + str(i), 0, glyphCount) for i in range(glyphCount)]

print("Starting optimization...")
best = hyperopt.fmin(objective, space, algo=hyperopt.tpe.suggest, max_evals=100)
print("Optimization complete.")
bestArgs = hyperopt.space_eval(space, best)
bestResult = objective(bestArgs)

print(best)
print(bestArgs)
print("On average, downloaded " + str(bestResult / urlCount) + " bytes per url")
print("On average, downloaded " + str((bestResult / urlCount - (unconditionalDownloadSize + threshold)) / averageGlyphSize) + " glyphs per URL")
print("On average, downloaded " + str(100 * (bestResult / urlCount - (unconditionalDownloadSize + threshold)) / averageGlyphSize / glyphCount) + "% of glyph data per URL")
