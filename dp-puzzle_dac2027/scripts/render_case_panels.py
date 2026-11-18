"""Render the standalone manuscript's case-study figure from frozen results."""
from argparse import ArgumentParser
from csv import DictReader
from hashlib import sha256
import json
from pathlib import Path

from figure_style import COLUMN_WIDTH, configure

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path("data/evidence/v41_five_stage_20261117")


def read_verified(paper, name, manifest):
    path = paper / EVIDENCE / (name + ".csv")
    fingerprint = {
        "path": str(path.relative_to(paper)),
        "sha256": sha256(path.read_bytes()).hexdigest(),
    }
    if fingerprint not in manifest["outputs"]:
        raise ValueError(f"Changed source: {path}")
    with path.open(newline="") as stream:
        return list(DictReader(stream))


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--paper", type=Path, default=ROOT.parent / "paper")
    parser.add_argument("--output", type=Path, default=ROOT / "figures/v41_case_panels_overlay.pdf")
    args = parser.parse_args()
    paper, output = args.paper.resolve(), args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    configure(ROOT / "build" / ".figure-mpl")
    import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    from matplotlib.patches import Rectangle
    import numpy as np

    manifest = json.loads((paper / EVIDENCE / "manifest.json").read_text())
    hardware = read_verified(paper, "hardware", manifest)
    gains = read_verified(paper, "gains", manifest)
    columns = [s["id"] for s in manifest["config"]["scenarios"]] + ["All"]
    ratios = [r["ratio"] for r in hardware]
    area = [int(r["area_only_cores"]) for r in hardware]
    joint = [int(r["cores"]) for r in hardware]
    scores = {(r["ratio"], r["scenario"]): float(r["speedup"]) for r in gains}
    matrix = np.array([[scores[ratio, s] for s in columns] for ratio in ratios])
    assert all(nj <= na for na, nj in zip(area, joint))
    assert np.allclose(matrix[ratios.index("1:2:4")], 1)

    width, height = COLUMN_WIDTH * 72, 179
    fig = plt.figure(figsize=(COLUMN_WIDTH, height / 72))
    bottom, panel_height = 43 / height, 116 / height
    bars = fig.add_axes([31 / width, bottom, 69 / width, panel_height])
    heat = fig.add_axes([107 / width, bottom, (width - 111) / width, panel_height], sharey=bars)
    y = np.arange(len(ratios))
    bars.barh(y, area, height=.78, color="#d5d8dc", edgecolor="#858b92", linewidth=.4)
    bars.barh(y, joint, height=.50, color="#3c5488")
    for i, (na, nj) in enumerate(zip(area, joint)):
        if na != nj:
            bars.text(na + .65, i, str(na), ha="left", va="center", color="#414750")
        bars.text(nj - .65, i, str(nj), ha="right", va="center", color="white")
    bars.set(ylim=(len(ratios)-.5, -.5), xlim=(0, 43), yticks=y, yticklabels=ratios,
             xticks=[0, 20, 40], xlabel="Core count")
    bars.xaxis.set_major_formatter("{x:.0f}")
    bars.tick_params(axis="y", length=0, pad=3)
    bars.tick_params(axis="x", length=2, pad=2)
    bars.xaxis.labelpad = 2
    bars.set_axisbelow(True)
    bars.grid(axis="x", color="#dedede", linewidth=.4)
    bars.set_title("(a)", pad=4)

    lower = min(.9, np.floor(matrix.min()*10)/10)
    upper = max(1.1, np.ceil(matrix.max()*10)/10)
    norm = TwoSlopeNorm(vmin=lower, vcenter=1, vmax=upper)
    image = heat.pcolormesh(np.arange(len(columns)+1)-.5, np.arange(len(ratios)+1)-.5,
                            matrix, cmap="RdBu", norm=norm, shading="flat",
                            antialiased=False)
    heat.set(xlim=(-.5, len(columns)-.5), xticks=np.arange(len(columns)), xticklabels=columns)
    heat.tick_params(axis="y", left=False, labelleft=False)
    heat.tick_params(axis="x", length=0, pad=2)
    heat.set_title("(b)", pad=4)
    heat.axvline(len(columns)-1.5, color="white", linewidth=1.25)
    for i, row in enumerate(matrix):
        for j, value in enumerate(row):
            heat.text(j, i, f"{value:.2f}", ha="center", va="center",
                      color="white" if norm(value) < .16 or norm(value) > .87 else "#202020")
            if np.isclose(value, matrix[:, j].max(), rtol=1e-12):
                heat.add_patch(Rectangle((j-.46, i-.46), .92, .92, fill=False,
                                         edgecolor="#181818", linewidth=.7))
    box = heat.get_position()
    cax = fig.add_axes([box.x0, 17 / height, box.width, 4.5 / height])
    scale = fig.colorbar(image, cax=cax, orientation="horizontal", ticks=[lower, 1, upper])
    scale.solids.set_rasterized(False)
    scale.ax.xaxis.set_major_formatter("{x:.1f}")
    scale.ax.tick_params(pad=1, length=2)
    scale.ax.get_xticklabels()[0].set_ha("left")
    scale.ax.get_xticklabels()[-1].set_ha("right")
    fig.savefig(output, metadata={"CreationDate": None, "ModDate": None})
    plt.close(fig)


if __name__ == "__main__":
    main()
