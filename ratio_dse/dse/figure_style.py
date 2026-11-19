"""Vector figure typography for the standalone 10-pt IEEEtran manuscript."""
import os
from pathlib import Path

TEX_POINTS_PER_INCH = 72.27
COLUMN_WIDTH = 252 / TEX_POINTS_PER_INCH
TEXT_WIDTH = 516 / TEX_POINTS_PER_INCH


def configure(cache: Path) -> None:
    """Use IEEEtran's Times text family and default LaTeX math fonts."""
    os.environ.setdefault("MPLCONFIGDIR", str(cache))
    import matplotlib

    matplotlib.use("Agg")
    matplotlib.rcParams.update({
        "font.family": "serif",
        "font.serif": ["Computer Modern Roman"],
        "font.size": 10,
        "text.usetex": True,
        "text.latex.preamble": r"\usepackage[T1]{fontenc}\renewcommand{\rmdefault}{ptm}",
        "axes.titlesize": 10,
        "axes.titleweight": "normal",
        "axes.labelsize": 10,
        "axes.linewidth": 0.55,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "xtick.labelsize": 10,
        "ytick.labelsize": 10,
        "legend.fontsize": 10,
    })
