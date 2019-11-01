import hyperopt
import json

glyphSizesFile = open("/Users/mmaxfield/Build/Products/Debug/output_glyph_sizes.json", "r")
glyphSizes = json.load(glyphSizesFile)

urlsFile = open("/Users/mmaxfield/Build/Products/Debug/output_glyphs.json", "r")
urls = json.load(urlsFile)

threshold = 8 * 170

def objective(args):
    items = sorted([(i, args[i]) for i in range(len(args))], key=lambda x:x[1])
    result = 0
    for url in urls:
        necessaryGlyphs = set(url["Glyphs"])
        results = []
        for item in items:
            glyph = item[0]
            size = glyphSizes[glyph]
            necessary = glyph in necessaryGlyphs
            if necessary:
                if len(results) % 2 == 0:
                    results.append(size)
                else:
                    results[len(results) - 1] += size
            else:
                if len(results) % 2 == 0:
                    if len(results) == 0:
                        results.append(0)
                        results.append(size)
                    else:
                        results[len(results) - 1] += size
                else:
                    results.append(size)
        for i in range(len(results)):
            if i % 2 == 0:
                result += results[i]
            elif i < len(results) - 1:
                result += min(results[i], threshold)
    return result

#glyphCount = 8676
glyphCount = 20
space = [hyperopt.hp.uniform("glyph " + str(glyphCount), 0, glyphCount)] * glyphCount

best = hyperopt.fmin(objective, space, algo=hyperopt.tpe.suggest, max_evals=100)

print(best)
print hyperopt.space_eval(space, best)
