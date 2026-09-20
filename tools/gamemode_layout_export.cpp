// Exports the installed game's classified game-mode layout through libbf6.
// The resulting manifest retains both the lossless source row and the
// classifier's role, geometry, flag association, and provenance.
#include <cmath>
#include <cstdio>
#include <cstring>
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

static int conquest_flag_for_root(const char* level, int root)
{
    struct Mapping { const char* level; int root; int flag; };
    static const Mapping mappings[] = {
        {"mp_abbasid",1,0},{"mp_abbasid",2,1},{"mp_abbasid",3,2},{"mp_abbasid",4,3},{"mp_abbasid",5,4},
        {"mp_aftermath",19,0},{"mp_aftermath",20,1},{"mp_aftermath",21,2},{"mp_aftermath",0,3},{"mp_aftermath",22,4},
        {"mp_aftermath_portal",19,0},{"mp_aftermath_portal",20,1},{"mp_aftermath_portal",21,2},{"mp_aftermath_portal",0,3},{"mp_aftermath_portal",22,4},
        {"mp_atoll",2,0},{"mp_atoll",3,1},{"mp_atoll",4,2},{"mp_atoll",5,3},{"mp_atoll",6,4},{"mp_atoll",23,5},{"mp_atoll",24,6},
        {"mp_badlands",3,0},{"mp_badlands",4,1},{"mp_badlands",5,2},{"mp_badlands",6,3},{"mp_badlands",27,4},{"mp_badlands",28,5},
        {"mp_battery",3,0},{"mp_battery",4,1},{"mp_battery",5,2},{"mp_battery",6,3},{"mp_battery",7,4},
        {"mp_capstone",3,0},{"mp_capstone",4,1},{"mp_capstone",5,2},{"mp_capstone",6,3},{"mp_capstone",7,4},{"mp_capstone",25,5},
        {"mp_contaminated",3,0},{"mp_contaminated",7,1},{"mp_contaminated",4,2},{"mp_contaminated",47,3},{"mp_contaminated",6,4},{"mp_contaminated",5,5},
        {"mp_dumbo",18,0},{"mp_dumbo",17,1},{"mp_dumbo",3,2},{"mp_dumbo",4,3},{"mp_dumbo",16,4},
        {"mp_eastwood",3,0},{"mp_eastwood",4,1},{"mp_eastwood",5,2},{"mp_eastwood",6,3},{"mp_eastwood",7,4},
        {"mp_firestorm",1,0},{"mp_firestorm",2,1},{"mp_firestorm",3,2},{"mp_firestorm",4,3},{"mp_firestorm",5,4},
        {"mp_golmudrailway",3,0},{"mp_golmudrailway",4,1},{"mp_golmudrailway",5,2},{"mp_golmudrailway",6,3},{"mp_golmudrailway",7,4},{"mp_golmudrailway",24,5},{"mp_golmudrailway",25,6},
        {"mp_isolated",3,0},{"mp_isolated",4,1},{"mp_isolated",69,2},{"mp_isolated",5,3},{"mp_isolated",6,4},{"mp_isolated",7,5},{"mp_isolated",70,6},{"mp_isolated",45,7},{"mp_isolated",44,8},
        {"mp_outskirts",3,0},{"mp_outskirts",4,1},{"mp_outskirts",5,2},{"mp_outskirts",6,3},{"mp_outskirts",7,4},
        {"mp_plaza",3,0},{"mp_plaza",4,1},{"mp_plaza",5,2},{"mp_plaza",6,3},{"mp_plaza",7,4},
        {"mp_subsurface",3,0},{"mp_subsurface",4,1},{"mp_subsurface",5,2},{"mp_subsurface",6,3},{"mp_subsurface",7,4},
        {"mp_tungsten",3,0},{"mp_tungsten",4,1},{"mp_tungsten",6,2},{"mp_tungsten",5,3},{"mp_tungsten",23,4},
    };
    for (const Mapping& mapping : mappings)
        if (!std::strcmp(level, mapping.level) && root == mapping.root) return mapping.flag;
    return -1;
}

static bool polygon_contains_xz(const bf6_gm_object& object, float x, float z)
{
    if (!object.world_points || object.point_count < 3) return false;
    bool inside = false;
    for (int i = 0, j = object.point_count - 1; i < object.point_count; j = i++) {
        const float xi = object.world_points[i * 3], zi = object.world_points[i * 3 + 2];
        const float xj = object.world_points[j * 3], zj = object.world_points[j * 3 + 2];
        if (((zi > z) != (zj > z)) &&
            (x < (xj - xi) * (z - zi) / (zj - zi) + xi)) inside = !inside;
    }
    return inside;
}

