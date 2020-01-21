import objc
import hyperopt

bundle = objc.loadBundle("Optimize", globals(), bundle_path="/Users/mmaxfield/Build/Products/Debug/Optimize.framework")
GlyphData = bundle.classNamed_("GlyphData")
glyphData = GlyphData.new()
SingleFitness = bundle.classNamed_("SingleFitness")
singleFitness = SingleFitness.alloc().initWithGlyphData_(glyphData)
dimension = singleFitness.dimension()

def objective(args):
    return 1 - singleFitness.computeFitness_([args[i] for i in range(len(args))])

space = [hyperopt.hp.uniform("val " + str(i), -1, 1) for i in range(dimension)]
best = hyperopt.fmin(objective, space, algo=hyperopt.tpe.suggest, max_evals=200)
print("Best fitness: " + str(1 - objective(hyperopt.space_eval(space, best))))

