package com.hamxanadeem.snapdoc.core

/** The size and colour layout of a JPEG, read from its frame header. */
data class JpegInfo(val width: Int, val height: Int, val components: Int) {

    companion object {
        /**
         * Reads the first start-of-frame marker of [jpeg]. Returns null if the
         * bytes are not a JPEG or the header is missing or cut short.
         */
        fun read(jpeg: ByteArray): JpegInfo? {
            if (jpeg.size < 4 || u8(jpeg, 0) != 0xFF || u8(jpeg, 1) != 0xD8) return null
            var i = 2
            while (i + 4 <= jpeg.size) {
                if (u8(jpeg, i) != 0xFF) return null
                val marker = u8(jpeg, i + 1)
                // Padding bytes and markers without a length.
                if (marker == 0xFF) {
                    i++
                    continue
                }
                if (marker == 0xD8 || marker == 0x01 || marker in 0xD0..0xD7) {
                    i += 2
                    continue
                }
                if (marker == 0xD9 || marker == 0xDA) return null
                val length = (u8(jpeg, i + 2) shl 8) or u8(jpeg, i + 3)
                if (length < 2) return null
                val isFrame = marker in 0xC0..0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
                if (isFrame) {
                    if (i + 9 >= jpeg.size) return null
                    val height = (u8(jpeg, i + 5) shl 8) or u8(jpeg, i + 6)
                    val width = (u8(jpeg, i + 7) shl 8) or u8(jpeg, i + 8)
                    val components = u8(jpeg, i + 9)
                    if (width <= 0 || height <= 0) return null
                    return JpegInfo(width, height, components)
                }
                i += 2 + length
            }
            return null
        }

        private fun u8(b: ByteArray, i: Int): Int = b[i].toInt() and 0xFF
    }
}
