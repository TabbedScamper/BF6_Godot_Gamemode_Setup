#include "bf6_core.h"
#include <cstdio>
#include <cstring>
#include <vector>

int main(int argc, char** argv)
{
    if (argc != 3) {
        std::fprintf(stderr, "usage: gamemode_capture_audit <game-dir> <level>\n");
        return 2;
    }
    char error[512] = {};
    bf6_ctx* context = bf6_open(argv[1], error, sizeof(error));
    if (!context) { std::fprintf(stderr, "open failed: %s\n", error); return 1; }
    const int count = bf6_level_gamemodes(context, argv[2], nullptr, 0, nullptr,
                                           error, sizeof(error));
    std::vector<bf6_gm_entity> rows((size_t)(count > 0 ? count : 0));
    if (count > 0)
        bf6_level_gamemodes(context, argv[2], rows.data(), count, nullptr,
                            error, sizeof(error));
    for (const bf6_gm_entity& row : rows) {
        if (!row.mode || std::strcmp(row.mode, "conquest") || !row.gem_link ||
            std::strcmp(row.gem_link, "gem_capturepoint")) continue;
        std::printf("root=%d instance=%d guid=%s at=(%.3f %.3f %.3f) value=%d layer=%s\n",
                    row.root_order, row.instance,
                    row.instance_guid ? row.instance_guid : "-",
                    row.xform[9], row.xform[10], row.xform[11], row.gem_value,
                    row.layer ? row.layer : "-");
    }
    bf6_close(context);
    return 0;
}
