PYTHON ?= python3
.PHONY: all pdf watch reproduce reproduce-legacy petile17 diagrams cost-figures dp-share-figures check test test-legacy clean
all: pdf
pdf:
	latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error main.tex
reproduce:
	$(PYTHON) scripts/reproduce_joint_dse.py
	$(PYTHON) data/process_normalization/normalize_table.py
reproduce-legacy:
	$(PYTHON) scripts/reproduce.py
petile17:
	$(PYTHON) scripts/reproduce_petile17_n12.py
	$(PYTHON) scripts/precision_migration.py
diagrams:
	$(PYTHON) scripts/plot_tensor_dp_background.py
	$(PYTHON) scripts/plot_kn_composition.py
check: reproduce
	$(MAKE) test
test:
	$(PYTHON) -m unittest discover -s scripts -p 'test_hardware_cost.py' -v
	$(PYTHON) -m unittest discover -s scripts -p 'test_joint_dse.py' -v
test-legacy:
	$(PYTHON) scripts/test_parameters.py
clean:
	latexmk -c main.tex

# Editable area/power data; PNG figures only.
cost-figures:
	$(PYTHON) data/DP_area_power/plot_latest6_area_power.py --scope ratios

dp-share-figures:
	$(PYTHON) data/H16Q32E64_area/plot_area.py
	$(PYTHON) data/H16Q32E64_power/plot_power.py

# Optional terminal watcher; Ctrl-C stops it. The VS Code recipe already builds on save.
watch:
	latexmk -pvc -view=none -xelatex -interaction=nonstopmode -halt-on-error -file-line-error main.tex
