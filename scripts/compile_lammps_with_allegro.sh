#!/bin/bash
###############################################################################
# LAMMPS Compilation Script with Allegro ML Potential Support
#
# This script compiles LAMMPS from source with:
# 1. Standard packages for TIP3P water: KSPACE, MOLECULE, RIGID, MISC
# 2. Allegro ML potential support via pair_nequip_allegro
#
# Requirements:
# - CMake (>= 3.15)
# - C++ compiler with C++17 support (g++ >= 7 or clang++ >= 7)
# - MPI library (for parallel builds, optional but recommended)
# - Git
# - wget or curl
#
# Usage:
#   ./compile_lammps_with_allegro.sh [OPTIONS]
#
# Options:
#   --cuda         Use CUDA-enabled LibTorch (requires CUDA toolkit)
#   --cuda-version CUDA version (e.g., 11.7, 11.8, 12.1)
#   --install-dir  Installation directory (default: $HOME/lammps)
#   --clean        Clean build directories before starting
###############################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
INSTALL_DIR="${HOME}/lammps"
LAMMPS_DIR="${INSTALL_DIR}/lammps"
BUILD_DIR="${LAMMPS_DIR}/build"
LIBTORCH_DIR="${INSTALL_DIR}/libtorch"
PAIR_ALLEGRO_REPO="https://github.com/mir-group/pair_nequip_allegro.git"
PAIR_ALLEGRO_DIR="${INSTALL_DIR}/pair_nequip_allegro"
USE_CUDA=false
CUDA_VERSION="11.8"
CLEAN_BUILD=false
CHECKPOINT_FILE=""  # Path to checkpoint file for PyTorch version detection
PYTORCH_VERSION=""  # Detected PyTorch version
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cuda)
            USE_CUDA=true
            shift
            ;;
        --cuda-version)
            CUDA_VERSION="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            LAMMPS_DIR="${INSTALL_DIR}/lammps"
            BUILD_DIR="${LAMMPS_DIR}/build"
            LIBTORCH_DIR="${INSTALL_DIR}/libtorch"
            PAIR_ALLEGRO_DIR="${INSTALL_DIR}/pair_nequip_allegro"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --checkpoint)
            CHECKPOINT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --cuda              Use CUDA-enabled LibTorch"
            echo "  --cuda-version VER  CUDA version (default: 11.8)"
            echo "  --install-dir DIR   Installation directory (default: \$HOME/lammps)"
            echo "  --checkpoint FILE   Path to checkpoint file to detect PyTorch version"
            echo "  --clean             Clean build directories before starting"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "The script will automatically detect PyTorch version from:"
            echo "  1. Checkpoint file (if --checkpoint is provided)"
            echo "  2. Current Python environment (if torch is installed)"
            echo "And download the matching LibTorch version."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Number of processors for parallel build
NUM_PROCS=$(nproc 2>/dev/null || echo 4)

###############################################################################
# Helper Functions
###############################################################################

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

###############################################################################
# Pre-flight Checks
###############################################################################

print_info "Checking prerequisites..."

check_command git
check_command cmake
check_command make

# Check for C++ compiler
if command -v g++ &> /dev/null; then
    CXX_COMPILER=$(which g++)
elif command -v clang++ &> /dev/null; then
    CXX_COMPILER=$(which clang++)
else
    print_error "No C++ compiler found. Please install g++ or clang++."
    exit 1
fi

print_info "Using C++ compiler: $CXX_COMPILER"

# Check CMake version
CMAKE_VERSION=$(cmake --version | head -n1 | cut -d' ' -f3)
print_info "CMake version: $CMAKE_VERSION"

# Check for MPI (optional but recommended)
if command -v mpicc &> /dev/null && command -v mpicxx &> /dev/null; then
    print_info "MPI detected: $(mpicc --version | head -n1)"
    USE_MPI=true
else
    print_warn "MPI not found. Building without MPI support."
    USE_MPI=false
fi

