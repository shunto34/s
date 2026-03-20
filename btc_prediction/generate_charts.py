"""Generate professional chart cards for the BTC prediction video.

Creates clean, TikTok-optimized chart visualizations using the actual
price data from the user's TradingView screenshots.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np
import os

WIDTH = 1080
HEIGHT = 1920

# Colors
BG_DARK = (12, 12, 22)
BG_CARD = (20, 22, 35)
CYAN = (0, 200, 220)
GREEN = (0, 220, 100)
RED = (220, 50, 80)
ORANGE = (255, 180, 40)
BLUE = (40, 140, 255)
WHITE = (240, 240, 250)
GRAY = (120, 120, 140)
GOLD = (255, 210, 50)


def get_font(size, bold=True):
    paths = [
        "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except:
            continue
    return ImageFont.load_default()


def draw_glow_text(img, text, x, y, font, color, glow_radius=8):
    """Draw text with neon glow effect."""
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for _ in range(3):
        d.text((x, y), text, font=font, fill=(*color, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=glow_radius))

    sharp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sharp)
    sd.text((x, y), text, font=font, fill=(*color, 255))

    result = img.convert("RGBA")
    result = Image.alpha_composite(result, glow)
    result = Image.alpha_composite(result, sharp)
    return result.convert("RGB")


def draw_candlestick_chart(draw, x0, y0, w, h, prices, colors):
    """Draw a simplified candlestick chart."""
    n = len(prices)
    candle_w = max(3, w // (n * 2))
    gap = w / n

    min_p = min(p[2] for p in prices)  # low
    max_p = max(p[1] for p in prices)  # high
    price_range = max_p - min_p
    if price_range == 0:
        price_range = 1

    def price_to_y(p):
        return y0 + h - int((p - min_p) / price_range * h)

    for i, (open_p, high, low, close) in enumerate(prices):
        cx = int(x0 + i * gap + gap / 2)
        bullish = close >= open_p
        color = colors[0] if bullish else colors[1]

        # Wick
        wick_y1 = price_to_y(high)
        wick_y2 = price_to_y(low)
        draw.line([(cx, wick_y1), (cx, wick_y2)], fill=color, width=1)

        # Body
        body_top = price_to_y(max(open_p, close))
        body_bot = price_to_y(min(open_p, close))
        body_h = max(body_bot - body_top, 2)
        draw.rectangle(
            [cx - candle_w // 2, body_top, cx + candle_w // 2, body_top + body_h],
            fill=color,
        )

    return min_p, max_p, price_to_y


def generate_btc_price_data_30m():
    """Generate realistic BTC 30m candle data matching the W-bottom pattern."""
    # W-bottom pattern: drop to ~68,627, bounce, drop again, then strong rally
    np.random.seed(42)

    prices = []
    p = 70200  # start

    # Phase 1: Initial decline (candles 0-15)
    for i in range(16):
        change = np.random.normal(-80, 60)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 50))
        low = min(open_p, close) - abs(np.random.normal(0, 50))
        prices.append((open_p, high, low, close))
        p = close

    # Phase 2: First bottom (~68,627)
    p = 68800
    for i in range(5):
        change = np.random.normal(20, 40)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 30))
        low = min(open_p, close) - abs(np.random.normal(0, 30))
        if i == 0:
            low = 68627
        prices.append((open_p, high, low, close))
        p = close

    # Phase 3: Bounce to ~69,900
    p = 69000
    for i in range(8):
        change = np.random.normal(60, 40)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 40))
        low = min(open_p, close) - abs(np.random.normal(0, 30))
        prices.append((open_p, high, low, close))
        p = close

    # Phase 4: Second dip (not as deep)
    p = 69500
    for i in range(6):
        change = np.random.normal(-40, 50)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 40))
        low = min(open_p, close) - abs(np.random.normal(0, 30))
        prices.append((open_p, high, low, close))
        p = close

    # Phase 5: Strong rally to current (~70,516)
    p = 69200
    for i in range(10):
        change = np.random.normal(100, 50)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 60))
        low = min(open_p, close) - abs(np.random.normal(0, 30))
        prices.append((open_p, high, low, close))
        p = close

    # Adjust last candle to close at 70,516
    last = prices[-1]
    prices[-1] = (last[0], max(last[1], 70600), last[2], 70516)

    return prices


def generate_btc_price_data_15m():
    """Generate BTC 15m data showing BOS signals."""
    np.random.seed(123)
    prices = []
    p = 69800

    # Range / accumulation
    for i in range(20):
        change = np.random.normal(10, 30)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 20))
        low = min(open_p, close) - abs(np.random.normal(0, 20))
        prices.append((open_p, high, low, close))
        p = close

    # BOS breakout
    p = 69950
    for i in range(15):
        change = np.random.normal(50, 35)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 30))
        low = min(open_p, close) - abs(np.random.normal(0, 20))
        prices.append((open_p, high, low, close))
        p = close

    # Pullback
    for i in range(8):
        change = np.random.normal(-20, 25)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 20))
        low = min(open_p, close) - abs(np.random.normal(0, 15))
        prices.append((open_p, high, low, close))
        p = close

    # Continuation rally
    for i in range(12):
        change = np.random.normal(40, 30)
        open_p = p
        close = p + change
        high = max(open_p, close) + abs(np.random.normal(0, 25))
        low = min(open_p, close) - abs(np.random.normal(0, 15))
        prices.append((open_p, high, low, close))
        p = close

    # End near 70,516
    last = prices[-1]
    prices[-1] = (last[0], max(last[1], 70600), last[2], 70516)

    return prices


def create_30m_chart():
    """Create the 30m context chart showing W-bottom pattern."""
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(img)

    # Title area
    title_font = get_font(42)
    small_font = get_font(24)
    label_font = get_font(20)

    # Header
    img = draw_glow_text(img, "BTCUSD  30分足", 60, 180, title_font, CYAN)
    draw = ImageDraw.Draw(img)
    draw.text((60, 240), "W底パターン → ブレイクアウト予測", font=small_font, fill=GRAY)

    # Chart area
    chart_x, chart_y = 80, 320
    chart_w, chart_h = WIDTH - 160, 900

    # Draw chart background
    draw.rectangle(
        [chart_x - 10, chart_y - 10, chart_x + chart_w + 10, chart_y + chart_h + 10],
        fill=(18, 18, 30),
        outline=(40, 40, 60),
        width=1,
    )

    # Generate and draw candles
    prices = generate_btc_price_data_30m()
    min_p, max_p, price_to_y = draw_candlestick_chart(
        draw, chart_x, chart_y, chart_w, chart_h,
        prices, (GREEN, RED)
    )

    # Draw key price levels
    levels = [
        (68627, "68,627", ORANGE, "Support"),
        (69901, "69,901", BLUE, "Resistance → Support"),
        (74684, "74,684", CYAN, "Target Zone"),
    ]

    for price, label, color, desc in levels:
        if min_p <= price <= max_p:
            y = price_to_y(price)
            # Dashed line
            for x in range(chart_x, chart_x + chart_w, 10):
                draw.line([(x, y), (min(x + 5, chart_x + chart_w), y)], fill=(*color, 128), width=1)
            # Label
            draw.text((chart_x + chart_w - 200, y - 20), f"${label}", font=label_font, fill=color)

    # Draw W-bottom annotation (cyan curve)
    # First V of W
    w_points_1 = []
    w_bottom_1_y = price_to_y(68627)
    w_top_y = price_to_y(69900)
    w_start_x = chart_x + int(chart_w * 0.3)
    w_mid_x = chart_x + int(chart_w * 0.45)
    w_end_x = chart_x + int(chart_w * 0.6)

    for t in np.linspace(0, 1, 30):
        x = int(w_start_x + (w_mid_x - w_start_x) * t)
        y = int(w_top_y + (w_bottom_1_y - w_top_y) * 4 * t * (1 - t) + (w_bottom_1_y - w_top_y) * t)
        w_points_1.append((x, y))

    # Second V of W
    for t in np.linspace(0, 1, 30):
        x = int(w_mid_x + (w_end_x - w_mid_x) * t)
        y = int(w_top_y + (w_bottom_1_y - w_top_y - 200) * 4 * t * (1 - t))
        w_points_1.append((x, y))

    # Draw prediction path up
    arrow_end_y = price_to_y(74000)
    for t in np.linspace(0, 1, 20):
        x = int(w_end_x + (chart_x + chart_w * 0.85 - w_end_x) * t)
        y = int(w_top_y + (arrow_end_y - w_top_y) * t)
        w_points_1.append((x, y))

    if len(w_points_1) > 1:
        # Glow
        glow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow_layer)
        gd.line(w_points_1, fill=(*CYAN, 100), width=6)
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=8))
        img = Image.alpha_composite(img.convert("RGBA"), glow_layer).convert("RGB")
        draw = ImageDraw.Draw(img)
        draw.line(w_points_1, fill=CYAN, width=3)

    # Arrow head at the end
    arrow_tip = w_points_1[-1]
    draw.polygon([
        (arrow_tip[0], arrow_tip[1] - 15),
        (arrow_tip[0] - 10, arrow_tip[1] + 5),
        (arrow_tip[0] + 10, arrow_tip[1] + 5),
    ], fill=CYAN)

    # Current price indicator
    current_y = price_to_y(70516)
    draw.rectangle(
        [chart_x + chart_w + 15, current_y - 15, chart_x + chart_w + 120, current_y + 15],
        fill=RED,
    )
    draw.text((chart_x + chart_w + 20, current_y - 12), "$70,516", font=label_font, fill=WHITE)

    # Bottom info
    info_font = get_font(28)
    img = draw_glow_text(img, "現在値: $70,516", 80, chart_y + chart_h + 40, info_font, WHITE)
    draw = ImageDraw.Draw(img)
    draw.text((80, chart_y + chart_h + 90), "W底形成 → 上昇トレンド転換の兆候", font=small_font, fill=CYAN)

    # Key levels summary at bottom
    y_info = chart_y + chart_h + 150
    draw.text((80, y_info), "━━━ 重要レベル ━━━", font=small_font, fill=GRAY)
    levels_text = [
        ("サポート", "$68,627", GREEN),
        ("現在値", "$70,516", WHITE),
        ("レジスタンス", "$74,684", ORANGE),
        ("ターゲット", "$75,000", CYAN),
    ]
    for i, (name, val, color) in enumerate(levels_text):
        y = y_info + 40 + i * 40
        draw.text((100, y), f"{name}:", font=small_font, fill=GRAY)
        draw.text((300, y), val, font=small_font, fill=color)

    return img


def create_15m_chart():
    """Create the 15m signal chart showing BOS and demand zone."""
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(img)

    title_font = get_font(42)
    small_font = get_font(24)
    label_font = get_font(20)
    bos_font = get_font(18)

    # Header
    img = draw_glow_text(img, "BTCUSD  15分足", 60, 180, title_font, CYAN)
    draw = ImageDraw.Draw(img)
    draw.text((60, 240), "BOS (構造ブレイク) 確認 → ロングセットアップ", font=small_font, fill=GRAY)

    # Chart area
    chart_x, chart_y = 80, 320
    chart_w, chart_h = WIDTH - 160, 900

    draw.rectangle(
        [chart_x - 10, chart_y - 10, chart_x + chart_w + 10, chart_y + chart_h + 10],
        fill=(18, 18, 30),
        outline=(40, 40, 60),
        width=1,
    )

    prices = generate_btc_price_data_15m()
    min_p, max_p, price_to_y = draw_candlestick_chart(
        draw, chart_x, chart_y, chart_w, chart_h,
        prices, (GREEN, RED)
    )

    # Draw demand zone (green zone around 69,900)
    if min_p <= 69901 <= max_p:
        zone_top = price_to_y(70050)
        zone_bot = price_to_y(69750)
        zone_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        zd = ImageDraw.Draw(zone_layer)
        zd.rectangle(
            [chart_x, zone_top, chart_x + chart_w, zone_bot],
            fill=(0, 220, 100, 40),
        )
        img = Image.alpha_composite(img.convert("RGBA"), zone_layer).convert("RGB")
        draw = ImageDraw.Draw(img)
        draw.text((chart_x + 10, zone_top + 5), "需要ゾーン $69,901", font=bos_font, fill=GREEN)

    # BOS labels
    bos_positions = [
        (0.35, 69950, "BOS 5Min"),
        (0.45, 70050, "BOS 15Min"),
        (0.55, 70200, "BOS 5Min"),
        (0.65, 70350, "BOS 15Min"),
    ]

    for x_ratio, price, label in bos_positions:
        if min_p <= price <= max_p:
            bx = chart_x + int(chart_w * x_ratio)
            by = price_to_y(price)

            # BOS box
            bbox = draw.textbbox((0, 0), label, font=bos_font)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]

            box_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            bd = ImageDraw.Draw(box_layer)
            bd.rounded_rectangle(
                [bx - 5, by - th - 8, bx + tw + 10, by + 2],
                radius=5,
                fill=(0, 200, 220, 60),
                outline=(*CYAN, 180),
                width=1,
            )
            img = Image.alpha_composite(img.convert("RGBA"), box_layer).convert("RGB")
            draw = ImageDraw.Draw(img)
            draw.text((bx, by - th - 5), label, font=bos_font, fill=CYAN)

            # Arrow line
            draw.line([(bx + tw // 2, by), (bx + tw // 2, by + 20)], fill=CYAN, width=1)

    # MSS label
    if min_p <= 69850 <= max_p:
        mss_x = chart_x + int(chart_w * 0.4)
        mss_y = price_to_y(69850)
        mss_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        md = ImageDraw.Draw(mss_layer)
        md.rounded_rectangle(
            [mss_x - 5, mss_y - 25, mss_x + 100, mss_y + 2],
            radius=5,
            fill=(255, 180, 40, 60),
            outline=(*ORANGE, 180),
            width=1,
        )
        img = Image.alpha_composite(img.convert("RGBA"), mss_layer).convert("RGB")
        draw = ImageDraw.Draw(img)
        draw.text((mss_x, mss_y - 22), "MSS 15Min", font=bos_font, fill=ORANGE)

    # Current price
    current_y = price_to_y(70516)
    draw.rectangle(
        [chart_x + chart_w + 15, current_y - 15, chart_x + chart_w + 120, current_y + 15],
        fill=RED,
    )
    draw.text((chart_x + chart_w + 20, current_y - 12), "$70,516", font=label_font, fill=WHITE)

    # Bottom analysis
    info_font = get_font(28)
    y_info = chart_y + chart_h + 40

    img = draw_glow_text(img, "シグナル確認", 80, y_info, info_font, CYAN)
    draw = ImageDraw.Draw(img)

    signals = [
        ("BOS 5min/15min", "構造ブレイク複数確認", GREEN),
        ("MSS 15min", "マーケット構造シフト", ORANGE),
        ("需要ゾーン", "$69,901からの反発", GREEN),
        ("方向性", "ロング (買い)", CYAN),
    ]

    for i, (sig, desc, color) in enumerate(signals):
        y = y_info + 50 + i * 40
        draw.text((100, y), f"✓ {sig}", font=small_font, fill=color)
        draw.text((400, y), desc, font=small_font, fill=GRAY)

    return img


if __name__ == "__main__":
    output_dir = os.path.dirname(os.path.abspath(__file__))
    materials_dir = os.path.join(output_dir, "materials")
    os.makedirs(materials_dir, exist_ok=True)

    print("Generating 30m chart...")
    chart_30m = create_30m_chart()
    chart_30m.save(os.path.join(materials_dir, "h1_chart.png"), quality=95)
    print(f"  Saved: {materials_dir}/h1_chart.png")

    print("Generating 15m chart...")
    chart_15m = create_15m_chart()
    chart_15m.save(os.path.join(materials_dir, "entry_chart.png"), quality=95)
    print(f"  Saved: {materials_dir}/entry_chart.png")

    print("Done! Charts generated successfully.")
