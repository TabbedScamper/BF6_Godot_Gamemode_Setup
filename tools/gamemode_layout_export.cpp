// Exports the installed game's classified game-mode layout through libbf6.
// The resulting manifest retains both the lossless source row and the
// classifier's role, geometry, flag association, and provenance.
#include <cstdio>
#include <fstream>
#include <iomanip>
#include <ostream>
#include <string>
#include <vector>
#include "bf6_core.h"

static void text(std::ostream& out, const char* value)
{
    if (!value) { out << "null"; return; }
    out << '"';
    for (const unsigned char c : std::string(value)) {
        switch (c) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default: if (c < 0x20) out << '?'; else out << (char)c;
        }
    }
    out << '"';
}

static void floats(std::ostream& out, const float* value, int count)
{
    out << '[';
    for (int i = 0; i < count; ++i) { if (i) out << ','; out << value[i]; }
    out << ']';
}

int main(int argc, char** argv)
{
    if (argc != 5) {
        std::fprintf(stderr, "usage: gamemode_layout_export <game-dir> <level> <mode> <output.json>\n");
        return 2;
    }
    char error[512] = {};
    bf6_ctx* context = bf6_open(argv[1], error, sizeof(error));
    if (!context) { std::fprintf(stderr, "open failed: %s\n", error); return 1; }

    bf6_gm_stats raw_stats{};
    const int raw_count = bf6_level_gamemodes(context, argv[2], nullptr, 0,
                                               &raw_stats, error, sizeof(error));
    if (raw_count <= 0) {
        std::fprintf(stderr, "read failed: %s\n", error); bf6_close(context); return 1;
    }
    std::vector<bf6_gm_entity> raw((size_t)raw_count);
    bf6_level_gamemodes(context, argv[2], raw.data(), raw_count, nullptr,
                        error, sizeof(error));

    bf6_gm_layout layout{};
    const int count = bf6_level_gamemode_layout(context, argv[2], argv[3],
                                                 nullptr, 0, &layout,
                                                 error, sizeof(error));
    if (count <= 0) {
        std::fprintf(stderr, "layout failed: %s\n", error); bf6_close(context); return 1;
    }
    std::vector<bf6_gm_object> objects((size_t)count);
    bf6_level_gamemode_layout(context, argv[2], argv[3], objects.data(), count,
                              &layout, error, sizeof(error));

    std::ofstream out(argv[4], std::ios::binary);
    if (!out) { std::fprintf(stderr, "cannot write %s\n", argv[4]); bf6_close(context); return 1; }
    out << std::setprecision(9);
    out << "{\n  \"schema\":2,\n  \"source\":{\"kind\":\"installed_bf6\",\"level\":";
    text(out, argv[2]); out << ",\"mode\":"; text(out, argv[3]); out << "},\n";
    out << "  \"objects\":[\n";
    for (int i = 0; i < count; ++i) {
        if (i) out << ",\n";
        const bf6_gm_object& o = objects[(size_t)i];
        const bf6_gm_entity& r = raw[(size_t)o.entity];
        out << "    {\"role\":" << o.role << ",\"label\":"; text(out, o.label);
        out << ",\"flag\":" << o.flag << ",\"team\":" << o.team
            << ",\"area_m2\":" << o.area_m2 << ",\"centre\":";
        floats(out, o.centre, 3);
        out << ",\"height\":" << o.height
            << ",\"stationary\":" << (o.stationary ? "true" : "false")
            << ",\"by_data\":" << (o.by_data ? "true" : "false")
            << ",\"water\":" << (o.water ? "true" : "false")
            << ",\"gem_link\":"; text(out, o.gem_link);
        out << ",\"gem_value\":" << o.gem_value;
        if (o.point_count > 0) {
            out << ",\"world_points\":"; floats(out, o.world_points, o.point_count * 3);
        }
        if (o.has_ground) out << ",\"ground_y\":" << o.ground_y;
        if (o.has_land) { out << ",\"land\":"; floats(out, o.land, 3); }
        out << ",\"raw\":{\"kind\":" << r.kind << ",\"type\":"; text(out, r.type_name);
        out << ",\"layer\":"; text(out, r.layer);
        out << ",\"partition\":"; text(out, r.partition);
        out << ",\"instance\":" << r.instance << ",\"root_order\":" << r.root_order
            << ",\"instance_guid\":"; text(out, r.instance_guid);
        out << ",\"blueprint\":"; text(out, r.blueprint);
        out << ",\"transform\":"; floats(out, r.xform, 12);
        if (r.kind == BF6_GM_OBB) { out << ",\"half_extents\":"; floats(out, r.half_extents, 3); }
        out << ",\"gem_blueprint\":"; text(out, r.gem_link);
        out << ",\"gem_selector\":" << r.gem_value << "}}";
    }
    int extras = 0;
    for (int i = 0; i < raw_count; ++i) {
        const bf6_gm_entity& r = raw[(size_t)i];
        if (!r.mode || std::string(r.mode) != argv[3] || !r.gem_link) continue;
        const std::string link(r.gem_link);
        const int role = link == "gem_hq" ? 100 : (link == "gem_automaticaa" ? 101 : 0);
        if (!role) continue;
        out << ",\n    {\"role\":" << role << ",\"label\":";
        text(out, role == 100 ? "HQ" : "Automatic AA");
        out << ",\"flag\":-1,\"team\":" << r.team
            << ",\"centre\":[" << r.xform[9] << ',' << r.xform[10] << ',' << r.xform[11]
            << "],\"raw\":{\"kind\":" << r.kind << ",\"type\":"; text(out, r.type_name);
        out << ",\"layer\":"; text(out, r.layer);
        out << ",\"partition\":"; text(out, r.partition);
        out << ",\"instance\":" << r.instance << ",\"root_order\":" << r.root_order
            << ",\"instance_guid\":"; text(out, r.instance_guid);
        out << ",\"blueprint\":"; text(out, r.blueprint);
        out << ",\"transform\":"; floats(out, r.xform, 12);
        out << ",\"gem_blueprint\":"; text(out, r.gem_link);
        out << ",\"gem_selector\":" << r.gem_value << "}}";
        ++extras;
    }
    out << "\n  ],\n  \"counts\":{\"objects\":" << layout.objects
        << ",\"spawns\":" << layout.spawns << ",\"captures\":" << layout.captures
        << ",\"zones\":" << layout.zones << ",\"combat\":" << layout.combat
        << ",\"obbs\":" << layout.obbs << ",\"vehicles\":" << layout.vehicles
        << ",\"resupply\":" << layout.resupply << ",\"mcoms\":" << layout.mcoms
        << ",\"bombs\":" << layout.bombs << ",\"specialareas\":" << layout.specialareas
        << ",\"slots\":" << layout.slots << ",\"unlinked\":" << layout.unlinked
        << ",\"extra_hq_aa\":" << extras << ",\"dropped\":" << (layout.dropped_junk + layout.dropped_owned +
             layout.dropped_prop_box + layout.dropped_gem_other + layout.dropped_dup +
             layout.dropped_twin + layout.dropped_other) << "}\n}\n";
    out.close();
    bf6_close(context);
    std::printf("wrote %d classified %s/%s objects to %s\n", count, argv[2], argv[3], argv[4]);
    return 0;
}
