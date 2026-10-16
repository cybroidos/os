"""Render the CSS draw-in animation of the logo mark to static SVG frames.

Boot splashes (Plymouth) cannot play CSS-animated SVG, and SVG rasterisers
ignore CSS animations, so render-brand.py samples the animation here into one
static SVG per frame and rasterises those.

Timings are read from the animated SVG's <style> (per-class `--t`/`--d` and the
nodes' `animation-delay`), applied to the elements of the static mark, which has
the same classes. The keyframes themselves (draw, tip, pop) are implemented
below to match logo/cybroid-mark-animated-transparent.svg; the endless loops
(node breathing, pulses, star twinkle) are left out: a splash holds the final
frame instead.

rsvg does not support `pathLength`, so stroke dashes use each arc's real
length.
"""

import math
import re
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

DRAW_EASE = (0.65, 0.0, 0.35, 1.0)
TIP_EASE = (0.2, 0.9, 0.3, 1.25)
POP_EASE = (0.3, 1.6, 0.5, 1.0)
DRAW_DUR = 0.8   # default --d
TIP = (1.35, 0.6, (420.0, 378.0), -38.0)  # delay, duration, origin, start angle
NODE_POP_DUR = 0.45
STAR = (1.95, 0.5)  # delay, duration


def cubic_bezier(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
    """CSS cubic-bezier timing function: progress for time fraction x."""
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    lo, hi = 0.0, 1.0
    for _ in range(40):  # bisection on the curve parameter
        t = (lo + hi) / 2
        bx = 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t ** 2 * x2 + t ** 3
        if bx < x:
            lo = t
        else:
            hi = t
    t = (lo + hi) / 2
    return 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t ** 2 * y2 + t ** 3


def progress(now: float, delay: float, dur: float, ease: tuple) -> float:
    return cubic_bezier(*ease, (now - delay) / dur)


def arc_length(d: str) -> float:
    """Length of a single-arc path `M x y A r r rot large sweep x y`."""
    n = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", d)]
    x1, y1, r, large, x2, y2 = n[0], n[1], n[2], n[5], n[7], n[8]
    chord = math.hypot(x2 - x1, y2 - y1)
    theta = 2 * math.asin(min(1.0, chord / (2 * r)))
    if large:
        theta = 2 * math.pi - theta
    return r * theta


def timings(animated_svg: str) -> tuple[dict, dict]:
    """Per-class (delay, duration) for draws, and per-class delay for pops."""
    css = re.search(r"<style>(.*?)</style>", animated_svg, re.S).group(1)
    draws = {}
    for cls, body in re.findall(r"\.([\w-]+)\{([^}]*)\}", css):
        t = re.search(r"--t:([\d.]+)s", body)
        if t:
            d = re.search(r"--d:([\d.]+)s", body)
            draws[cls] = (float(t.group(1)), float(d.group(1)) if d else DRAW_DUR)
    pops = {cls: float(delay) for cls, delay in
            re.findall(r"\.(n\d+)\{animation-delay:([\d.]+)s", css)}
    return draws, pops


def duration(animated_svg: str) -> float:
    """Time at which the intro (everything but the loops) has finished."""
    draws, pops = timings(animated_svg)
    ends = [t + d for t, d in draws.values()]
    ends += [t + NODE_POP_DUR for t in pops.values()]
    ends += [TIP[0] + TIP[1], STAR[0] + STAR[1]]
    return max(ends)


def frame(static_svg: str, animated_svg: str, now: float) -> str:
    """The static mark as it looks `now` seconds into the animation."""
    draws, pops = timings(animated_svg)
    root = ET.fromstring(static_svg)
    for parent in root.iter():
        for el in list(parent):
            classes = el.get("class", "").split()
            if "cy-pulse" in classes:
                parent.remove(el)
                continue
            draw = next((draws[c] for c in classes if c in draws), None)
            if draw and el.get("d"):
                p = progress(now, *draw, DRAW_EASE)
                length = arc_length(el.get("d"))
                el.attrib.pop("pathLength", None)
                el.set("stroke-dasharray", f"{length:.2f} {length + 1:.2f}")
                el.set("stroke-dashoffset", f"{length * (1 - p):.2f}")
                if p <= 0:
                    el.set("opacity", "0")  # round caps would show a dot
            elif "c-tip" in classes:
                delay, dur, (ox, oy), start = TIP
                p = progress(now, delay, dur, TIP_EASE)
                el.set("opacity", f"{max(0.0, min(1.0, p)):.3f}")
                el.set("transform", f"rotate({start * (1 - p):.2f} {ox} {oy})")
            elif "cy-node" in classes:
                delay = next((pops[c] for c in classes if c in pops), 0.0)
                s = max(0.0, progress(now, delay, NODE_POP_DUR, POP_EASE))
                cx, cy = float(el.get("cx")), float(el.get("cy"))
                el.set("transform", f"translate({cx} {cy}) scale({s:.3f}) translate({-cx} {-cy})")
            elif "cy-star" in classes:
                s = max(0.0, progress(now, *STAR, POP_EASE))
                el.set("transform", f"{el.get('transform', '')} scale({s:.3f})".strip())
    return ET.tostring(root, encoding="unicode")


def geometry(static_svg: str, animated_svg: str) -> dict:
    """The mark as plain data, for renderers that draw it natively (Flutter).

    Returns the viewBox size, the linear gradients, and every element in paint
    order with its role and timing. Paths stay as SVG `d` strings (M/A/L/Z).
    """
    draws, pops = timings(animated_svg)
    root = ET.fromstring(static_svg)
    size = float(root.get("viewBox").split()[2])

    gradients = {}
    for g in root.iter(f"{{{SVG_NS}}}linearGradient"):
        gradients[g.get("id")] = {
            "from": (float(g.get("x1")), float(g.get("y1"))),
            "to": (float(g.get("x2")), float(g.get("y2"))),
            "stops": [(float(s.get("offset")), s.get("stop-color"))
                      for s in g.iter(f"{{{SVG_NS}}}stop")],
        }

    def gradient_ref(value):
        m = re.match(r"url\(#([\w-]+)\)", value or "")
        return m.group(1) if m else None

    elements = []
    circuit_color = None
    for el in root.iter():
        classes = el.get("class", "").split()
        if not classes or "cy-pulse" in classes:
            continue
        if "cy-circuit" in classes:
            circuit_color = el.get("stroke")
            continue
        draw = next((draws[c] for c in classes if c in draws), None)
        if "cy-band" in classes or "cy-trace" in classes:
            item = {
                "kind": "band" if "cy-band" in classes else "trace",
                "d": el.get("d"),
                "width": float(el.get("stroke-width")),
                "round": el.get("stroke-linecap") == "round",
                "gradient": gradient_ref(el.get("stroke")),
                "glow": "cy-trace" in classes,
            }
            if "c-tip" in classes:
                delay, dur, origin, start = TIP
                item.update(kind="tip", delay=delay, duration=dur, origin=origin, angle=start)
            else:
                item.update(delay=draw[0], duration=draw[1])
            elements.append(item)
        elif "cy-node" in classes:
            delay = next((pops[c] for c in classes if c in pops), 0.0)
            elements.append({
                "kind": "node", "center": (float(el.get("cx")), float(el.get("cy"))),
                "r": float(el.get("r")), "delay": delay, "duration": NODE_POP_DUR, "glow": True,
            })
        elif "cy-star" in classes:
            tx, ty = re.findall(r"-?\d+(?:\.\d+)?", el.get("transform"))[:2]
            elements.append({
                "kind": "star", "d": el.get("d"), "center": (float(tx), float(ty)),
                "fill": el.get("fill"), "delay": STAR[0], "duration": STAR[1], "glow": True,
            })
    return {
        "size": size, "gradients": gradients, "elements": elements,
        "circuit_color": circuit_color, "duration": duration(animated_svg),
        "ease": {"draw": DRAW_EASE, "tip": TIP_EASE, "pop": POP_EASE},
    }