# Check for CUDA if requested
if [ "$USE_CUDA" = true ]; then
    if ! command -v nvcc &> /dev/null; then
        print_error "CUDA requested but nvcc not found. Please install CUDA toolkit."
        exit 1
    fi
    print_info "CUDA version: $(nvcc --version | grep release | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/')"
fi

###############################################################################
# Clean Build (if requested)
###############################################################################

if [ "$CLEAN_BUILD" = true ]; then
    print_info "Cleaning previous build directories..."
    rm -rf "${BUILD_DIR}"
    if [ -d "${LAMMPS_DIR}" ]; then
        rm -rf "${LAMMPS_DIR}/src/USER-ALLEGRO"
    fi
fi

###############################################################################
# Step 1: Clone LAMMPS
###############################################################################

print_info "Step 1/5: Cloning LAMMPS repository..."

mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

if [ -d "${LAMMPS_DIR}" ]; then
    print_warn "LAMMPS directory already exists. Updating..."
    cd "${LAMMPS_DIR}"
    git fetch origin
    git checkout stable
    git pull origin stable
else
    git clone -b stable https://github.com/lammps/lammps.git "${LAMMPS_DIR}"
fi

###############################################################################
# Step 2: Detect PyTorch Version
###############################################################################

print_info "Step 2/6: Detecting PyTorch version..."

# Use the check_pytorch_version.py script to detect version
CHECK_VERSION_SCRIPT="${SCRIPT_DIR}/check_pytorch_version.py"

if [ -f "${CHECK_VERSION_SCRIPT}" ]; then
    # Try to detect version from checkpoint or environment
    if [ -n "${CHECKPOINT_FILE}" ] && [ -f "${CHECKPOINT_FILE}" ]; then
        print_info "Checking PyTorch version from checkpoint: ${CHECKPOINT_FILE}"
        PYTORCH_VERSION=$(python3 "${CHECK_VERSION_SCRIPT}" "${CHECKPOINT_FILE}" 2>/dev/null | tail -1)
    else
        # Try default checkpoint locations
        DEFAULT_CHECKPOINTS=(
            "${SCRIPT_DIR}/../outputs/2025-12-23/10-46-15/best.ckpt"
            "${SCRIPT_DIR}/../outputs/2025-12-23/10-46-15/last.ckpt"
            "${HOME}/coding/allegro/outputs/2025-12-23/10-46-15/best.ckpt"
        )
        
        for ckpt in "${DEFAULT_CHECKPOINTS[@]}"; do
            if [ -f "${ckpt}" ]; then
                print_info "Found checkpoint file: ${ckpt}"
                PYTORCH_VERSION=$(python3 "${CHECK_VERSION_SCRIPT}" "${ckpt}" 2>/dev/null | tail -1)
                CHECKPOINT_FILE="${ckpt}"
                break
            fi
        done
    fi
    
    # If still no version, try from environment
    if [ -z "${PYTORCH_VERSION}" ]; then
        print_info "Checking PyTorch version from Python environment..."
        PYTORCH_VERSION=$(python3 "${CHECK_VERSION_SCRIPT}" 2>/dev/null | tail -1)
    fi
else
    print_warn "check_pytorch_version.py not found. Skipping version detection."
fi

if [ -n "${PYTORCH_VERSION}" ]; then
    print_info "Detected PyTorch version: ${PYTORCH_VERSION}"
else
    print_warn "Could not detect PyTorch version. Will use latest LibTorch."
    PYTORCH_VERSION="latest"
fi

###############################################################################
# Step 3: Download and Setup LibTorch
###############################################################################

print_info "Step 3/6: Downloading and setting up LibTorch..."

cd "${INSTALL_DIR}"

if [ -d "${LIBTORCH_DIR}" ]; then
    print_warn "LibTorch directory already exists. Skipping download."
    print_warn "Remove ${LIBTORCH_DIR} if you want to re-download."
