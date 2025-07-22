#!/bin/bash

echo "Combining and extracting mutants csv files..."

cat zmutants/invs_part_* > invs-by-mutants-csv-files.tar.gz
tar -xzf invs-by-mutants-csv-files.tar.gz

rm invs-by-mutants-csv-files.tar.gz
rm zmutants/invs_part_*

echo "All parts have been combined and extracted."