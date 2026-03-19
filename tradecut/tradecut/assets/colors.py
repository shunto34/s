"""Color palettes derived from Visual Logic Masterpiece indicator."""

# --- VLM Default Palette (matches the MT5 indicator) ---

# Bullish / Buy signals
CYAN = (0, 200, 220)
BULL_BLUE = (0, 180, 255)

# Bearish / Sell signals
ROSE = (220, 50, 80)
BEAR_RED = (255, 55, 55)

# Take Profit
TP_GREEN = (0, 255, 100)

# Cloud colors
CLOUD_GOLD = (255, 210, 50)
CLOUD_BLUE = (40, 140, 255)

# Warning / Neutral
WARNING_ORANGE = (255, 165, 0)

# UI colors
BACKGROUND_DARK = (15, 15, 25)
BACKGROUND_CARD = (25, 25, 40)
TEXT_WHITE = (255, 255, 255)
TEXT_GRAY = (160, 160, 180)
TEXT_SUBTITLE = (200, 200, 210)

# Profit / Loss
PROFIT_GREEN = (0, 220, 100)
LOSS_RED = (255, 60, 60)

# Gradients (top_color, bottom_color)
GRADIENT_BULL = (CYAN, BULL_BLUE)
GRADIENT_BEAR = (ROSE, BEAR_RED)
GRADIENT_DARK = ((20, 20, 35), (10, 10, 20))


def get_direction_color(direction: str) -> tuple[int, int, int]:
    """Get the primary color for a trade direction."""
    return CYAN if direction == "long" else ROSE


def get_result_color(result: str) -> tuple[int, int, int]:
    """Get the color for a trade result."""
    if result == "win":
        return PROFIT_GREEN
    elif result == "loss":
        return LOSS_RED
    return WARNING_ORANGE
