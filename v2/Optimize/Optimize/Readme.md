# Strategies
- Direct Hyperparameter Optimization
- Gradient Descent
- Pick and Place
- Poisson Algorithm
- Genetic Algorithm
    - With Hyperparameter Optimization
- Particle System
    - With Hyperparameter Optimization
- Least Squares?

# Seeds
- Frequency
- Best buddy of most-recently-placed
- Best buddy of any previously-placed
- Best buddy of `n` most-recently-placed
- Best score, regardless

# Data Flow
| Component | Input | Output |
| --------------|--------|---------|
| `CodepointsToGlyphs` | The font file itself, and `output.json` from the Java tool from Apache Nutch | `output_glyphs.json` and `output_glyph_sizes.json` |
| `Prune` | `output_glyphs.json` and `output_glyph_sizes.json` | `urlGlyphsPruned.json` and `gyphSizesPruned.json` |
| `ScoreBigrams` | `urlGlyphsPruned.json` and `gyphSizesPruned.json` | `bigramScores.json` |
| `SaveSeeds` | `urlGlyphsPruned.json`, `gyphSizesPruned.json`, and `bigramScores.json` | `seeds.json` |
| `PickAndPlace` | `urlGlyphsPruned.json`, `gyphSizesPruned.json`, and `seeds.json` | |
