# Strategies
- Direct Hyperparameter Optimization
- Using Gradient Descent and Simulated Annealing:
    - Pick and Place
- Poisson Algorithm
- Genetic Algorithm
    - With Hyperparameter Optimization
- Particle System
    - With Hyperparameter Optimization
- Least Squares?

# Seeds
- Frequency
- Using bigram scores and word to vec distances
    - Best buddy of most-recently-placed
    - Best buddy of any previously-placed
    - Best buddy of `n` most-recently-placed
    - Best score, regardless
- Project word to vec down to a 1d space
    - Perhaps using Hyperparameter Optimization to construct the projection matrix

# Data Flow
| Component | Input | Output |
| --------------|--------|---------|
| `CodepointsToGlyphs` | The font file itself, and `output.json` from the Java tool from Apache Nutch | `output_glyphs.json` and `output_glyph_sizes.json` |
| `Prune` | `output_glyphs.json` and `output_glyph_sizes.json` | `urlGlyphsPruned.json`, `gyphSizesPruned.json`, and `glyphUnicodeMapping.json` |
| `ScoreBigrams` | `urlGlyphsPruned.json` and `gyphSizesPruned.json` | `BigramScores.json` |
| `SaveSeeds` | `urlGlyphsPruned.json`, `gyphSizesPruned.json`, and `BigramScores.json` | `seeds.json` |
| `SemanticDistances` | `glyphUnicodeMapping.json` and `cc.zh.300.bin` | `glyphVectors.json` and `semanticDistances.json` |
| `PickAndPlace` | `urlGlyphsPruned.json`, `gyphSizesPruned.json`, and `seeds.json` | |
| `GeneticAlgorithm` | `urlGlyphsPruned.json`, `gyphSizesPruned.json`, and `seeds.json` | |
| `ParticleSystem` | `BigramScores.json` | |