else
    # Build LibTorch URL based on PyTorch version and CUDA settings
    if [ "$USE_CUDA" = true ]; then
        # Map CUDA version to LibTorch URL suffix
        case "$CUDA_VERSION" in
            11.7)
                CUDA_SUFFIX="cu117"
                ;;
            11.8)
                CUDA_SUFFIX="cu118"
                ;;
            12.1)
                CUDA_SUFFIX="cu121"
                ;;
            *)
                print_warn "Unrecognized CUDA version $CUDA_VERSION, using 11.8"
                CUDA_SUFFIX="cu118"
                ;;
        esac
        
        # Build URL with PyTorch version if available
        if [ "${PYTORCH_VERSION}" != "latest" ] && [ -n "${PYTORCH_VERSION}" ]; then
            # Map PyTorch major.minor to LibTorch version
            # For versions like 2.0, 2.1, 2.2, etc., use the same version
            # For 2.8 (which might be a typo for 2.0.8), try 2.0
            # Check if this is a standard PyTorch version
            case "${PYTORCH_VERSION}" in
                2.8|2.9|2.10|2.11|2.12|2.13|2.14|2.15|2.16|2.17|2.18|2.19|2.20|2.21|2.22|2.23|2.24|2.25|2.26|2.27)
                    print_warn "PyTorch ${PYTORCH_VERSION} is not a standard release version."
                    print_warn "Using latest LibTorch instead for compatibility."
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/${CUDA_SUFFIX}/libtorch-cxx11-abi-shared-with-deps-latest.zip"
                    ;;
                2.0|2.1|2.2|2.3|2.4|2.5)
                    LIBTORCH_VERSION="${PYTORCH_VERSION}"
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/${CUDA_SUFFIX}/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}.0.zip"
                    print_info "Attempting to download CUDA-enabled LibTorch ${LIBTORCH_VERSION}.0 (CUDA $CUDA_VERSION)..."
                    ;;
                *)
                    # For unknown versions, try the version directly, with fallback to latest
                    LIBTORCH_VERSION="${PYTORCH_VERSION}"
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/${CUDA_SUFFIX}/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}.0.zip"
                    print_info "Attempting to download CUDA-enabled LibTorch ${LIBTORCH_VERSION}.0 (CUDA $CUDA_VERSION)..."
                    print_warn "If download fails, will fallback to latest version."
                    ;;
            esac
        else
            LIBTORCH_URL="https://download.pytorch.org/libtorch/${CUDA_SUFFIX}/libtorch-cxx11-abi-shared-with-deps-latest.zip"
            print_info "Downloading latest CUDA-enabled LibTorch (CUDA $CUDA_VERSION)..."
        fi
    else
        # CPU version
        if [ "${PYTORCH_VERSION}" != "latest" ] && [ -n "${PYTORCH_VERSION}" ]; then
            # Check if this is a standard PyTorch version
            case "${PYTORCH_VERSION}" in
                2.8|2.9|2.10|2.11|2.12|2.13|2.14|2.15|2.16|2.17|2.18|2.19|2.20|2.21|2.22|2.23|2.24|2.25|2.26|2.27)
                    print_warn "PyTorch ${PYTORCH_VERSION} is not a standard release version."
                    print_warn "Using latest LibTorch instead for compatibility."
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip"
                    ;;
                2.0|2.1|2.2|2.3|2.4|2.5)
                    LIBTORCH_VERSION="${PYTORCH_VERSION}"
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}.0.zip"
                    print_info "Attempting to download CPU-only LibTorch ${LIBTORCH_VERSION}.0..."
                    ;;
                *)
                    # For unknown versions, try the version directly, with fallback to latest
                    LIBTORCH_VERSION="${PYTORCH_VERSION}"
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}.0.zip"
                    print_info "Attempting to download CPU-only LibTorch ${LIBTORCH_VERSION}.0..."
                    print_warn "If download fails, will fallback to latest version."
                    ;;
            esac
        else
            LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip"
            print_info "Downloading latest CPU-only LibTorch..."
        fi
    fi
    
    # Download LibTorch (with fallback to latest if versioned URL fails)
    print_info "Downloading from: ${LIBTORCH_URL}"
    
    if command -v wget &> /dev/null; then
        if ! wget --progress=bar:force -O libtorch.zip "${LIBTORCH_URL}" 2>&1; then
            # If versioned URL fails, try latest
            if [ "${PYTORCH_VERSION}" != "latest" ] && [ -n "${PYTORCH_VERSION}" ]; then
                print_warn "Failed to download versioned LibTorch, trying latest version..."
                if [ "$USE_CUDA" = true ]; then
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/${CUDA_SUFFIX}/libtorch-cxx11-abi-shared-with-deps-latest.zip"
                else
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip"
                fi
                print_info "Downloading from: ${LIBTORCH_URL}"
                wget --progress=bar:force -O libtorch.zip "${LIBTORCH_URL}" || {
                    print_error "Failed to download LibTorch. Please check your internet connection."
                    exit 1
                }
            else
                print_error "Failed to download LibTorch. Please check your internet connection."
                exit 1
            fi
        fi
    elif command -v curl &> /dev/null; then
        if ! curl -L --progress-bar -f -o libtorch.zip "${LIBTORCH_URL}"; then
            # If versioned URL fails, try latest
            if [ "${PYTORCH_VERSION}" != "latest" ] && [ -n "${PYTORCH_VERSION}" ]; then
                print_warn "Failed to download versioned LibTorch, trying latest version..."
                if [ "$USE_CUDA" = true ]; then
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/${CUDA_SUFFIX}/libtorch-cxx11-abi-shared-with-deps-latest.zip"
                else
                    LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip"
                fi
                print_info "Downloading from: ${LIBTORCH_URL}"
                curl -L --progress-bar -f -o libtorch.zip "${LIBTORCH_URL}" || {
                    print_error "Failed to download LibTorch. Please check your internet connection."
                    exit 1
                }
            else
                print_error "Failed to download LibTorch. Please check your internet connection."
                exit 1
            fi
        fi
    else
        print_error "Neither wget nor curl found. Please install one of them."
        exit 1
    fi
    
    if [ ! -f libtorch.zip ]; then
        print_error "Downloaded file not found. Download may have failed."
        exit 1
    fi
    
    # Extract LibTorch
    print_info "Extracting LibTorch..."
    unzip -q libtorch.zip -d "${INSTALL_DIR}"
    rm libtorch.zip
    
    # Verify extraction - LibTorch might be extracted to a nested directory
    if [ ! -d "${LIBTORCH_DIR}" ]; then
        # Check if libtorch was extracted to a nested directory
        if [ -d "${INSTALL_DIR}/libtorch/libtorch" ]; then
            LIBTORCH_DIR="${INSTALL_DIR}/libtorch/libtorch"
        else
            # Find where libtorch was actually extracted
            FOUND_LIBTORCH=$(find "${INSTALL_DIR}" -maxdepth 2 -type d -name "libtorch" | head -1)
            if [ -n "${FOUND_LIBTORCH}" ]; then
                LIBTORCH_DIR="${FOUND_LIBTORCH}"
            else
                print_error "LibTorch extraction failed. Check the download."
                exit 1
            fi
        fi
    fi
