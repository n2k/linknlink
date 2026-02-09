#!/usr/bin/env python3
"""Generate a heat-pump themed boot animation matching the kiosk dashboard."""

import math
import os
import shutil
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 800
FPS = 12

# Dashboard color palette
BG = (13, 17, 23)           # Dark navy background
CYAN = (100, 200, 255)      # Snowflake / accent cyan
CYAN_DIM = (40, 80, 110)    # Dimmed cyan
ORANGE = (255, 170, 40)     # Hot water accent
WHITE = (220, 225, 235)     # Text white
GRAY = (100, 110, 130)      # Subtle gray

FONT_PATH = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

OUT = "/tmp/bootanim_build"


def lerp_color(c1, c2, t):
    """Interpolate between two RGB colors."""
    t = max(0.0, min(1.0, t))
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_snowflake(draw, cx, cy, size, color, thickness=3):
    """Draw a 6-pointed snowflake."""
    for i in range(6):
        angle = math.radians(i * 60 - 90)
        x2 = cx + math.cos(angle) * size
        y2 = cy + math.sin(angle) * size
        draw.line([(cx, cy), (x2, y2)], fill=color, width=thickness)

        # Branch tips
        branch_len = size * 0.4
        for side in [-1, 1]:
            ba = angle + side * math.radians(45)
            bx = cx + math.cos(angle) * size * 0.6
            by = cy + math.sin(angle) * size * 0.6
            bx2 = bx + math.cos(ba) * branch_len
            by2 = by + math.sin(ba) * branch_len
            draw.line([(bx, by), (bx2, by2)], fill=color, width=max(1, thickness - 1))

        # Smaller inner branches
        for side in [-1, 1]:
            ba = angle + side * math.radians(50)
            bx = cx + math.cos(angle) * size * 0.35
            by = cy + math.sin(angle) * size * 0.35
            bx2 = bx + math.cos(ba) * branch_len * 0.5
            by2 = by + math.sin(ba) * branch_len * 0.5
            draw.line([(bx, by), (bx2, by2)], fill=color, width=max(1, thickness - 2))


def draw_heat_waves(draw, cx, cy, radius, color, phase=0, count=3):
    """Draw concentric heat wave arcs on the right side."""
    for i in range(count):
        r = radius + i * 14
        alpha = max(0, 255 - i * 70)
        c = (*color[:3],) if len(color) == 3 else color
        c_faded = lerp_color(c, BG, i * 0.3)
        arc_start = -40 + math.sin(phase + i * 0.5) * 8
        arc_end = 40 + math.sin(phase + i * 0.5) * 8
        bbox = [cx - r, cy - r, cx + r, cy + r]
        draw.arc(bbox, start=arc_start, end=arc_end, fill=c_faded, width=2)


def draw_flow_arrow(draw, x1, y, x2, color, progress=1.0, thickness=2):
    """Draw a horizontal flow line with an arrow."""
    x_end = x1 + (x2 - x1) * progress
    draw.line([(x1, y), (x_end, y)], fill=color, width=thickness)
    if progress > 0.3:
        # Arrowhead
        ax = x_end
        draw.polygon([(ax, y), (ax - 10, y - 6), (ax - 10, y + 6)], fill=color)


