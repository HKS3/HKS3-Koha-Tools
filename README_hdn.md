
apt install dos2unix

dos2unix hdn.data

iconv --from-code ISO-8859-1 --to-code UTF-8 --output=hdn.utf8.data hdn.data

CACHE_DIR=./hausdernatur_isbn_cache_dir/ carton exec perl -Ilib bin/hdn_mab2marc.pl hdn.utf8.data mapping_MAB2_MARC21.csv
