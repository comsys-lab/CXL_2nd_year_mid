#/bin/bash
set -x

initialize
sleep 5
./Qdrant_Local.sh
./Qdrant_AutoNUMA_1_1.sh
./Qdrant_AutoNUMA_1_2.sh
./Qdrant_AutoNUMA_1_3.sh
./Qdrant_AutoNUMA_1_4.sh
./Qdrant_CXL_only.sh