fi

print_info "LibTorch located at: ${LIBTORCH_DIR}"

###############################################################################
# Step 4: Download and Setup pair_nequip_allegro
###############################################################################

print_info "Step 4/6: Downloading and setting up pair_nequip_allegro..."

cd "${INSTALL_DIR}"

if [ -d "${PAIR_ALLEGRO_DIR}" ]; then
    print_warn "pair_nequip_allegro directory already exists. Updating..."
    cd "${PAIR_ALLEGRO_DIR}"
    git fetch origin
    git pull origin main || git pull origin master
else
    git clone "${PAIR_ALLEGRO_REPO}" "${PAIR_ALLEGRO_DIR}"
fi

# Install pair_allegro to LAMMPS src/USER-ALLEGRO directory
# LAMMPS USER packages should be placed in src/USER-PKGNAME
USER_ALLEGRO_DIR="${LAMMPS_DIR}/src/USER-ALLEGRO"
print_info "Installing pair_allegro as USER-ALLEGRO package..."

if [ -d "${USER_ALLEGRO_DIR}" ]; then
    print_warn "USER-ALLEGRO directory already exists. Removing old version..."
    rm -rf "${USER_ALLEGRO_DIR}"
fi

# Copy the pair_allegro source files to USER-ALLEGRO
mkdir -p "${USER_ALLEGRO_DIR}"

