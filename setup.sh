#!/bin/bash

# --- Functions ---

show_welcome() {
    clear  # Clear the screen for a clean look

    echo ""
    sleep 0.2
    echo " _   _      _ _          ____    _    __  __ ____           _ "
    sleep 0.2
    echo "| | | | ___| | | ___    / ___|  / \  |  \/  |  _ \ ___ _ __| |"
    sleep 0.2
    echo "| |_| |/ _ \ | |/ _ \  | |     / _ \ | |\/| | |_) / _ \ '__| |"
    sleep 0.2
    echo "|  _  |  __/ | | (_) | | |___ / ___ \| |  | |  __/  __/ |  |_|"
    sleep 0.2
    echo "|_| |_|\___|_|_|\___/   \____/_/   \_\_|  |_|_|   \___|_|  (_)"
    sleep 0.5

    echo ""
    echo "🌲🏕️  WELCOME TO CAMP SETUP! 🏕️🌲"
    echo "===================================================="
    echo ""
    echo "   🏕️  Configuring Databases & Conda Environments"
    echo "       for CAMP MAG QC"
    echo ""
    echo "   🔥 Let's get everything set up properly!"
    echo ""
    echo "===================================================="
    echo ""

}

# Check to see if the base CAMP environment has already been installed 
find_install_camp_env() {
    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/camp"; then 
        echo "✅ The main CAMP environment is already installed in $DEFAULT_CONDA_ENV_DIR."
    else
        echo "🚀 Installing the main CAMP environment in $DEFAULT_CONDA_ENV_DIR/..."
        conda create --prefix "$DEFAULT_CONDA_ENV_DIR/camp" -c conda-forge -c bioconda biopython blast bowtie2 bumpversion click click-default-group cookiecutter jupyter matplotlib numpy pandas samtools scikit-learn scipy seaborn snakemake=7.32.4 umap-learn upsetplot
        echo "✅ The main CAMP environment has been installed successfully!"
    fi
}

# Check to see if the required conda environments have already been installed 
find_install_conda_env() {
    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/$1"; then
        echo "✅ The $1 environment is already installed in $DEFAULT_CONDA_ENV_DIR."
    else
        echo "🚀 Installing $1 in $DEFAULT_CONDA_ENV_DIR/$1..."
        if [ $1 = 'checkm2' ]; then
            conda create -n checkm2 -c conda-forge -c bioconda python=3.8 checkm2 # CheckM2 requires a specific Python version
        else
            conda create --prefix $DEFAULT_CONDA_ENV_DIR/$1 -c conda-forge -c bioconda $1
        fi
        if [ $1 = 'gunc' ]; then
            conda activate gunc
            conda install -c conda-forge setuptools
            conda deactivate
        fi
        echo "✅ $1 installed successfully!"
    fi
}

# Ask user if each database is already installed or needs to be installed
ask_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local DB_PATH=""

    echo "🛠️  Checking for $DB_NAME database..."

    while true; do
        read -p "❓ Do you already have the $DB_NAME database installed? (y/n): " RESPONSE
        case "$RESPONSE" in
            [Yy]* )
                while true; do
                    read -p "📂 Enter the path to your existing $DB_NAME database (eg. /path/to/database_storage): " DB_PATH
                    if [[ -d "$DB_PATH" || -f "$DB_PATH" ]]; then
                        DATABASE_PATHS[$DB_VAR_NAME]="$DB_PATH"
                        echo "✅ $DB_NAME path set to: $DB_PATH"
                        return  # Exit the function immediately after successful input
                    else
                        echo "⚠️ The provided path does not exist or is empty. Please check and try again."
                        read -p "Do you want to re-enter the path (r) or install $DB_NAME instead (i)? (r/i): " RETRY
                        if [[ "$RETRY" == "i" ]]; then
                            break  # Exit outer loop to start installation
                        fi
                    fi
                done
                ;;
            [Nn]* )
                break # Exit outer loop to start installation
                ;; 
            * ) echo "⚠️ Please enter 'y(es)' or 'n(o)'.";;
        esac
    done
    read -p "📂 Enter the directory where you want to install $DB_NAME: " DB_PATH
    install_database "$DB_NAME" "$DB_VAR_NAME" "$DB_PATH"
}

# Install databases in the specified directory
install_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local INSTALL_DIR="$3"
    local FINAL_DB_PATH="$INSTALL_DIR/${DB_SUBDIRS[$DB_VAR_NAME]}"

    echo "🚀 Installing $DB_NAME database in: $FINAL_DB_PATH"	

    case "$DB_VAR_NAME" in
        "GTDBTK_PATH")
            wget -c https://data.ace.uq.edu.au/public/gtdb/data/releases/release220/220.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r220_data.tar.gz -P $INSTALL_DIR
            mkdir -p $FINAL_DB_PATH
	        tar -xzf "$INSTALL_DIR/gtdbtk_r220_data.tar.gz" -C "$FINAL_DB_PATH"
            #rm "$INSTALL_DIR/gtdbtk_r202_data.tar.gz"
            echo "✅ GTDB-Tk database installed successfully!"
            ;;
        "CHECKM2_PATH")
            conda activate checkm2
            checkm2 database --download --path "$FINAL_DB_PATH"
            conda deactivate
            echo "✅ CheckM2 database downloaded successfully!"
            ;;
        "CHECKM_PATH")
            local ARCHIVE="checkm_data_2015_01_16.tar.gz"
            local DB_URL="https://data.ace.uq.edu.au/public/CheckM_databases/$ARCHIVE"
            # wget -c $DB_URL -P $INSTALL_DIR
            mkdir -p "$FINAL_DB_PATH"
	        tar -xzf "$INSTALL_DIR/$ARCHIVE" -C "$FINAL_DB_PATH"
            echo "✅ CheckM1 database installed successfully!"
            ;;
        "GUNC_PATH")
            conda activate gunc
            gunc download_db $INSTALL_DIR
            conda deactivate
            echo "✅ GUNC database installed successfully!"
            ;;
        *)
            echo "⚠️ Unknown database: $DB_NAME"
            ;;
    esac

    DATABASE_PATHS[$DB_VAR_NAME]="$FINAL_DB_PATH"
}