def generate_part0(output_dir):
    """Part 0: Fade in snowflake + title + flow diagram."""
    os.makedirs(output_dir, exist_ok=True)
    total_frames = FPS * 3  # 3 seconds

    font_title = ImageFont.truetype(FONT_BOLD, 32)
    font_sub = ImageFont.truetype(FONT_PATH, 18)

    for frame in range(total_frames):
        t = frame / total_frames  # 0 -> 1
        img = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(img)

        # Snowflake fade in (first 60% of animation)
        snow_t = min(1.0, t / 0.6)
        snow_alpha = snow_t
        snow_color = lerp_color(BG, CYAN, snow_alpha)
        snow_size = 55 + snow_t * 5  # Slight grow

        cx, cy = W // 2, H // 2 - 40
        draw_snowflake(draw, cx, cy, snow_size, snow_color, thickness=3)

        # Glow circle behind snowflake
        if snow_alpha > 0.1:
            glow_color = lerp_color(BG, CYAN_DIM, snow_alpha * 0.3)
            for r in range(80, 20, -5):
                glow = lerp_color(BG, glow_color, (80 - r) / 60 * snow_alpha * 0.5)
                draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=glow)

        # Title fade in (starts at 30%)
        if t > 0.3:
            text_t = min(1.0, (t - 0.3) / 0.4)
            text_color = lerp_color(BG, WHITE, text_t)
            title = "IVT Air X 400"
            bbox = draw.textbbox((0, 0), title, font=font_title)
            tw = bbox[2] - bbox[0]
            draw.text(((W - tw) // 2, cy + 80), title, fill=text_color, font=font_title)

        # Subtitle fade in (starts at 50%)
        if t > 0.5:
            sub_t = min(1.0, (t - 0.5) / 0.3)
            sub_color = lerp_color(BG, GRAY, sub_t)
            subtitle = "Heat Pump Dashboard"
            bbox = draw.textbbox((0, 0), subtitle, font=font_sub)
            tw = bbox[2] - bbox[0]
            draw.text(((W - tw) // 2, cy + 120), subtitle, fill=sub_color, font=font_sub)

        # Flow line at bottom (starts at 60%)
        if t > 0.6:
            flow_t = min(1.0, (t - 0.6) / 0.4)
            line_y = cy + 170
            line_w = 300
            line_x = (W - line_w) // 2

            # Blue (cold) to orange (hot) gradient line
            for px in range(int(line_w * flow_t)):
                frac = px / line_w
                c = lerp_color(CYAN, ORANGE, frac)
                c = lerp_color(BG, c, min(1.0, flow_t * 1.5))
                draw.line([(line_x + px, line_y), (line_x + px, line_y)], fill=c)

            # Dots at ends
            if flow_t > 0.2:
                dot_c = lerp_color(BG, CYAN, min(1.0, flow_t * 2))
                draw.ellipse([line_x - 5, line_y - 5, line_x + 5, line_y + 5], fill=dot_c)
            if flow_t > 0.8:
                dot_c = lerp_color(BG, ORANGE, min(1.0, (flow_t - 0.5) * 3))
                end_x = line_x + int(line_w * flow_t)
                draw.ellipse([end_x - 5, line_y - 5, end_x + 5, line_y + 5], fill=dot_c)

        img.save(os.path.join(output_dir, f"{frame:03d}.jpg"), "JPEG", quality=90)

    return total_frames


def generate_part1(output_dir):
    """Part 1: Looping pulse animation - snowflake breathes, flow animates."""
    os.makedirs(output_dir, exist_ok=True)
    total_frames = FPS * 3  # 3-second loop

    font_title = ImageFont.truetype(FONT_BOLD, 32)
    font_sub = ImageFont.truetype(FONT_PATH, 18)
    font_status = ImageFont.truetype(FONT_PATH, 16)

    for frame in range(total_frames):
        t = frame / total_frames  # 0 -> 1 (one loop cycle)
        phase = t * math.pi * 2
        img = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(img)

        cx, cy = W // 2, H // 2 - 40

        # Pulsing snowflake
        pulse = 0.85 + 0.15 * math.sin(phase)
        snow_color = lerp_color(CYAN_DIM, CYAN, pulse)
        snow_size = 55 + 5 * math.sin(phase)
        draw_snowflake(draw, cx, cy, snow_size, snow_color, thickness=3)

        # Pulsing glow
        glow_intensity = 0.2 + 0.15 * math.sin(phase)
        for r in range(80, 20, -5):
            glow = lerp_color(BG, CYAN_DIM, (80 - r) / 60 * glow_intensity)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=glow)

        # Title
        title = "IVT Air X 400"
        bbox = draw.textbbox((0, 0), title, font=font_title)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) // 2, cy + 80), title, fill=WHITE, font=font_title)

        # Subtitle
        subtitle = "Heat Pump Dashboard"
        bbox = draw.textbbox((0, 0), subtitle, font=font_sub)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) // 2, cy + 120), subtitle, fill=GRAY, font=font_sub)

        # Animated flow line (particles moving along gradient)
        line_y = cy + 170
        line_w = 300
        line_x = (W - line_w) // 2

        # Base gradient line
        for px in range(line_w):
            frac = px / line_w
            c = lerp_color(CYAN, ORANGE, frac)
            c = lerp_color(c, BG, 0.3)  # Dim the base line
            draw.line([(line_x + px, line_y), (line_x + px, line_y)], fill=c)

        # Animated bright particle moving along the line
        for p in range(3):
            particle_pos = ((t + p * 0.33) % 1.0)
            px_pos = int(line_x + particle_pos * line_w)
            frac = particle_pos
            particle_color = lerp_color(CYAN, ORANGE, frac)
            # Draw particle with glow
            for glow_r in range(12, 0, -1):
                gc = lerp_color(BG, particle_color, (12 - glow_r) / 12 * 0.8)
                draw.ellipse([px_pos - glow_r, line_y - glow_r,
                              px_pos + glow_r, line_y + glow_r], fill=gc)

        # End dots
        draw.ellipse([line_x - 5, line_y - 5, line_x + 5, line_y + 5], fill=CYAN)
        draw.ellipse([line_x + line_w - 5, line_y - 5,
                       line_x + line_w + 5, line_y + 5], fill=ORANGE)

        # "Starting..." text with animated dots
        dots = "." * (1 + frame % 3)
        status = f"Starting{dots}"
        status_color = lerp_color(GRAY, BG, 0.3)
        bbox = draw.textbbox((0, 0), status, font=font_status)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) // 2, cy + 200), status, fill=status_color, font=font_status)

        img.save(os.path.join(output_dir, f"{frame:03d}.jpg"), "JPEG", quality=90)

    return total_frames


def main():
    # Clean and create build dir
    if os.path.exists(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)

    print("Generating part0 (fade in)...")
    n0 = generate_part0(os.path.join(OUT, "part0"))
    print(f"  {n0} frames")

    print("Generating part1 (loop)...")
    n1 = generate_part1(os.path.join(OUT, "part1"))
    print(f"  {n1} frames")

    # Write desc.txt
    desc = f"{W} {H} {FPS}\np 1 0 part0\np 0 0 part1\n"
    with open(os.path.join(OUT, "desc.txt"), "w") as f:
        f.write(desc)
    print(f"desc.txt: {desc.strip()}")

    # Package into zip (must use STORED, not DEFLATED for bootanimation)
    import zipfile
    zip_path = "/tmp/bootanimation_custom.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_STORED) as zf:
        zf.write(os.path.join(OUT, "desc.txt"), "desc.txt")
        for part in ["part0", "part1"]:
            part_dir = os.path.join(OUT, part)
            files = sorted(os.listdir(part_dir))
            for fname in files:
                zf.write(os.path.join(part_dir, fname), f"{part}/{fname}")

    size = os.path.getsize(zip_path)
    print(f"\nCreated: {zip_path} ({size / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
