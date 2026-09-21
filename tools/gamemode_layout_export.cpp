// Exports the installed game's classified game-mode layout through libbf6.
// The resulting manifest retains both the lossless source row and the
// classifier's role, geometry, flag association, and provenance.
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <map>
#include <ostream>
#include <string>
#include <tuple>
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

static void raw_element(std::ostream& out, const bf6_gm_entity& r)
{
    out << "{\"gem\":"; text(out, r.gem_link);
    out << ",\"selector\":" << r.gem_value
        << ",\"team\":" << r.team
        << ",\"enabled\":" << (r.enabled ? "true" : "false")
        << ",\"root_order\":" << r.root_order
        << ",\"instance\":" << r.instance
        << ",\"instance_guid\":"; text(out, r.instance_guid);
    out << ",\"layer\":"; text(out, r.layer);
    out << ",\"partition\":"; text(out, r.partition);
    out << ",\"transform\":"; floats(out, r.xform, 12);
    out << ",\"shape\":"; text(out, r.gem_shape);
    out << ",\"shape_property\":" << r.gem_shape_property
        << ",\"links\":[";
    for (int i = 0; i < r.link_count; ++i) {
        if (i) out << ',';
        out << "{\"target\":" << r.links[i]
            << ",\"source_field\":" << r.link_fields[i] << '}';
    }
    out << "]}";
}

static std::string ebx_name(const char* value)
{
    std::string result = value ? value : "";
    if (result.size() > 4 && result.compare(result.size() - 4, 4, ".ebx") == 0)
        result.resize(result.size() - 4);
    return result;
}

struct Point3 { float x, y, z; };
struct ShapeTransform {
    Point3 p{0, 0, 0};
    float q[4]{0, 0, 0, 1};
    float basis[9]{1, 0, 0, 0, 1, 0, 0, 0, 1};
    bool direct_basis = false;
};
struct PointKey {
    int x, z;
    bool operator<(const PointKey& other) const { return std::tie(x, z) < std::tie(other.x, other.z); }
    bool operator==(const PointKey& other) const { return x == other.x && z == other.z; }
    bool operator!=(const PointKey& other) const { return !(*this == other); }
};
struct EdgeKey {
    PointKey a, b;
    bool operator<(const EdgeKey& other) const { return std::tie(a, b) < std::tie(other.a, other.b); }
};

static PointKey point_key(const Point3& p)
{
    return {(int)std::lround(p.x * 1000.f), (int)std::lround(p.z * 1000.f)};
}

static Point3 rotate_point(const float q[4], const Point3& p)
{
    const Point3 u{q[0], q[1], q[2]};
    const float s = q[3];
    const float dot = u.x * p.x + u.y * p.y + u.z * p.z;
    const float uu = u.x * u.x + u.y * u.y + u.z * u.z;
    const Point3 cross{u.y * p.z - u.z * p.y,
                       u.z * p.x - u.x * p.z,
                       u.x * p.y - u.y * p.x};
    return {2.f * dot * u.x + (s * s - uu) * p.x + 2.f * s * cross.x,
            2.f * dot * u.y + (s * s - uu) * p.y + 2.f * s * cross.y,
            2.f * dot * u.z + (s * s - uu) * p.z + 2.f * s * cross.z};
}

