#!/usr/bin/env python3
"""Writes the room scenes in scenes/rooms/ from the definitions at the bottom.

Rooms are whole screen cells (1152 by 648) at the origin, x right, y down.
Every room has a Hull (static hull rectangles with openings at the exits), one
Compartment covering it (with Tint and the state containers), an Exits node,
and whatever lives there. Run from the repository root:

    python3 tools/build_rooms.py
"""
import math, os

CELL_W, CELL_H = 1152, 648
T = 32                      # hull thickness
HULL = "Color(0.1, 0.11, 0.13, 1)"
PLATE = "Color(0.22, 0.19, 0.14, 1)"
SCENERY = "Color(0.16, 0.17, 0.2, 1)"
BRIGHT = "Color(0.85, 0.9, 1, 1)"
HOT = "Color(1, 0.35, 0.2, 1)"
STAR = "Color(0.8, 0.85, 0.95, 1)"

def f(v):
    if isinstance(v, (tuple, list)): return ", ".join(f(x) for x in v)
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, float): return repr(round(v, 3))
    return str(v)

class Room:
    def __init__(self, name, cells, plates_live, floor_y=None):
        self.name = name
        self.w, self.h = cells[0] * CELL_W, cells[1] * CELL_H
        self.plates_live = plates_live
        self.floor_y = float(self.h - T) if floor_y is None else float(floor_y)
        self.ext = {}      # path -> id
        self.subs = []     # sub_resource text
        self.nodes = []    # node text
        self.openings = {"left": [], "right": [], "top": [], "bottom": []}   # ranges cut from hull walls
        self.exits = []    # (name, side, along)
        self.extras_hull = []  # (rect) extra hull blocks: (x, y, w, h)
        self.art = []
        self.state = {}    # container -> list of (kind, data)
        self.floor_segments = None  # None: full floor; else list of (x0, x1)
        self.room_script_name = "room.gd"
        self.sub_ids = 0

    def res(self, path, kind="PackedScene"):
        if path not in self.ext:
            self.ext[path] = (len(self.ext) + 1, kind)
        return 'ExtResource("%d")' % self.ext[path][0]

    def sub(self, text):
        self.sub_ids += 1
        rid = "sub_%d" % self.sub_ids
        self.subs.append('[sub_resource %s\n' % text.replace("ID", rid, 1))
        return 'SubResource("%s")' % rid

    def rect_shape(self, w, h):
        return self.sub('type="RectangleShape2D" id="ID"]\nsize = Vector2(%s, %s)\n' % (f(float(w)), f(float(h))))

    def exit(self, name, side, along=None):
        """side: left/right/top/bottom; along: y for sides, x for top/bottom. Default: floor level or centre."""
        if along is None:
            along = self.floor_y - 68 if side in ("left", "right") else self.w / 2
        self.exits.append((name, side, float(along)))
        if side in ("left", "right"):
            self.openings[side].append((along - 68, along + 68))
        else:
            self.openings[side].append((along - 80, along + 80))

    def polygon(self, parent, name, color, pts, pos=None, extra=""):
        s = '[node name="%s" type="Polygon2D" parent="%s"]\n' % (name, parent)
        if pos: s += "position = Vector2(%s)\n" % f(pos)
        s += "color = %s\npolygon = PackedVector2Array(%s)\n%s\n" % (color, f([c for p in pts for c in p]), extra)
        self.nodes.append(s)

    def rect_pts(self, x, y, w, h):
        return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]

    def instance(self, name, scene, parent=".", props=None, extra_nodes=""):
        s = '[node name="%s" parent="%s" instance=%s]\n' % (name, parent, self.res(scene))
        for k, v in (props or {}).items():
            s += "%s = %s\n" % (k, v)
        self.nodes.append(s + "\n" + extra_nodes)

    def checkpoint(self, pos, room_name):
        self.instance("Airlock", "res://scenes/Checkpoint.tscn", props={"position": "Vector2(%s)" % f(pos), "room_name": '"%s"' % room_name})

    def spawner(self, name, enemy, pos):
        self.instance(name, "res://scenes/Spawner.tscn", props={"position": "Vector2(%s)" % f(pos), "scene": self.res("res://scenes/%s.tscn" % enemy)})

    def switch(self, name, switch_name, pos):
        self.instance(name, "res://scenes/Switch.tscn", props={"position": "Vector2(%s)" % f(pos), "switch_name": '"%s"' % switch_name})

    def hazard(self, name, pos, size=None):
        extra = ""
        if size:
            shape = self.rect_shape(*size)
            extra = '[node name="CollisionShape2D" parent="%s" index="0"]\nshape = %s\n\n[node name="CollisionShape2D" parent="%s/Hurt" index="0"]\nshape = %s\n\n' % (name, shape, name, shape)
            extra += '[node name="Spikes" parent="%s" index="1"]\npolygon = PackedVector2Array(%s)\n\n' % (name, f([c for p in self.spike_pts(size) for c in p]))
        self.instance(name, "res://scenes/Hazard.tscn", props={"position": "Vector2(%s)" % f(pos)}, extra_nodes=extra)

    def spike_pts(self, size):
        w, h = size
        pts = [(-w / 2, h / 2)]
        n = max(2, int(w // 10))
        for i in range(n):
            x0 = -w / 2 + i * w / n
            pts.append((x0 + w / n / 2, -h / 2))
            pts.append((x0 + w / n, h / 2))
        return pts

    def vent(self, name, pos, size, direction):
        shape = self.rect_shape(*size)
        extra = '[node name="Bounds" parent="%s" index="0"]\nshape = %s\n\n[node name="Streaks" parent="%s" index="1"]\nemission_rect_extents = Vector2(%s, %s)\n\n' % (name, shape, name, f(size[0] / 2), f(size[1] / 2))
        self.instance(name, "res://scenes/Vent.tscn", props={"position": "Vector2(%s)" % f(pos), "direction": "Vector2(%s)" % f(direction)}, extra_nodes=extra)

    def block(self, x, y, w, h, color=HULL, name=None):
        """A solid static block that is part of the hull."""
        self.extras_hull.append((x, y, w, h, color, name))

    def state_block(self, container, name, x, y, w, h, color=SCENERY, collide=True):
        self.state.setdefault(container, []).append((name, x, y, w, h, color, collide))

    def star_field(self, count, seed=1):
        import random
        rng = random.Random(seed)
        pts = []
        for i in range(count):
            x, y = rng.uniform(T, self.w - T), rng.uniform(T, self.h - T)
            s = rng.uniform(1.0, 2.5)
            pts.append([(x, y), (x + s, y), (x + s, y + s), (x, y + s)])
        return pts

    # ---- writing ----
    def hull_rects(self):
        rects = []
        def wall_segments(length, openings):
            segs, start = [], 0.0
            for a, b in sorted(openings):
                if a > start: segs.append((start, a))
                start = max(start, b)
            if start < length: segs.append((start, length))
            return segs
        for a, b in wall_segments(self.h, self.openings["left"]): rects.append((0, a, T, b - a))
        for a, b in wall_segments(self.h, self.openings["right"]): rects.append((self.w - T, a, T, b - a))
        for a, b in wall_segments(self.w, self.openings["top"]): rects.append((a, 0, b - a, T))
        bottom_open = list(self.openings["bottom"])
        if self.floor_segments is not None:
            for a, b in self.floor_segments: rects.append((a, self.floor_y, b - a, self.h - self.floor_y))
        else:
            for a, b in wall_segments(self.w, bottom_open): rects.append((a, self.h - T, b - a, T))
        return rects

    def write(self):
        n = []
        n.append('[node name="%s" type="Node2D"]\nscript = %s\nroom_name = "%s"\nfloor_y = %s\n\n' % (self.name.replace(" ", ""), self.res("res://scripts/room.gd", "Script"), self.name, f(self.floor_y)))
        # background
        if not self.plates_live:
            n.append('[node name="Sky" type="Polygon2D" parent="."]\ncolor = Color(0.01, 0.01, 0.02, 1)\npolygon = PackedVector2Array(%s)\n\n' % f([c for p in self.rect_pts(0, 0, self.w, self.h) for c in p]))
            for i, s in enumerate(self.star_field(60, seed=len(self.name))):
                n.append('[node name="Star%d" type="Polygon2D" parent="."]\ncolor = %s\npolygon = PackedVector2Array(%s)\n\n' % (i, STAR, f([c for p in s for c in p])))
        # hull
        n.append('[node name="Hull" type="StaticBody2D" parent="."]\ncollision_layer = 1\ncollision_mask = 0\n\n')
        rects = self.hull_rects() + [(x, y, w, h) for (x, y, w, h, c, nm) in self.extras_hull]
        colors = [HULL] * len(self.hull_rects()) + [c for (x, y, w, h, c, nm) in self.extras_hull]
        for i, ((x, y, w, h), color) in enumerate(zip(rects, colors)):
            shape = self.rect_shape(w, h)
            n.append('[node name="Wall%d" type="CollisionShape2D" parent="Hull"]\nposition = Vector2(%s, %s)\nshape = %s\n\n' % (i, f(x + w / 2), f(y + h / 2), shape))
            n.append('[node name="WallArt%d" type="Polygon2D" parent="Hull"]\ncolor = %s\npolygon = PackedVector2Array(%s)\n\n' % (i, color, f([c for p in self.rect_pts(x, y, w, h) for c in p])))
        if self.plates_live and self.floor_segments is None:
            n.append('[node name="PlateArt" type="Polygon2D" parent="Hull"]\ncolor = %s\npolygon = PackedVector2Array(%s)\n\n' % (PLATE, f([c for p in self.rect_pts(T, self.floor_y, self.w - 2 * T, 6) for c in p])))
        # compartment
        bounds = self.rect_shape(self.w, self.h)
        n.append('[node name="Compartment" parent="." instance=%s]\nposition = Vector2(%s, %s)\nplates_live = %s\nroom_name = "%s"\n\n[node name="Bounds" parent="Compartment" index="0"]\nshape = %s\n\n' % (self.res("res://scenes/Compartment.tscn"), f(self.w / 2), f(self.h / 2), f(self.plates_live), self.name, bounds))
        n.append('[node name="Tint" type="Polygon2D" parent="Compartment"]\ncolor = Color(1, 0.72, 0.4, 0.1)\npolygon = PackedVector2Array(%s)\n\n' % f([c for p in self.rect_pts(-self.w / 2, -self.h / 2, self.w, self.h) for c in p]))
        for container, blocks in self.state.items():
            n.append('[node name="%s" type="Node2D" parent="Compartment"]\nposition = Vector2(%s, %s)\n\n' % (container, f(-self.w / 2), f(-self.h / 2)))
            for (name, x, y, w, h, color, collide) in blocks:
                n.append('[node name="%s" type="StaticBody2D" parent="Compartment/%s"]\ncollision_layer = 1\ncollision_mask = 0\n\n' % (name, container))
                if collide:
                    n.append('[node name="Shape" type="CollisionShape2D" parent="Compartment/%s/%s"]\nposition = Vector2(%s, %s)\nshape = %s\n\n' % (container, name, f(x + w / 2), f(y + h / 2), self.rect_shape(w, h)))
                n.append('[node name="Art" type="Polygon2D" parent="Compartment/%s/%s"]\ncolor = %s\npolygon = PackedVector2Array(%s)\n\n' % (container, name, color, f([c for p in self.rect_pts(x, y, w, h) for c in p])))
        # exits
        n.append('[node name="Exits" type="Node2D" parent="."]\n\n')
        for (name, side, along) in self.exits:
            if side == "left": pos, inward, rot = (T / 2, along), (1, 0), 0.0
            elif side == "right": pos, inward, rot = (self.w - T / 2, along), (-1, 0), 0.0
            elif side == "top": pos, inward, rot = (along, T / 2), (0, 1), math.pi / 2
            else: pos, inward, rot = (along, self.h - T / 2), (0, -1), math.pi / 2
            n.append('[node name="%s" parent="Exits" instance=%s]\nposition = Vector2(%s)\nrotation = %s\nexit_name = "%s"\ninward = Vector2(%s)\n\n' % (name, self.res("res://scenes/Exit.tscn"), f(pos), f(rot), name, f(inward)))
        n.extend(self.nodes)
        head = "[gd_scene load_steps=%d format=3]\n\n" % (len(self.ext) + len(self.subs) + 1)
        for path, (i, kind) in sorted(self.ext.items(), key=lambda kv: kv[1][0]):
            head += '[ext_resource type="%s" path="%s" id="%d"]\n' % (kind, path, i)
        head += "\n" + "".join(self.subs) + "\n"
        os.makedirs("scenes/rooms", exist_ok=True)
        with open("scenes/rooms/%s.tscn" % self.name.replace(" ", ""), "w") as out:
            out.write(head + "".join(n))

# ------------------------------------------------------------------ rooms

def dock():
    r = Room("Dock", (1, 1), True)
    fy = r.floor_y
    r.exit("west", "left")
    r.exit("east", "right")
    r.checkpoint((120, fy - 40), "Dock")
    r.spawner("MiteSpawner1", "Mite", (600, fy - 8))
    r.spawner("MiteSpawner2", "Mite", (1090, fy - 8))
    r.polygon(".", "Sign", SCENERY, r.rect_pts(0, 0, 160, 40), pos=(500, 80))
    r.write()

def breach():
    r = Room("Breach", (1, 1), False)
    r.exit("west", "left", 324)
    r.exit("east", "right", 324)
    # three drifting hull fragments to grab, mites on their top faces
    for i, (x, y, w, h) in enumerate([(220, 160, 220, 90), (560, 400, 260, 80), (800, 120, 180, 110)]):
        r.block(x, y, w, h, color=SCENERY, name="Fragment%d" % i)
        r.spawner("MiteSpawner%d" % i, "Mite", (x + w / 2, y - 8))
    r.write()

if __name__ == "__main__":
    dock()
    breach()
    print("rooms written")
