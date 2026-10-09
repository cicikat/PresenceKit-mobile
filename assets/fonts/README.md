# Reference typography assets

Chinese serif: Noto Serif CJK SC Regular, release Serif2.003, upstream commit `9b0f1436e455d902de067a2501422e5dc71ad16b`.

- [Upstream](https://github.com/notofonts/noto-cjk/tree/9b0f1436e455d902de067a2501422e5dc71ad16b/Serif)
- File: NotoSerifCJKsc-Regular.otf
- SHA-256: `2A2EAE2628DF83556C54018C41E20FA532C1B862C5256AE8B3F23FEB918D12CA`
- License: NotoSerifCJK-LICENSE.txt, SIL Open Font License 1.1.

Latin serif: Libre Baskerville, Google Fonts upstream commit `b3d4b3ba7c4d54f15ed2be72d7f58b9097c3b252`. Variable font assets are registered at weight 400; the italic file is registered separately.

- [Upstream](https://github.com/google/fonts/tree/b3d4b3ba7c4d54f15ed2be72d7f58b9097c3b252/ofl/librebaskerville)
- LibreBaskerville-Regular.ttf SHA-256: `05A95421961341C5B2556285E8415DF9DB27DAB4F4ABE22B446B3C6A8B916C5D`
- LibreBaskerville-Italic.ttf SHA-256: `223959683DC73EC4437BD61FABAA4B3F22209E22855FFD3AEE36BA61A5116E97`
- License: LibreBaskerville-OFL.txt, SIL Open Font License 1.1.

Font files retain the upstream bytes; no glyph subsetting, renaming of internal font names or system installation is performed. License notices are included in the application asset bundle. Flutter family aliases are ReferenceSong and ReferenceLatin. User-selected fonts override the reference defaults.