static const char* conquest_polygon_override(const char* level, int flag)
{
    /* Golmud E overlaps a larger sector polygon whose centre is closer to the
     * capturepoint. The smaller game polygon matches the audited capture area. */
    if (!std::strcmp(level, "mp_golmudrailway") && flag == 4)
        return "36d4f960-d137-46b8-b862-558941af3393";
    return nullptr;
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

    /* The classifier deliberately starts with geometric heuristics. For the
     * supported Conquest maps, replace that provisional result with the
     * installed partition's gem_capturepoint identities. Community templates
     * are used only to audit root-to-letter naming; every emitted position,
     * polygon, spawn and raw identity remains installed-game data. */
    std::vector<std::string> adjusted_labels((size_t)count);
    std::vector<const bf6_gm_entity*> capture_sources((size_t)count, nullptr);
    std::vector<float> capture_binding_distance((size_t)count, -1.f);
    std::vector<std::string> capture_binding_methods((size_t)count);
    if (!std::strcmp(argv[3], "conquest")) {
        struct RootPoint { const bf6_gm_entity* row; int flag; };
        std::vector<RootPoint> roots;
        for (const bf6_gm_entity& row : raw) {
            if (!row.mode || std::strcmp(row.mode, "conquest") || !row.gem_link ||
                std::strcmp(row.gem_link, "gem_capturepoint")) continue;
            const int flag = conquest_flag_for_root(argv[2], row.root_order);
            if (flag >= 0) roots.push_back({&row, flag});
        }
        if (!roots.empty()) {
            std::vector<int> matched((size_t)count, -1);
            std::vector<int> old_to_retail(32, -1);
            for (const RootPoint& root : roots) {
                int best = -1;
                float best_distance = INFINITY;
                float best_area = INFINITY;
                const char* override_guid = conquest_polygon_override(argv[2], root.flag);
                for (int i = 0; i < count; ++i) {
                    const bf6_gm_object& object = objects[(size_t)i];
                    if (matched[(size_t)i] >= 0 ||
                        (object.role != BF6_GMR_CAPTURE && object.role != BF6_GMR_ZONE) ||
                        object.area_m2 < 250.f || object.area_m2 > 20000.f) continue;
                    const bf6_gm_entity& source = raw[(size_t)object.entity];
                    if (root.row->gem_shape && source.shape_asset &&
                        !std::strcmp(root.row->gem_shape, source.shape_asset)) {
                        best = i;
                        const float dx = object.centre[0] - root.row->xform[9];
                        const float dz = object.centre[2] - root.row->xform[11];
                        best_distance = dx * dx + dz * dz;
                        best_area = object.area_m2;
                        break;
                    }
                    if (override_guid && source.instance_guid &&
                        !std::strcmp(source.instance_guid, override_guid)) {
                        best = i;
                        best_distance = 0.f;
                        best_area = object.area_m2;
                        break;
                    }
                    const float dx = object.centre[0] - root.row->xform[9];
                    const float dz = object.centre[2] - root.row->xform[11];
                    const float distance = dx * dx + dz * dz;
                    const bool contains = polygon_contains_xz(
                        object, root.row->xform[9], root.row->xform[11]);
                    const float ranked = distance + (contains ? 0.f : 2500.f);
                    const float best_ranked = best_distance +
                        (best >= 0 && polygon_contains_xz(objects[(size_t)best],
                            root.row->xform[9], root.row->xform[11]) ? 0.f : 2500.f);
                    if (ranked < best_ranked - .01f ||
                        (std::fabs(ranked - best_ranked) <= .01f && object.area_m2 < best_area)) {
                        best = i;
                        best_distance = distance;
                        best_area = object.area_m2;
                    }
                }
                if (best < 0 || best_distance > 100.f * 100.f) continue;
                bf6_gm_object& object = objects[(size_t)best];
                if (object.flag >= 0 && object.flag < (int)old_to_retail.size())
                    old_to_retail[(size_t)object.flag] = root.flag;
                if (object.role == BF6_GMR_ZONE) ++layout.big_flag_rescued;
                matched[(size_t)best] = root.flag;
                capture_sources[(size_t)best] = root.row;
                capture_binding_distance[(size_t)best] = std::sqrt(best_distance);
                const bf6_gm_entity& matched_source = raw[(size_t)object.entity];
                capture_binding_methods[(size_t)best] =
                    root.row->gem_shape && matched_source.shape_asset &&
                    !std::strcmp(root.row->gem_shape, matched_source.shape_asset)
                    ? "installed_gem_shape_asset_identity"
                    : "installed_gem_to_nearest_containing_polygon";
            }

            for (int i = 0; i < count; ++i) {
                bf6_gm_object& object = objects[(size_t)i];
                if (object.role != BF6_GMR_CAPTURE && object.role != BF6_GMR_ZONE) continue;
                if (matched[(size_t)i] < 0) {
                    if (object.role == BF6_GMR_CAPTURE) {
                        object.role = BF6_GMR_ZONE;
                        object.flag = -1;
                        adjusted_labels[(size_t)i] = "Zone";
                        object.label = adjusted_labels[(size_t)i].c_str();
                    }
                    continue;
                }
                object.role = BF6_GMR_CAPTURE;
                object.flag = matched[(size_t)i];
                /* A capture GEM and its polygon are distinct authored records.
                 * The SDK node belongs at the GEM transform (including its
                 * authored height); its child volume keeps the polygon's
                 * world points and is rebased by the Godot builder. */
                if (capture_sources[(size_t)i]) {
                    object.centre[0] = capture_sources[(size_t)i]->xform[9];
                    object.centre[1] = capture_sources[(size_t)i]->xform[10];
                    object.centre[2] = capture_sources[(size_t)i]->xform[11];
                }
                adjusted_labels[(size_t)i] = std::string("Flag ") + char('A' + object.flag);
                object.label = adjusted_labels[(size_t)i].c_str();
            }

            for (int i = 0; i < count; ++i) {
                bf6_gm_object& spawn = objects[(size_t)i];
                if (spawn.role != BF6_GMR_SPAWN) continue;
                int retail = spawn.flag >= 0 && spawn.flag < (int)old_to_retail.size()
                    ? old_to_retail[(size_t)spawn.flag] : -1;
                if (retail < 0) {
                    float nearest = 30.f * 30.f;
                    for (int j = 0; j < count; ++j) {
                        if (matched[(size_t)j] < 0) continue;
                        const bf6_gm_object& capture = objects[(size_t)j];
                        const float dx = spawn.centre[0] - capture.centre[0];
                        const float dy = spawn.centre[1] - capture.centre[1];
                        const float dz = spawn.centre[2] - capture.centre[2];
                        const float distance = dx * dx + dy * dy + dz * dz;
                        if (distance <= nearest) { nearest = distance; retail = matched[(size_t)j]; }
                    }
                }
                spawn.flag = retail;
                adjusted_labels[(size_t)i] = retail >= 0
                    ? std::string("Flag ") + char('A' + retail) + " Spawn"
                    : "Spawn Point";
                spawn.label = adjusted_labels[(size_t)i].c_str();
            }

            layout.captures = 0;
            layout.zones = 0;
            for (const bf6_gm_object& object : objects) {
                if (object.role == BF6_GMR_CAPTURE) ++layout.captures;
                else if (object.role == BF6_GMR_ZONE) ++layout.zones;
            }
        }
    }

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
        if (capture_sources[(size_t)i]) {
            const bf6_gm_entity& cp = *capture_sources[(size_t)i];
            out << ",\"capture_binding\":{\"method\":";
            text(out, capture_binding_methods[(size_t)i].c_str());
            out
                << ",\"distance_m\":" << capture_binding_distance[(size_t)i]
                << ",\"instance_guid\":"; text(out, cp.instance_guid);
            out << ",\"partition\":"; text(out, cp.partition);
            out << ",\"root_order\":" << cp.root_order << ",\"transform\":";
            floats(out, cp.xform, 12);
            out << ",\"gem_shape\":"; text(out, cp.gem_shape);
            out << ",\"gem_shape_property\":" << cp.gem_shape_property;
            out << '}';
        }
        out << ",\"raw\":{\"kind\":" << r.kind << ",\"type\":"; text(out, r.type_name);
        out << ",\"layer\":"; text(out, r.layer);
        out << ",\"partition\":"; text(out, r.partition);
        out << ",\"instance\":" << r.instance << ",\"root_order\":" << r.root_order
            << ",\"instance_guid\":"; text(out, r.instance_guid);
        out << ",\"blueprint\":"; text(out, r.blueprint);
        out << ",\"transform\":"; floats(out, r.xform, 12);
        if (r.kind == BF6_GM_OBB) { out << ",\"half_extents\":"; floats(out, r.half_extents, 3); }
        out << ",\"gem_blueprint\":"; text(out, r.gem_link);
        out << ",\"gem_selector\":" << r.gem_value;
        out << ",\"gem_shape\":"; text(out, r.gem_shape);
        out << ",\"gem_shape_property\":" << r.gem_shape_property;
        out << ",\"shape_asset\":"; text(out, r.shape_asset);
        out << "}}";
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
