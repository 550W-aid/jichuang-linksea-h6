# PaperPuppet H6 v12 delivery

v12 addresses the art feedback by replacing the rigid rectangle overlay with the supplied 160x270 gold/red Wukong paper-puppet sprite. It is a transparent 4-bit indexed ROM with frame-latched motion, jump, and horizontal sweep actions.

The H6 packer rejects M512 primitives, so the ROM is implemented with supported M4K blocks. H6 pack, route, and bitgen completed successfully. Timing report: WNS/WHS/TNS/THS all `0.000 ns`; RTL simulation passed. No physical board was available, so the release remains `BUILT_NOT_BOARD_VERIFIED`.

Artifact: `PaperPuppet_H6_v12_wukong_m4k_20260806.zip`

JPSK SHA256: `7EF8B4887A3BFB0D99DD685692062518AF177AB169597F18A8B78C92640F3E7C`

ZIP SHA256: `CD8B3F4253989452AB8B9E278C846E7635C195827AC499D1B9EBF2EAC5B30CEA`