static bool generated_shape_transforms(bf6_ctx* context, const std::string& name,
                                       int expected, const float* fallback_xform,
                                       std::vector<ShapeTransform>& result)
{
    bf6_schematic* graph = bf6_partition_graph_read(context, name.c_str());
    if (!graph) return false;
    result.assign((size_t)expected, ShapeTransform{});
    /* A one-hull generated asset omits the aggregate child-transform node; its
     * collision vertices are already in the shape asset's authored space. */
    if (expected == 1 && graph->node_count == 1) {
        for (int i = 0; i < 9; ++i) result[0].basis[i] = fallback_xform[i];
        result[0].p = {fallback_xform[9], fallback_xform[10], fallback_xform[11]};
        result[0].direct_basis = true;
        bf6_free(context, graph);
        return true;
    }
    std::vector<unsigned char> have_pos((size_t)expected, 0);
    for (int fi = 0; fi < graph->field_count; ++fi) {
        const bf6_schem_field& f = graph->fields[fi];
        if (f.value_kind != BF6_SCHEM_VALUE_REAL || f.path_depth < 3 ||
            f.path_hashes[0] != 0xc8c9b6bf || f.array_indices[0] < 0 ||
            f.array_indices[0] >= expected) continue;
        const int index = f.array_indices[0];
        float* target = nullptr;
        if (f.path_hashes[1] == 0xa4862c49) {
            if (f.path_hashes[2] == 0x3901db14) target = &result[(size_t)index].p.x;
            else if (f.path_hashes[2] == 0x42fc0f5e) target = &result[(size_t)index].p.y;
            else if (f.path_hashes[2] == 0x32a99b9c) target = &result[(size_t)index].p.z;
            if (target) have_pos[(size_t)index] |= (f.path_hashes[2] == 0x3901db14 ? 1 :
                f.path_hashes[2] == 0x42fc0f5e ? 2 : 4);
        } else if (f.path_hashes[1] == 0x71f50735) {
            if (f.path_hashes[2] == 0x3901db14) target = &result[(size_t)index].q[0];
            else if (f.path_hashes[2] == 0x42fc0f5e) target = &result[(size_t)index].q[1];
            else if (f.path_hashes[2] == 0x32a99b9c) target = &result[(size_t)index].q[2];
            else if (f.path_hashes[2] == 0x7c8062f2) target = &result[(size_t)index].q[3];
        }
        if (target) *target = (float)f.real_value;
    }
    bf6_free(context, graph);
    for (unsigned char mask : have_pos) if (mask != 7) return false;
    return true;
}

/* Generated VectorShapeAssets store an aggregate PhysicsResource. Each child
 * hull is one exact convex decomposition piece and c8c9b6bf stores its authored
 * transform. Shared decomposition edges cancel exactly; the remaining loop is
 * the authored exterior. Failure is returned rather than spatially guessing. */
