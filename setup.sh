#!/bin/bash

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

show_welcome

# Set work_dir
DEFAULT_PATH=$PWD
read -p "Enter the working directory (Press Enter for default: $DEFAULT_PATH): " USER_WORK_DIR
MAG_QC_WORK_DIR="$(realpath "${USER_WORK_DIR:-$PWD}")"
echo "Working directory set to: $MAG_QC_WORK_DIR"
#echo "export ${MAG_QC_WORK_DIR} >> ~/.bashrc" 

# Define variables to store user responses
declare -A DB_SUBDIRS=(
    ["GTDBTK_PATH"]="GTDBTk_R220"
    ["CHECKM2_PATH"]="CheckM2_database/uniref100.KO.1.dmnd"
    ["CHECKM_PATH"]="checkm_data_2015_01_16"
    ["GUNC_PATH"]="gunc_db_progenomes2.1.dmnd"
)

declare -A DATABASE_PATHS

# Install CheckM2 if not yet installed
while true; do
    read -p "❓ Is CheckM2 Conda environment already installed? (y/n): " CHECKM2_INSTALLED
    case "$CHECKM2_INSTALLED" in
        [Yy]* )
            # Check if the conda environment exists
            if conda env list | grep -q "checkm2"; then
                DEFAULT_CONDA_ENV_DIR=$(conda env list | grep checkm2 | awk '{print $NF}' | sed 's|/checkm2||')
                echo "✅ CheckM2 environment found at: $DEFAULT_CONDA_ENV_DIR"
                
                read -p "📂 Enter the full path to existing CheckM2 database (eg. /path/to/checkm2_db/uniref100.KO.1.dmnd): " CHECKM2_DB_PATH
                DATABASE_PATHS["CHECKM2_PATH"]="$CHECKM2_DB_PATH"
                echo "✅ CheckM2 database path set to: $(realpath "${CHECKM2_DB_PATH}")"
                break
            else
                echo "⚠️ CheckM2 Conda environment not found!"
                read -p "❓ Would you like to reinstall CheckM2? (y/n): " REINSTALL_CHOICE
                if [[ "$REINSTALL_CHOICE" =~ ^[Yy]$ ]]; then
                    CHECKM2_INSTALLED="n"
                else
                    echo "❌ CheckM2 environment is required but was not found. Exiting."
                    exit 1
                fi
            fi
            ;;
        [Nn]* )
            read -p "📂 Enter the directory to install CheckM2 (default: $MAG_QC_WORK_DIR): " CHECKM2_INSTALL_DIR
            CHECKM2_INSTALL_DIR="$(realpath "${CHECKM2_INSTALL_DIR:-$MAG_QC_WORK_DIR}")"
            
            echo "🚀 Installing CheckM2 environment at $CHECKM2_INSTALL_DIR"

            # Install
            cd $CHECKM2_INSTALL_DIR
            git clone --recursive https://github.com/chklovski/checkm2.git && cd checkm2
            conda env create -n checkm2 -f checkm2.yml
            conda activate checkm2
            python setup.py install

            # Verify installation
            if ! command -v checkm2 &> /dev/null; then
                echo "❌ CheckM2 installation failed. Exiting."
                exit 1
            fi

            echo "✅ CheckM2 successfully installed!"

            # Get default Conda environment directory
            DEFAULT_CONDA_ENV_DIR=$(conda env list | grep checkm2 | awk '{print $NF}' | sed 's|/checkm2||')
            echo "📍 Default Conda environment directory: $DEFAULT_CONDA_ENV_DIR"

            # Download CheckM2 database
            read -p "📂 Enter path to install CheckM2 database: " CHECKM2_DB_PATH
            echo "⬇️ Downloading CheckM2 database to $CHECKM2_DB_PATH..."
            checkm2 database --download --path "$CHECKM2_DB_PATH"

            conda deactivate
            DATABASE_PATHS["CHECKM2_PATH"]="$CHECKM2_DB_PATH"
            echo "✅ CheckM2 database downloaded successfully!"
            cd $MAG_QC_WORK_DIR
            break
            ;;
    * ) echo "⚠️ Please answer 'y(es)' or 'n(o)'.";;
    esac
