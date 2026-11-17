"""Transpose current native-process comparison into a legible single-column draft table."""
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONDITIONS = ROOT/'tables/related_ppa_native.tex'
VALUES = ROOT/'data/evidence/related_native_dc_area_20261117/efficiencies.csv'
TABLE = ROOT/'tables/temp/related_ppa_compact.tex'
OUT = ROOT/'data/evidence/related_compact_20261117'


def main():
    source = CONDITIONS.read_text()
    conditions = {}
    for field in ('Technology (nm)', 'Voltage (V)', 'Frequency (GHz)', 'Accumulation'):
        line = next(s for s in source.splitlines() if s.startswith(field+' &'))
        cells = line.removesuffix(r' \\').split(' & ')[1:]
        assert len(cells) == 8
        conditions[field] = cells
    values = list(csv.DictReader(VALUES.open()))
    designs = [
        ('tenfour', '', r'Ten-Four~\cite{rout2026tenfourv3}', ['BF16','MXFP8']),
        ('mpicc', '', r'MPICC~\cite{huangMPICCMultiplePrecisionInterCombined2025}', ['FP8','FP4']),
        ('mxdotp', '', r'MXDOTP~\cite{islamoglu2025mxdotp}', ['MXFP8']),
        ('fpnew', '', r'FPnew~\cite{mach2021fpnew}', ['FP16','BF16','FP8']),
        ('minifloats', '', r'MiniFloats~\cite{bertaccini2024minifloats}', ['FP8','FP16']),
        ('transdot', '', r'TransDot~\cite{transdot2026}', ['FP16','FP8','FP4']),
        ('ours', '1:2:4', r'DP-Puzzle $1:2:4$', ['BF16','MXFP8','MXFP4']),
        ('ours', '0:2:4', r'DP-Puzzle $0:2:4$', ['MXFP8','MXFP4']),
    ]
    def stack(items, align='l'):
        return r'\begin{tabular}[c]{@{}'+align+r'@{}}'+r'\\'.join(items)+r'\end{tabular}'
    checked = []
    def efficiency(work, config, precision, metric):
        selected = [r for r in values if r['work']==work and r['format']==precision and r['metric']==metric
                    and (work=='tenfour' or r['config']==config)]
        if not selected:
            assert work=='tenfour' and metric=='energy'
            return '---'
        assert len(selected) == (2 if work=='tenfour' else 1)
        numbers = [f"{float(r['value']):.2f}" for r in selected]
        for r, number in zip(selected, numbers):
            assert number in source, (work, precision, metric, number)
            checked.append(dict(r, displayed=number))
        display = '/'.join(numbers)
        return r'$\approx '+display+r'^{\dagger}$' if selected[0]['status']=='figure_read_estimate' else display
    lines = [r'% Generated from the current shared comparison values; temporary single-column layout.',
        r'\begin{table}[t]', r'\centering',
        r'\caption{Implementation conditions and efficiency at the reported process nodes.}',
        r'\label{tab:related_dp}',
        r'\begingroup\footnotesize\setlength{\tabcolsep}{2pt}',
        r'\renewcommand{\arraystretch}{0.95}',
        r'\begin{tabular*}{\columnwidth}{@{\extracolsep{\fill}}lclrr@{}}\toprule',
        r'\shortstack[l]{Design\\Accumulation} & nm/V/GHz & Format & AE & EE \\\midrule']
    for i, (work, config, label, formats) in enumerate(designs):
        if work=='ours' and config=='1:2:4':
            lines.append(r'\midrule')
        cells = [stack([label, r'{\scriptsize '+conditions['Accumulation'][i]+'}']),
                 '/'.join(conditions[f][i] for f in ('Technology (nm)','Voltage (V)','Frequency (GHz)')),
                 stack(formats),
                 stack([efficiency(work,config,p,'area') for p in formats], 'r'),
                 stack([efficiency(work,config,p,'energy') for p in formats], 'r')]
        lines.append(' & '.join(cells)+r' \\[1pt]')
    lines += [r'\bottomrule\end{tabular*}', r'\par\vspace{2pt}',
        r'\parbox{\columnwidth}{\scriptsize\raggedright',
        r'AE: TFLOP/s/mm$^2$; EE: TFLOP/s/W. Original process nodes; no technology scaling.',
        r'Ten-Four pairs denote Q8/Q16. MiniFloats uses the standalone wDotp FPU.',
        r'$\dagger$: TransDot area estimated from Fig.~7(a) at 1\,ns; throughput from Table~II.',
        r'---: unreported. Supported formats: Table~\ref{tab:related_features}.}',
        r'\endgroup', r'\end{table}']
    TABLE.write_text('\n'.join(lines)+'\n')
    OUT.mkdir(parents=True, exist_ok=True)
    checked_file = OUT/'displayed_efficiencies.csv'
    with checked_file.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(checked[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(checked)
    def fp(path):
        return dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    (OUT/'manifest.json').write_text(json.dumps(dict(scope='Temporary Table IV, single-column layout',
        inputs=[fp(p) for p in (CONDITIONS, VALUES, Path(__file__))],
        outputs=[fp(p) for p in (TABLE, checked_file)],
        checks=dict(designs=len(designs), efficiency_values=len(checked), values_match_current_shared_table=True),
        policy='Use current shared-table conditions and latest recorded efficiencies, preserve precision/accumulation labels and estimate markers.'), indent=2)+'\n')
    print(f'Wrote single-column Table IV: {len(designs)} designs, {len(checked)} efficiency values.')


if __name__ == '__main__':
    main()