static bool generated_shape_boundary(bf6_ctx* context, const std::string& name,
                                     const float* fallback_xform,
                                     std::vector<float>& points, float& height)
{
    bf6_physics* physics = bf6_physics_read(context, name.c_str());
    if (!physics || physics->shape_count <= 0) {
        std::fprintf(stderr, "capture shape %s: missing physics shapes\n", name.c_str());
        if (physics) bf6_free(context, physics);
        return false;
    }
    std::vector<ShapeTransform> transforms;
    if (!generated_shape_transforms(context, name, physics->shape_count, fallback_xform,
                                    transforms)) {
        std::fprintf(stderr, "capture shape %s: child transform count does not match %d hulls\n",
                     name.c_str(), physics->shape_count);
        bf6_free(context, physics); return false;
    }
    std::map<EdgeKey, int> edge_counts;
    std::map<PointKey, Point3> authored;
    float min_y = INFINITY, max_y = -INFINITY;
    for (int si = 0; si < physics->shape_count; ++si) {
        const bf6_phys_shape& shape = physics->shapes[si];
        if (shape.vertex_first < 0 || shape.vertex_count < 6 || (shape.vertex_count & 1)) {
            std::fprintf(stderr, "capture shape %s: unsupported hull %d (%u vertices)\n",
                         name.c_str(), si, (unsigned)shape.vertex_count);
            bf6_free(context, physics); return false;
        }
        std::vector<Point3> lower;
        const ShapeTransform& transform = transforms[(size_t)si];
        for (int vi = 0; vi < shape.vertex_count; ++vi) {
            const int at = (shape.vertex_first + vi) * 3;
            Point3 local{physics->vertices[at], physics->vertices[at + 1],
                         physics->vertices[at + 2]};
            Point3 world = transform.direct_basis ? Point3{
                transform.basis[0] * local.x + transform.basis[3] * local.y + transform.basis[6] * local.z,
                transform.basis[1] * local.x + transform.basis[4] * local.y + transform.basis[7] * local.z,
                transform.basis[2] * local.x + transform.basis[5] * local.y + transform.basis[8] * local.z}
                : rotate_point(transform.q, local);
            world.x += transform.p.x; world.y += transform.p.y; world.z += transform.p.z;
            min_y = std::min(min_y, world.y); max_y = std::max(max_y, world.y);
            if (vi < shape.vertex_count / 2) lower.push_back(world);
        }
        for (size_t vi = 0; vi < lower.size(); ++vi) {
            PointKey a = point_key(lower[vi]);
            PointKey b = point_key(lower[(vi + 1) % lower.size()]);
            authored[a] = lower[vi]; authored[b] = lower[(vi + 1) % lower.size()];
            EdgeKey edge{a < b ? a : b, a < b ? b : a};
            ++edge_counts[edge];
        }
    }
    bf6_free(context, physics);
    std::map<PointKey, std::vector<PointKey>> neighbours;
    int boundary_edges = 0;
    for (const auto& item : edge_counts) {
        if (item.second != 1) continue;
        neighbours[item.first.a].push_back(item.first.b);
        neighbours[item.first.b].push_back(item.first.a);
        ++boundary_edges;
    }
    if (boundary_edges < 3) return false;
    for (const auto& item : neighbours) if (item.second.size() != 2) {
        std::fprintf(stderr, "capture shape %s: non-manifold projected boundary (%zu neighbours)\n",
                     name.c_str(), item.second.size());
        return false;
    }
    PointKey start = neighbours.begin()->first, previous = start, current = start;
    std::vector<PointKey> loop;
    do {
        loop.push_back(current);
        const std::vector<PointKey>& nexts = neighbours[current];
        PointKey next = (loop.size() == 1 || nexts[0] != previous) ? nexts[0] : nexts[1];
        previous = current; current = next;
        if ((int)loop.size() > boundary_edges) return false;
    } while (!(current == start));
    if ((int)loop.size() != boundary_edges) {
        std::fprintf(stderr, "capture shape %s: %d boundary edges form multiple loops\n",
                     name.c_str(), boundary_edges);
        return false;
    }
    const float middle_y = (min_y + max_y) * .5f;
    points.clear(); points.reserve(loop.size() * 3);
    for (const PointKey& key : loop) {
        const Point3& p = authored[key];
        points.push_back(p.x); points.push_back(middle_y); points.push_back(p.z);
    }
    height = max_y - min_y;
    return height > 0.f;
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
    if (!bf6_mount_all(context, 1, error, sizeof(error))) {
        std::fprintf(stderr, "mount failed: %s\n", error); bf6_close(context); return 1;
    }

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
    out << "{\n  \"schema\":4,\n  \"source\":{\"kind\":\"installed_bf6\",\"level\":";
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
        out << ",\"owner_type\":"; text(out, r.owner_type);
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
        out << ",\"gem_selector\":" << r.gem_value << '}';
        if (role == 101) {
            for (int link = 0; link < r.link_count; ++link) {
                if (r.link_fields[link] != 0xD7DAD1C4u) continue;
                const int target_index = r.links[link];
                if (target_index < 0 || target_index >= raw_count) continue;
                const bf6_gm_entity& target = raw[(size_t)target_index];
                if (target.kind != BF6_GM_OBB && target.kind != BF6_GM_CYLINDER) continue;
                out << ",\"protection_shape\":{\"instance_guid\":";
                text(out, target.instance_guid);
                out << ",\"partition\":"; text(out, target.partition);
                out << ",\"kind\":";
                text(out, target.kind == BF6_GM_CYLINDER ? "cylinder" : "obb");
                out << ",\"source_field\":" << r.link_fields[link]
                    << ",\"transform\":"; floats(out, target.xform, 12);
                out << ",\"half_extents\":"; floats(out, target.half_extents, 3);
                out << '}';
                break;
            }
        }
        out << '}';
        ++extras;
    }
    out << "\n  ],\n  \"elements\":[\n";
    bool first_element = true;
    for (const bf6_gm_entity& r : raw) {
        if (!r.gem_link || !r.mode) continue;
        if (std::strcmp(r.mode, argv[3]) && std::strcmp(r.mode, "__shared")) continue;
        if (!first_element) out << ",\n";
        out << "    "; raw_element(out, r);
        first_element = false;
    }
    /* Capture volumes are not inferred from the loose polygons in the level.
     * A placed gem_capturepoint explicitly binds property 0x5C3A072B to a
     * generated VectorShapeAsset. Read that asset directly and preserve the
     * controller-to-shape identity in the manifest. */
    out << "\n  ],\n  \"capture_shapes\":[\n";
    bool first_capture_shape = true;
    int exact_capture_shapes = 0;
    for (const bf6_gm_entity& r : raw) {
        if (!r.mode || std::strcmp(r.mode, argv[3]) || !r.gem_link ||
            std::strcmp(r.gem_link, "gem_capturepoint") || !r.gem_shape ||
            !*r.gem_shape) continue;
        const std::string shape_name = ebx_name(r.gem_shape);
        bf6_vector_shapes* shapes = bf6_vector_shapes_read(context, shape_name.c_str());
        if (!shapes || shapes->count == 0) {
            if (shapes) bf6_free(context, shapes);
            std::vector<float> boundary;
            float height = 0.f;
            if (!generated_shape_boundary(context, shape_name, r.xform, boundary, height)) {
                std::fprintf(stderr, "capture shape %s: exact boundary unavailable\n",
                             shape_name.c_str());
                continue;
            }
            if (!first_capture_shape) out << ",\n";
            first_capture_shape = false;
            out << "    {\"controller_instance_guid\":"; text(out, r.instance_guid);
            out << ",\"controller_partition\":"; text(out, r.partition);
            out << ",\"controller_root_order\":" << r.root_order
                << ",\"flag\":" << (!std::strcmp(argv[3], "conquest") ?
                    conquest_flag_for_root(argv[2], r.root_order) : -1)
                << ",\"shape_asset\":"; text(out, r.gem_shape);
            out << ",\"shape_property\":" << r.gem_shape_property
                << ",\"shape_index\":0,\"world_points\":";
            floats(out, boundary.data(), (int)boundary.size());
            out << ",\"height\":" << height
                << ",\"flags\":0,\"realm\":0"
                << ",\"binding\":\"installed_gem_instance_parameter_generated_vector_shape\"}";
            ++exact_capture_shapes;
            continue;
        }
        for (int shape_index = 0; shape_index < shapes->count; ++shape_index) {
            const bf6_vector_shape& shape = shapes->shapes[shape_index];
            if (!shape.is_volume || shape.point_count < 3 || !shape.points) continue;
            if (!first_capture_shape) out << ",\n";
            first_capture_shape = false;
            out << "    {\"controller_instance_guid\":"; text(out, r.instance_guid);
            out << ",\"controller_partition\":"; text(out, r.partition);
            out << ",\"controller_root_order\":" << r.root_order
                << ",\"flag\":" << (!std::strcmp(argv[3], "conquest") ?
                    conquest_flag_for_root(argv[2], r.root_order) : -1)
                << ",\"shape_asset\":"; text(out, r.gem_shape);
            out << ",\"shape_property\":" << r.gem_shape_property
                << ",\"shape_index\":" << shape_index
                << ",\"world_points\":";
            floats(out, shape.points, shape.point_count * 3);
            out << ",\"height\":" << shape.height
                << ",\"flags\":" << shape.flags
                << ",\"realm\":" << shape.realm
                << ",\"binding\":\"installed_gem_instance_parameter_vector_shape\"}";
            ++exact_capture_shapes;
        }
        bf6_free(context, shapes);
    }
    out << "\n  ],\n  \"counts\":{\"objects\":" << layout.objects
        << ",\"spawns\":" << layout.spawns << ",\"captures\":" << layout.captures
        << ",\"zones\":" << layout.zones << ",\"combat\":" << layout.combat
        << ",\"obbs\":" << layout.obbs << ",\"vehicles\":" << layout.vehicles
        << ",\"resupply\":" << layout.resupply << ",\"mcoms\":" << layout.mcoms
        << ",\"bombs\":" << layout.bombs << ",\"specialareas\":" << layout.specialareas
        << ",\"slots\":" << layout.slots << ",\"unlinked\":" << layout.unlinked
        << ",\"exact_capture_shapes\":" << exact_capture_shapes
        << ",\"extra_hq_aa\":" << extras << ",\"dropped\":" << (layout.dropped_junk + layout.dropped_owned +
             layout.dropped_prop_box + layout.dropped_gem_other + layout.dropped_dup +
             layout.dropped_twin + layout.dropped_other) << "}\n}\n";
    out.close();
    bf6_close(context);
    std::printf("wrote %d classified %s/%s objects to %s\n", count, argv[2], argv[3], argv[4]);
    return 0;
}