# Check the structure of pair_nequip_allegro repository and copy files appropriately
# The repository structure may vary, so we try multiple approaches
if [ -f "${PAIR_ALLEGRO_DIR}/pair_allegro.cpp" ]; then
    # Files are directly in the repository root
    print_info "Found pair_allegro files in repository root..."
    cp -r "${PAIR_ALLEGRO_DIR}"/* "${USER_ALLEGRO_DIR}/" 2>/dev/null || true
    # Exclude .git and other non-essential files
    rm -rf "${USER_ALLEGRO_DIR}/.git" 2>/dev/null || true
    rm -rf "${USER_ALLEGRO_DIR}/README.md" 2>/dev/null || true
elif [ -d "${PAIR_ALLEGRO_DIR}/pair_allegro" ]; then
    # Files are in a pair_allegro subdirectory
    print_info "Found pair_allegro files in subdirectory..."
    cp -r "${PAIR_ALLEGRO_DIR}/pair_allegro"/* "${USER_ALLEGRO_DIR}/"
elif [ -d "${PAIR_ALLEGRO_DIR}/src" ]; then
    # Files might be in src subdirectory
    print_info "Found pair_allegro files in src subdirectory..."
    cp -r "${PAIR_ALLEGRO_DIR}/src"/* "${USER_ALLEGRO_DIR}/"
else
    # Try to find and copy source files individually
    print_info "Searching for pair_allegro source files..."
    find "${PAIR_ALLEGRO_DIR}" -maxdepth 3 -name "pair_allegro.cpp" -exec cp {} "${USER_ALLEGRO_DIR}/" \; 2>/dev/null || true
    find "${PAIR_ALLEGRO_DIR}" -maxdepth 3 -name "pair_nequip_allegro.cpp" -exec cp {} "${USER_ALLEGRO_DIR}/" \; 2>/dev/null || true
    find "${PAIR_ALLEGRO_DIR}" -maxdepth 3 \( -name "*.h" -o -name "*.hpp" \) -exec cp {} "${USER_ALLEGRO_DIR}/" \; 2>/dev/null || true
    find "${PAIR_ALLEGRO_DIR}" -maxdepth 3 -name "CMakeLists.txt" -exec cp {} "${USER_ALLEGRO_DIR}/" \; 2>/dev/null || true
fi

# Ensure we have the necessary files (try different possible names)
if [ ! -f "${USER_ALLEGRO_DIR}/pair_allegro.cpp" ] && [ ! -f "${USER_ALLEGRO_DIR}/pair_nequip_allegro.cpp" ]; then
    print_error "Could not find pair_allegro source files."
    print_error "Repository structure might be different. Please check: ${PAIR_ALLEGRO_DIR}"
    print_error "Expected files: pair_allegro.cpp or pair_nequip_allegro.cpp"
    print_info "Listing repository contents:"
    ls -la "${PAIR_ALLEGRO_DIR}" | head -20
    exit 1
fi

print_info "pair_allegro installed to: ${USER_ALLEGRO_DIR}"

###############################################################################
# Step 5: Configure LAMMPS with CMake
###############################################################################

print_info "Step 5/6: Configuring LAMMPS with CMake..."

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Base CMake command
CMAKE_ARGS=(
    "${LAMMPS_DIR}/cmake"
    -D CMAKE_BUILD_TYPE=Release
    -D CMAKE_CXX_COMPILER="${CXX_COMPILER}"
    -D BUILD_MPI="${USE_MPI}"
    -D PKG_KSPACE=ON
    -D PKG_MOLECULE=ON
    -D PKG_RIGID=ON
    -D PKG_MISC=ON
    -D PKG_USER-ALLEGRO=ON
    -D CMAKE_PREFIX_PATH="${LIBTORCH_DIR}"
    -D Torch_DIR="${LIBTORCH_DIR}/share/cmake/Torch"
    -D LAMMPS_EXCEPTIONS=ON
    -D CMAKE_CXX_FLAGS="-D_GLIBCXX_USE_CXX11_ABI=1"
)

# Add CUDA support if requested
if [ "$USE_CUDA" = true ]; then
    CMAKE_ARGS+=(
        -D PKG_USER-CUDA=ON
        -D CUDA_TOOLKIT_ROOT_DIR="${CUDA_HOME:-/usr/local/cuda}"
    )
    print_info "Configuring with CUDA support..."
fi

# Add MPI-specific settings if MPI is available
if [ "$USE_MPI" = true ]; then
    CMAKE_ARGS+=(
        -D BUILD_MPI=yes
        -D CMAKE_C_COMPILER="$(which mpicc)"
        -D CMAKE_CXX_COMPILER="$(which mpicxx)"
    )
fi

print_info "Running CMake with the following configuration:"
print_info "  Packages: KSPACE, MOLECULE, RIGID, MISC, USER-ALLEGRO"
print_info "  LibTorch: ${LIBTORCH_DIR}"
print_info "  Build type: Release"

cmake "${CMAKE_ARGS[@]}"

###############################################################################
# Step 6: Compile LAMMPS
###############################################################################

print_info "Step 6/6: Compiling LAMMPS (using ${NUM_PROCS} cores)..."

make -j"${NUM_PROCS}"

# Check if compilation was successful
if [ -f "${BUILD_DIR}/lmp" ] || [ -f "${BUILD_DIR}/lmp_serial" ]; then
    print_info "Compilation completed successfully!"
    
    # Find the LAMMPS executable
    if [ -f "${BUILD_DIR}/lmp" ]; then
        LAMMPS_EXE="${BUILD_DIR}/lmp"
    else
        LAMMPS_EXE="${BUILD_DIR}/lmp_serial"
    fi
    
    print_info "LAMMPS executable: ${LAMMPS_EXE}"
    
    # Test the executable
    print_info "Testing LAMMPS installation..."
    if "${LAMMPS_EXE}" -help &> /dev/null; then
        print_info "LAMMPS is working correctly!"
        
        # Check if packages are available
        PACKAGES_OUTPUT=$("${LAMMPS_EXE}" -h 2>&1 | grep -i "packages" || true)
        if [ -n "${PACKAGES_OUTPUT}" ]; then
            print_info "Installed packages:"
            "${LAMMPS_EXE}" -h 2>&1 | grep -A 100 "Packages:" | head -20
        fi
    else
        print_warn "Could not verify LAMMPS installation."
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "LAMMPS executable: ${LAMMPS_EXE}"
    echo "LibTorch: ${LIBTORCH_DIR}"
    if [ -n "${PYTORCH_VERSION}" ] && [ "${PYTORCH_VERSION}" != "latest" ]; then
        echo "PyTorch version (detected): ${PYTORCH_VERSION}"
    fi
    if [ -n "${CHECKPOINT_FILE}" ]; then
        echo "Checkpoint file used: ${CHECKPOINT_FILE}"
    fi
    echo "Packages enabled: KSPACE, MOLECULE, RIGID, MISC, USER-ALLEGRO"
    if [ "$USE_CUDA" = true ]; then
        echo "CUDA support: Enabled (version $CUDA_VERSION)"
    else
        echo "CUDA support: Disabled (CPU-only)"
    fi
    echo ""
    echo "To use LAMMPS, add to your PATH:"
    echo "  export PATH=\"${BUILD_DIR}:\$PATH\""
    echo ""
    echo "Or create a symlink:"
    echo "  sudo ln -s ${LAMMPS_EXE} /usr/local/bin/lmp"
    
else
    print_error "Compilation failed! Check the error messages above."
    exit 1
fi

