import objc
import hyperopt

bundle = objc.loadBundle("Optimize", globals(), bundle_path="/Users/mmaxfield/Build/Products/Debug/Optimize.framework")
GlyphData = bundle.classNamed_("GlyphData")
glyphData = GlyphData.new()
Seeds = bundle.classNamed_("Seeds")
seeds = Seeds.new().seeds().mutableCopy()
Seeds.fillWithRandomSeeds_withGlyphCount_untilCount_(seeds, glyphData.glyphCount(), 6)
SimulatedAnnealing = bundle.classNamed_("SimulatedAnnealing")


def objective(args):
    simulatedAnnealing = SimulatedAnnealing.alloc().initWithGlyphData_seeds_exponent_maximumSlope_(glyphData, seeds, 0.25, 100000.0)
    return 1 - simulatedAnnealing.simulate()

space = [hyperopt.hp.uniform("exponent", 0, 1), hyperopt.hp.uniform("maximumSlope", 10000, 100000)]
best = hyperopt.fmin(objective, space, algo=hyperopt.tpe.suggest, max_evals=1)
print(best)
print(hyperopt.space_eval(space, best))
#print("Best fitness: " + str(1 - objective(hyperopt.space_eval(space, best))))
