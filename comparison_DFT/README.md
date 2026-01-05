# Water Simulation: TIP3P vs Allegro

Compare classical TIP3P force field and Allegro ML potential for water simulation.

## Quick Start

```bash
# Run simulations
./run.sh

# Plot results
python3 plot.py
```

## Requirements

- LAMMPS with Allegro support
- Python 3 with numpy, matplotlib
- Model file: `../outputs/2025-12-23/10-46-15/lammps_allegro.nequip.pt2`

## Files

- `in.tip3p` - TIP3P simulation input
- `in.mlp` - Allegro simulation input
- `run.sh` - Run both simulations
- `plot.py` - Plot RDF comparison
- `data/water.data` - TIP3P structure
- `data/water_atomic.data` - Atomic structure for ML

## Output

- `data/rdf_tip3p.xvg` - TIP3P RDF data
- `data/rdf_mlp.xvg` - Allegro RDF data
- `rdf_comparison.png` - Comparison plot
