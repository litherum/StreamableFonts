//
//  SharedShaders.h
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#ifndef SharedShaders_h
#define SharedShaders_h

constant uint32_t glyphBitfieldSize [[function_constant(0)]];

constant constexpr uint32_t fontSize = 1758483;

inline bool glyphIsNecessary(device uint8_t* urlBitmaps, uint urlIndex, uint32_t glyph) {
    return urlBitmaps[glyphBitfieldSize * urlIndex + glyph / 8] & (1 << (glyph % 8));
}

#endif /* SharedShaders_h */