# --- Initialize setup ---

show_welcome

# Set work_dir
MODULE_WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PATH=$PWD
read -p "Enter the working directory (Press Enter for default: $DEFAULT_PATH): " USER_WORK_DIR
MAG_QC_WORK_DIR="$(realpath "${USER_WORK_DIR:-$PWD}")"
echo "Working directory set to: $MAG_QC_WORK_DIR"
#echo "export ${MAG_QC_WORK_DIR} >> ~/.bashrc" 

# --- Install conda environments ---

cd $MODULE_WORK_DIR
DEFAULT_CONDA_ENV_DIR=$(conda info --base)/envs

# Find or install...

# ...module environment
find_install_camp_env

# ...auxiliary environments
MODULE_PKGS=('checkm2' 'checkm-genome' 'gunc' 'gtdbtk' 'mummer' 'quast' 'prokka') # Add any additional conda packages here
for m in "${MODULE_PKGS[@]}"; do
    find_install_conda_env "$m"
done

# --- Download databases ---

# Define variables to store user responses
declare -A DB_SUBDIRS=(
    ["GTDBTK_PATH"]="GTDBTk_R220"
    ["CHECKM2_PATH"]="CheckM2_database/uniref100.KO.1.dmnd"
    ["CHECKM_PATH"]="checkm_data_2015_01_16"
    ["GUNC_PATH"]="gunc_db_progenomes2.1.dmnd"
)

declare -A DATABASE_PATHS

# Ask for all required databases
ask_database "GTDB-Tk" "GTDBTK_PATH" 
ask_database "CheckM2" "CHECKM2_PATH" 
ask_database "CheckM" "CHECKM_PATH" 
ask_database "GUNC" "GUNC_PATH" 

echo "✅ Setup complete!"

# --- Generate parameter configs ---

# Create test_data/parameters.yaml
PARAMS_FILE="$DEFAULT_PATH/test_data/parameters.yaml" 

echo "🚀 Generating parameter configs ..."

# Default values for analysis parameters
TEST_MIN_CONTIG_LEN=100
REAL_MIN_CONTIG_LEN=1000

# Use existing paths from DATABASE_PATHS
CHECKM2_DB="${DATABASE_PATHS[CHECKM2_PATH]}"
CHECKM1_DB="${DATABASE_PATHS[CHECKM_PATH]}"
DIAMOND_DB="${DATABASE_PATHS[GUNC_PATH]}"
GTDB_DB="${DATABASE_PATHS[GTDBTK_PATH]}"
EXT_PATH="$MAG_QC_WORK_DIR/workflow/ext"  # Assuming extensions are in workflow/ext

# Create test_data/parameters.yaml
cat <<EOL > "$PARAMS_FILE"
# Parameters config

ext: '$EXT_PATH'
conda_prefix: '$DEFAULT_CONDA_ENV_DIR'


# --- checkm --- #
checkm2_db: '$CHECKM2_DB'
checkm1_db: '$CHECKM1_DB'

# --- gunc --- #
diamond_db: '$DIAMOND_DB'

# --- gtdbtk --- #
gtdb_db: '$GTDB_DB'

# --- quast --- #
min_contig_len: $TEST_MIN_CONTIG_LEN
EOL

echo "✅ Configuration file created at: $PARAMS_FILE"
 
# Create configs/parameters.yaml 
PARAMS_FILE="$DEFAULT_PATH/configs/parameters.yaml"

cat <<EOL > "$PARAMS_FILE"
# Parameters config

ext: '$EXT_PATH'
conda_prefix: '$DEFAULT_CONDA_ENV_DIR'


# --- checkm --- #
checkm2_db: '$CHECKM2_DB'
checkm1_db: '$CHECKM1_DB'

# --- gunc --- #
diamond_db: '$DIAMOND_DB'

# --- gtdbtk --- #
gtdb_db: '$GTDB_DB'

# --- quast --- #
min_contig_len: $REAL_MIN_CONTIG_LEN
EOL

echo "✅ Configuration file created at: $PARAMS_FILE"

# --- Generate test data input CSV ---

# Create test_data/samples.csv
INPUT_CSV="$DEFAULT_PATH/test_data/samples.csv" 
MAG_QC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Generating test_data/samples.csv in $INPUT_CSV ..."

cat <<EOL > "$INPUT_CSV"
sample_name,mag_dir,bam
uhgg,$MAG_QC_DIR/test_data/uhgg,$MAG_QC_DIR/test_data/uhgg.sort.bam
EOL

echo "✅ Test data input CSV created at: $INPUT_CSV"

echo "🎯 Setup complete! You can now test the workflow using \`python workflow/mag_qc.py test\`"

