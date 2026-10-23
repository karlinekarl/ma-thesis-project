"""Run model_cvk.gms for several GDP growth rates and plot emissions and marginal costs.

Usage: python3 figures/plot_scenarios.py
Writes figures/*.png in the repo root. Scenario runs go to a temp dir, the model file is not modified.
"""
import csv
import io
import re
import subprocess
import tempfile
from pathlib import Path

import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "thesis-model" / "model_cvk.gms"
FIGDIR = ROOT / "figures"
GAMS_DIR = Path("/Library/Frameworks/GAMS.framework/Versions/Current/Resources")

# (label, growth rate, color = categorical slots 1-3 of the reference palette)
SCENARIOS = [
    ("No growth (0%)", 0.0, "#2a78d6"),
    ("1.5% growth", 0.015, "#eb6834"),
    ("2% growth", 0.02, "#1baf7a"),
]

# abatement vs removal: categorical slots 7-8, so they don't reuse the growth-scenario colors
ABATE_COLOR, REMOVE_COLOR = "#6250d6", "#e34948"

SURFACE, INK, INK2, MUTED, GRID, AXIS = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9", "#c3c2b7"


def run_scenario(growth, workdir):
    src = MODEL.read_text()
    src, n = re.subn(r"(gdp_growth[^/]*/)[0-9.eE+-]+(/)", rf"\g<1>{growth}\2", src)
    assert n == 1, "could not find gdp_growth default in model"
    (workdir / "model.gms").write_text(src)
    subprocess.run([GAMS_DIR / "gams", "model.gms", "lo=2", "o=run.lst"], cwd=workdir, check=True,
                   stdout=subprocess.DEVNULL)
    return workdir / "results.gdx"


def read_series(gdx, name):
    out = subprocess.run([GAMS_DIR / "gdxdump", gdx, f"symb={name}", "format=csv"],
                         capture_output=True, text=True, check=True).stdout
    rows = list(csv.reader(io.StringIO(out)))[1:]
    return [float(r[-1]) for r in sorted(rows, key=lambda r: int(r[0]))]


def style(ax, ylabel):
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(AXIS)
    ax.tick_params(colors=MUTED, length=0, labelsize=9)
    ax.set_ylabel(ylabel, color=INK2, fontsize=10)
    ax.set_xlabel("Year", color=INK2, fontsize=10)


def panel(ax, years, data, key, title, ylabel, zero_line=False):
    style(ax, ylabel)
    ax.set_title(title, loc="left", color=INK, fontsize=11, fontweight="bold")
    if zero_line:
        ax.axhline(0, color=AXIS, linewidth=1)
    for label, g, color in SCENARIOS:
        ax.plot(years, data[label][key], color=color, linewidth=2, label=label)
    ax.set_xlim(years[0], years[-1] + 9)  # room for end labels
    ax.margins(y=0.05)
    end_labels(ax, years[-1], [(data[label][key][-1], f"{g * 100:g}%", color) for label, g, color in SCENARIOS])


def end_labels(ax, x_end, ends):
    """Direct labels at the line ends, spread apart where the lines converge. ends = [(y, text, color)]."""
    lo, hi = ax.get_ylim()
    gap = 0.07 * (hi - lo)
    ends = sorted(ends, key=lambda e: e[0])
    pos = [y for y, _, _ in ends]
    for i in range(1, len(pos)):
        pos[i] = max(pos[i], pos[i - 1] + gap)
    shift = (sum(pos) - sum(y for y, _, _ in ends)) / len(pos)  # keep the group centred on the true ends
    for (y, text, color), py in zip(ends, pos):
        ax.annotate(text, (x_end, y), xytext=(x_end + 2, py - shift),
                    textcoords="data", color=INK2, fontsize=9, va="center",
                    arrowprops=dict(arrowstyle="-", color=color, linewidth=1, shrinkA=0, shrinkB=1))


