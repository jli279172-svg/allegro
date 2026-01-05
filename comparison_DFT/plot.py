#!/usr/bin/env python3
"""Plot RDF comparison between TIP3P and Allegro"""

import numpy as np
import matplotlib.pyplot as plt

def load_rdf(filename):
    """Load RDF data from xvg file"""
    try:
        # Read file and find data section (skip header with TimeStep line)
        with open(filename, 'r') as f:
            lines = f.readlines()
        
        # Find where data starts (after "# Row c_rdf1[1] ..." line)
        data_start = 0
        for i, line in enumerate(lines):
            if line.strip().startswith('# Row'):
                data_start = i + 1
                break
        
        # Read data lines, skip lines with wrong number of columns
        data_lines = []
        for line in lines[data_start:]:
            line = line.strip()
            if line and not line.startswith('#'):
                parts = line.split()
                if len(parts) >= 8:  # Expect 8 columns
                    data_lines.append(line)
        
        if not data_lines:
            print(f"Warning: No data found in {filename}")
            return None, None, None, None
        
        # Load data using numpy
        from io import StringIO
        data_str = '\n'.join(data_lines)
        data = np.loadtxt(StringIO(data_str))
        
        # Column mapping: 0=Row(distance), 1=g_OO, 3=g_HO, 5=g_HH
        r = data[:, 0]  # Distance (Å)
        g_oo = data[:, 1]  # O-O RDF
        g_oh = data[:, 3] if data.shape[1] > 3 else None  # O-H RDF (actually H-O)
        g_hh = data[:, 5] if data.shape[1] > 5 else None  # H-H RDF
        
        return r, g_oo, g_oh, g_hh
    except Exception as e:
        print(f"Error loading {filename}: {e}")
        import traceback
        traceback.print_exc()
        return None, None, None, None

def main():
    # Load data
    r_tip3p, g_oo_tip3p, g_oh_tip3p, g_hh_tip3p = load_rdf('data/rdf_tip3p.xvg')
    r_mlp, g_oo_mlp, g_oh_mlp, g_hh_mlp = load_rdf('data/rdf_mlp.xvg')
    
    if r_tip3p is None or r_mlp is None:
        print("Error: Could not load RDF data")
        return
    
    # Plot
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))
    
    axes[0].plot(r_tip3p, g_oo_tip3p, label='TIP3P', linewidth=2)
    axes[0].plot(r_mlp, g_oo_mlp, label='Allegro', linewidth=2, linestyle='--')
    axes[0].set_xlabel('r (Å)')
    axes[0].set_ylabel('g(r)')
    axes[0].set_title('O-O RDF')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    if g_oh_tip3p is not None and g_oh_mlp is not None:
        axes[1].plot(r_tip3p, g_oh_tip3p, label='TIP3P', linewidth=2)
        axes[1].plot(r_mlp, g_oh_mlp, label='Allegro', linewidth=2, linestyle='--')
        axes[1].set_xlabel('r (Å)')
        axes[1].set_ylabel('g(r)')
        axes[1].set_title('O-H RDF')
        axes[1].legend()
        axes[1].grid(True, alpha=0.3)
    
    if g_hh_tip3p is not None and g_hh_mlp is not None:
        axes[2].plot(r_tip3p, g_hh_tip3p, label='TIP3P', linewidth=2)
        axes[2].plot(r_mlp, g_hh_mlp, label='Allegro', linewidth=2, linestyle='--')
        axes[2].set_xlabel('r (Å)')
        axes[2].set_ylabel('g(r)')
        axes[2].set_title('H-H RDF')
        axes[2].legend()
        axes[2].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('outputs/rdf_comparison.png', dpi=150)
    print("Saved: outputs/rdf_comparison.png")

if __name__ == '__main__':
    main()

