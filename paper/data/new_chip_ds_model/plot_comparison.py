"""Plot the observed length distributions and their aggregate speedups."""
import csv
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

RESULTS = Path(__file__).resolve().parent / 'results'


def read(name):
    with (RESULTS/name).open(newline='') as f:
        return list(csv.DictReader(f))


def main():
    weights = read('context_weights.csv')
    scores = [r for r in read('scores.csv') if r['length_method']=='exact' and r['scenario']=='All']
    names = list(dict.fromkeys(r['trace'] for r in scores))
    labels = {'agent_calls':'Agent calls (cold replay)', 'agent_first':'Agent session starts',
              'azure_chat':'Azure conversations', 'uniform_grid':'Uniform context grid'}
    styles = ['o','s','^','D','v']
    width = 0.84 / (len(names)-1)
    fig, (ax, bx) = plt.subplots(2, 1, figsize=(8.4, 5.8), layout='constrained')
    for i, name in enumerate(names):
        baseline = name=='uniform_grid'
        color = '#606060' if baseline else plt.cm.tab10(i % 10)
        label = labels.get(name, name.replace('_',' '))
        if not baseline:
            w = [r for r in weights if r['trace']==name]
            ax.bar([j-0.42+(i+0.5)*width for j in range(len(w))],
                   [100*float(r['weight']) for r in w],width=width,color=color,label=label)
        points = [r for r in scores if r['trace']==name]
        bx.plot(range(len(points)), [float(r['speedup']) for r in points],
                marker=styles[i % len(styles)], ms=4.5, color=color,
                ls='--' if baseline else '-', lw=1.5, label=label)
    ax.set_xticks(range(11), ['1K','2K','4K','8K','16K','32K','64K','128K','256K','512K','1M'])
    ax.set_ylabel('Requests (%)')
    ax.set_xlabel('Prompt-length bin (representative token count)')
    bx.set_xticks(range(len(points)), [r['ratio'] for r in points])
    bx.set_xlabel('BF16 : MXFP8 : MXFP4 peak throughput ratio')
    bx.set_ylabel('Compute speedup vs. 1:2:4')
    bx.axhline(1, color='0.65', lw=.8)
    for a in (ax,bx):
        a.spines[['top','right']].set_visible(False)
        a.grid(axis='y', lw=.4, color='0.85')
        a.set_axisbelow(True)
        a.legend(fontsize=8, frameon=False, ncol=2)
    fig.savefig(RESULTS/'comparison.pdf', metadata={'CreationDate':None,'ModDate':None})
    plt.close(fig)


if __name__ == '__main__':
    main()