def make_by_scenario(years, data, keys, fname, suptitle, ylabel, zero_line=False):
    """One panel per growth scenario, abatement and removal curves together. keys = (abatement, removal)."""
    fig, axes = plt.subplots(1, len(SCENARIOS), figsize=(5.6 * len(SCENARIOS), 4.4), facecolor=SURFACE, sharey=True)
    series = [(keys[0], "Abatement", ABATE_COLOR), (keys[1], "Removal (CDR)", REMOVE_COLOR)]
    for ax, (label, g, _) in zip(axes, SCENARIOS):
        style(ax, ylabel)
        ax.set_title(label, loc="left", color=INK, fontsize=11, fontweight="bold")
        if zero_line:
            ax.axhline(0, color=AXIS, linewidth=1)
        for key, name, color in series:
            ax.plot(years, data[label][key], color=color, linewidth=2, label=name)
        ax.set_xlim(years[0], years[-1] + 9)
        ax.margins(y=0.05)
    for ax, (label, _, _) in zip(axes, SCENARIOS):  # after sharey limits are final
        end_labels(ax, years[-1], [(data[label][k][-1], n.split(" ")[0], c) for k, n, c in series])
    axes[0].legend(frameon=False, fontsize=9, labelcolor=INK2, loc="upper left")
    fig.suptitle(suptitle, x=0.01, ha="left", color=INK, fontsize=13, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    FIGDIR.mkdir(exist_ok=True)
    fig.savefig(FIGDIR / fname, dpi=200, facecolor=SURFACE)
    plt.close(fig)


def make_combined(years, data, top_panels, bottom_panels, fname, suptitle):
    fig, axes = plt.subplots(2, 2, figsize=(11.2, 9), facecolor=SURFACE)
    for ax, p in zip(axes.flat, [*top_panels, *bottom_panels]):
        panel(ax, years, data, *p)
    axes[0, 0].legend(frameon=False, fontsize=9, labelcolor=INK2, loc="upper right")
    fig.suptitle(suptitle, x=0.01, ha="left", color=INK, fontsize=13, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.96), h_pad=2.5)
    FIGDIR.mkdir(exist_ok=True)
    fig.savefig(FIGDIR / fname, dpi=200, facecolor=SURFACE)
    plt.close(fig)


def main():
    data = {}
    with tempfile.TemporaryDirectory() as tmp:
        for label, g, _ in SCENARIOS:
            wd = Path(tmp) / f"g{g}"
            wd.mkdir()
            gdx = run_scenario(g, wd)
            gdp, miu, sigma = (read_series(gdx, n) for n in ("GDP", "MIU", "sigma"))
            data[label] = {
                "abated": [s * y * m for s, y, m in zip(sigma, gdp, miu)],  # GtCO2 avoided vs baseline
                "e_cdr": read_series(gdx, "E_CDR"),
                "e_res": read_series(gdx, "E_RES"),
                "e_net": read_series(gdx, "E"),
                "mc_emi": read_series(gdx, "MC_EMI"),
                "mc_cdr": read_series(gdx, "MC_CDR"),
            }
    t0 = 2025
    years = [t0 + i for i in range(1, 101)]

    emission_panels = [("e_res", "Residual emissions", "GtCO2 per year"),
                       ("e_net", "Net emissions (after CDR)", "GtCO2 per year", True)]
    cost_panels = [("mc_emi", "Marginal abatement cost (= carbon price)", "$ per tCO2"),
                   ("mc_cdr", "Marginal cost of carbon removal", "$ per tCO2")]
    make_combined(years, data, emission_panels, cost_panels, "overview.png",
                  "Emissions and marginal costs under different GDP growth rates")
    make_by_scenario(years, data, ("abated", "e_cdr"), "emissions_abatement_vs_removal.png",
                     "Emissions abated vs. removed (CDR), by GDP growth rate", "GtCO2 per year")
    make_by_scenario(years, data, ("mc_emi", "mc_cdr"), "marginal_costs_abatement_vs_removal.png",
                     "Marginal cost of abatement vs. removal (CDR), by GDP growth rate", "$ per tCO2")


if __name__ == "__main__":
    main()
