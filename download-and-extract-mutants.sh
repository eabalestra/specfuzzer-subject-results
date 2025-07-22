#!/bin/bash

# List of all invs_part_* files in the zmutants folder
files=(invs_part_aa invs_part_ab invs_part_ac invs_part_ad)

for file in "${files[@]}"; do
  curl -O "https://raw.githubusercontent.com/eabalestra/specfuzzer-subject-results/main/zmutants/$file"
done

cat invs_part_* > invs-by-mutants-csv-files.tar.gz
tar -xzf invs-by-mutants-csv-files.tar.gz

rm invs-by-mutants-csv-files.tar.gz
rm invs_part_*

echo "All parts have been combined and extracted."