done


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
        "CHECKM_PATH")
            wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz -P $INSTALL_DIR
	    mkdir -p $FINAL_DB_PATH
            tar -xzf "$INSTALL_DIR/checkm_data_2015_01_16.tar.gz" -C "$FINAL_DB_PATH"
            #rm "$INSTALL_DIR/checkm_data_2015_01_16.tar.gz"
            echo "✅ CheckM1 database installed successfully!"
            ;;
        "GUNC_PATH")
            gunc download_db $INSTALL_DIR
	    
            echo "✅ GUNC database installed successfully!"
            ;;
        *)
            echo "⚠️ Unknown database: $DB_NAME"
            ;;
    esac

    DATABASE_PATHS[$DB_VAR_NAME]="$FINAL_DB_PATH"
}

# Function to ask user about each database
ask_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local DB_HINT="$3"
    local DB_PATH=""

    echo "🛠️  Checking for $DB_NAME database..."

    while true; do
        read -p "❓ Do you already have $DB_NAME installed? (y/n): " RESPONSE
        case "$RESPONSE" in
            [Yy]* )
                while true; do
                    read -p "📂 Enter the path to your existing $DB_NAME database (eg. $DB_HINT): " DB_PATH
                    if [[ -d "$DB_PATH" || -f "$DB_PATH" ]]; then
                        DATABASE_PATHS[$DB_VAR_NAME]="$DB_PATH"
                        echo "✅ $DB_NAME path set to: $DB_PATH"
                        return  # Exit the function immediately after successful input
                    else
                        echo "⚠️ The provided path does not exist or is empty. Please check and try again."
                        read -p "Do you want to re-enter the path (r) or install $DB_NAME instead (i)? (r/i): " RETRY
                        if [[ "$RETRY" == "i" ]]; then
                            break  # Exit inner loop to start installation
                        fi
                    fi
                done
                if [[ "$RETRY" == "i" ]]; then
                    break  # Exit outer loop to install the database
                fi
                ;;
            [Nn]* )
                read -p "📂 Enter the directory where you want to install $DB_NAME: " DB_PATH
                install_database "$DB_NAME" "$DB_VAR_NAME" "$DB_PATH"
                return  # Exit function after installation
                ;;
            * ) echo "⚠️ Please enter 'y(es)' or 'n(o)'.";;
        esac
    done
}

# Ask for all required databases
ask_database "GTDB-Tk" "GTDBTK_PATH" "/path/to/gtdbtk_db/"
ask_database "CheckM" "CHECKM_PATH" "/path/to/checkm_db/"
ask_database "GUNC" "GUNC_PATH" "/path/to/gunc_db/gunc_db_progenomes2.1.dmnd"

echo "✅ Setup complete!"


# Install conda env: quast, prokka. 
cd $DEFAULT_PATH #camp_mag_qc
check_conda_env() {
    conda env list | awk '{print $2}' | grep -qx "$DEFAULT_CONDA_ENV_DIR/$1"
}

# Check for Prokka environment
if check_conda_env "prokka"; then
    echo "✅ Prokka environment is already installed in $DEFAULT_CONDA_ENV_DIR."
else
    echo "🚀 Installing Prokka in $DEFAULT_CONDA_ENV_DIR/prokka..."
    conda env create --file configs/conda/prokka.yaml --prefix "$DEFAULT_CONDA_ENV_DIR/prokka"
    echo "✅ Prokka installed successfully!"
fi

# Check for Quast environment
if check_conda_env "quast"; then
    echo "✅ Quast environment is already installed in $DEFAULT_CONDA_ENV_DIR."
else
    echo "🚀 Installing Quast in $DEFAULT_CONDA_ENV_DIR/quast..."
    conda env create --file configs/conda/quast.yaml --prefix "$DEFAULT_CONDA_ENV_DIR/quast"
    echo "✅ Quast installed successfully!"
fi


# --- Generate parameter configs ---

# Create test_data/parameters.yaml
PARAMS_FILE="$DEFAULT_PATH/test_data/parameters.yaml" 

echo "🚀 Generating test_data/parameters.yaml in $PARAMS_FILE ..."

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

echo "🎯 Setup complete! You can now test the workflow using `python workflow/mag_qc.py test`"

