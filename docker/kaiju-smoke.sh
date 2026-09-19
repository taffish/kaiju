#!/bin/sh
set -eu

mode="${1:-all}"
tmp="${2:-/tmp/taf-kaiju-smoke-$$}"

if [ "${mode}" = "all" ]; then
    for part in interfaces buildtime classify postprocess index gbk; do
        "$0" "${part}" "${tmp}-${part}"
    done
    exit 0
fi

case "${tmp}" in
    /tmp/taf-kaiju-*) ;;
    *)
        echo "temporary path must start with /tmp/taf-kaiju-" >&2
        exit 2
        ;;
esac

tmp=$(mktemp -d "${tmp}.XXXXXX")
cleanup() {
    code=$?
    trap - EXIT
    if [ "$code" -ne 0 ]; then
        echo "kaiju-smoke: stage=${mode} exit=${code}" >&2
        find "$tmp" -name '*.log' -type f -exec tail -n 60 {} \; >&2
    fi
    rm -rf "${tmp}"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
cd "${tmp}"

write_taxonomy() {
    printf '1\t|\t1\t|\tno rank\t|\n' > nodes.dmp
    printf '2\t|\t1\t|\tsuperkingdom\t|\n' >> nodes.dmp
    printf '10239\t|\t1\t|\tsuperkingdom\t|\n' >> nodes.dmp
    printf '1224\t|\t2\t|\tphylum\t|\n' >> nodes.dmp
    printf '561\t|\t1224\t|\tgenus\t|\n' >> nodes.dmp
    printf '562\t|\t561\t|\tspecies\t|\n' >> nodes.dmp

    printf '1\t|\troot\t|\t\t|\tscientific name\t|\n' > names.dmp
    printf '2\t|\tBacteria\t|\t\t|\tscientific name\t|\n' >> names.dmp
    printf '10239\t|\tViruses\t|\t\t|\tscientific name\t|\n' >> names.dmp
    printf '1224\t|\tPseudomonadota\t|\t\t|\tscientific name\t|\n' >> names.dmp
    printf '561\t|\tEscherichia\t|\t\t|\tscientific name\t|\n' >> names.dmp
    printf '562\t|\tEscherichia coli\t|\t\t|\tscientific name\t|\n' >> names.dmp
    : > merged.dmp
}

write_sequences() {
    unit='ACDEFGHIKLMNPQRSTVWY'
    query="${unit}${unit}${unit}"
    dna='GCTTGTGATGAATTTGGTCATATTAAACTGATGAATCCTCAACGTTCTACTGTTTGGTATGCTTGTGATGAATTTGGTCATATTAAACTGATGAATCCTCAACGTTCTACTGTTTGGTATGCTTGTGATGAATTTGGTCATATTAAACTGATGAATCCTCAACGTTCTACTGTTTGGTAT'
    : > proteins.faa
    record=1
    while [ "${record}" -le 20 ]; do
        background=$(awk -v seed="${record}" 'BEGIN {
            aa = "ACDEFGHIKLMNPQRSTVWY"; x = seed * 29 + 17
            for (i = 1; i <= 500; i++) {
                x = (x * 37 + 11) % 997
                printf "%s", substr(aa, (x % 20) + 1, 1)
            }
        }')
        if [ "${record}" -eq 1 ]; then
            printf '>tinyProtein_562 synthetic query-bearing reference\n%s%s\n' \
              "${background}" "${query}" >> proteins.faa
        else
            printf '>background%s_562 synthetic background reference\n%s\n' \
              "${record}" "${background}" >> proteins.faa
        fi
        record=$((record + 1))
    done
    printf '>read_protein\n%s\n' "${query}" > protein-query.faa
    printf '>read_dna\n%s\n' "${dna}" > dna-query.fna
}

prepare_fixture() {
    write_taxonomy
    write_sequences
}

build_tiny_index() {
    kaiju-mkbwt -n 2 -a ACDEFGHIKLMNPQRSTVWY -o tiny proteins.faa > mkbwt.log 2>&1
    kaiju-mkfmi tiny > mkfmi.log 2>&1
    test -s tiny.fmi
}

assert_classified() {
    file=$1
    read_name=$2
    grep -F "$(printf 'C\t%s\t562' "${read_name}")" "${file}" >/dev/null
}

case "${mode}" in
    interfaces)
        kaiju -h 2>&1 | grep -Fx 'Kaiju 1.10.3' >/dev/null
        kaiju -h 2>&1 | grep -F 'Name of database (.fmi) file' >/dev/null
        kaiju-multi -h 2>&1 | grep -F 'List of input files containing reads' >/dev/null
        kaijup -h 2>&1 | grep -F 'Disable SEG low complexity filter' >/dev/null
        kaijux -h 2>&1 | grep -F 'Disable SEG low complexity filter' >/dev/null
        kaiju2krona -h 2>&1 | grep -F 'nodes.dmp' >/dev/null
        kaiju2table -h 2>&1 | grep -F 'species' >/dev/null
        kaiju-addTaxonNames -h 2>&1 | grep -F 'names.dmp' >/dev/null
        kaiju-mergeOutputs -h 2>&1 | grep -F 'lca' >/dev/null
        kaiju-convertNR -h 2>&1 | grep -F 'prot.accession2taxid' >/dev/null
        kaiju-convertRefSeq -h 2>&1 | grep -F 'prot.accession2taxid.FULL.gz' >/dev/null
        kaiju-mkbwt -h 2>&1 | grep -F 'Prints summary of options and arguments' >/dev/null
        kaiju-mkfmi -h 2>&1 | grep -F 'Prints summary of options and arguments' >/dev/null
        kaiju-makedb --help 2>&1 | grep -F -- '--index-only' >/dev/null
        kaiju-gbk2faa.pl 2>&1 | grep -F 'infile.gbk outfile.faa' >/dev/null
        test -r /opt/kaiju/bin/kaiju-taxonlistEuk.tsv
        test -r /opt/kaiju/bin/kaiju-excluded-accessions.txt
        perl -MIO::Uncompress::AnyUncompress -e 'exit 0'
        for name in \
          kaiju kaiju-multi kaijup kaijux kaiju2krona kaiju2table \
          kaiju-addTaxonNames kaiju-mergeOutputs kaiju-convertNR \
          kaiju-convertRefSeq kaiju-mkbwt kaiju-mkfmi; do
            ldd "$(command -v "${name}")" >> ldd.txt 2>&1
        done
        if grep -F 'not found' ldd.txt; then exit 1; fi
        ;;
    buildtime)
        prepare_fixture
        build_tiny_index
        kaiju -a mem -m 11 -p -X -z 1 \
          -t nodes.dmp -f tiny.fmi -i protein-query.faa -o kaiju.out
        assert_classified kaiju.out read_protein
        kaijup -a mem -m 11 -X -z 1 \
          -f tiny.fmi -i protein-query.faa -o kaijup.out
        grep -F 'tinyProtein_562' kaijup.out >/dev/null
        ;;
    classify)
        prepare_fixture
        build_tiny_index
        gzip -c dna-query.fna > dna-query.fna.gz

        kaiju -a mem -m 11 -X -z 1 \
          -t nodes.dmp -f tiny.fmi -i dna-query.fna -o dna.out
        assert_classified dna.out read_dna

        kaiju -a mem -m 11 -p -X -z 1 \
          -t nodes.dmp -f tiny.fmi -i protein-query.faa -o protein.out
        assert_classified protein.out read_protein

        kaiju -a mem -m 11 -X -z 1 \
          -t nodes.dmp -f tiny.fmi -i dna-query.fna.gz -o compressed.out
        assert_classified compressed.out read_dna

        kaiju-multi -a mem -m 11 -p -X -z 1 \
          -t nodes.dmp -f tiny.fmi \
          -i protein-query.faa,protein-query.faa \
          -o multi-1.out,multi-2.out
        assert_classified multi-1.out read_protein
        assert_classified multi-2.out read_protein

        kaijup -a mem -m 11 -X -z 1 \
          -f tiny.fmi -i protein-query.faa -o kaijup.out
        kaijux -a mem -m 11 -X -z 1 \
          -f tiny.fmi -i dna-query.fna -o kaijux.out
        grep -F 'tinyProtein_562' kaijup.out >/dev/null
        grep -F 'tinyProtein_562' kaijux.out >/dev/null
        ;;
    postprocess)
        write_taxonomy
        printf 'C\tread_a\t562\nU\tread_b\t0\n' > sample-1.out
        printf 'C\tread_a\t561\nU\tread_b\t0\n' > sample-2.out

        kaiju-addTaxonNames -t nodes.dmp -n names.dmp \
          -i sample-1.out -o names.out
        grep -F 'Escherichia coli' names.out >/dev/null

        kaiju2krona -t nodes.dmp -n names.dmp \
          -i sample-1.out -o krona.tsv
        test -s krona.tsv
        grep -F 'Escherichia coli' krona.tsv >/dev/null

        kaiju2table -t nodes.dmp -n names.dmp -r species \
          -o table.tsv sample-1.out
        test -s table.tsv
        grep -F 'Escherichia coli' table.tsv >/dev/null

        kaiju-mergeOutputs -i sample-1.out -j sample-2.out \
          -c 1 -o merged.out
        grep -F "$(printf 'C\tread_a\t562')" merged.out >/dev/null
        ;;
    index)
        prepare_fixture
        build_tiny_index

        mkdir -p makedb/viruses
        cp nodes.dmp names.dmp merged.dmp makedb/
        cp proteins.faa makedb/viruses/kaiju_db_viruses.faa
        (
          cd makedb
          tar -czf taxdump.tar.gz nodes.dmp names.dmp merged.dmp
          kaiju-makedb -s viruses -t 2 --index-only > run.log 2>&1
          test -s viruses/kaiju_db_viruses.fmi
          grep -F 'Done!' run.log >/dev/null
        )
        ;;
    gbk)
        cat > tiny.gbk <<'EOF'
LOCUS       TINY                     180 bp    DNA
FEATURES             Location/Qualifiers
     CDS             1..180
                     /db_xref="taxon:562"
                     /protein_id="TEST_1"
                     /translation="ACDEFGHIKLMNPQRSTVWYACDEFGHIKLMNPQRSTVWY"
ORIGIN
//
EOF
        gzip -c tiny.gbk > tiny.gbk.gz
        kaiju-gbk2faa.pl tiny.gbk.gz converted.faa
        test -s converted.faa
        grep -Fx '>TEST_1_562' converted.faa >/dev/null
        grep -Fx 'ACDEFGHIKLMNPQRSTVWYACDEFGHIKLMNPQRSTVWY' converted.faa >/dev/null
        ;;
    fixture)
        prepare_fixture
        build_tiny_index
        # Explicit test-only export into an existing caller-owned directory.
        test -n "${3:-}"
        test -d "$3"
        cp tiny.fmi nodes.dmp names.dmp protein-query.faa dna-query.fna proteins.faa "$3/"
        ;;
    *)
        echo "usage: kaiju-smoke.sh {interfaces|buildtime|classify|postprocess|index|gbk|all} [tmpdir]" >&2
        exit 2
        ;;
esac
echo "kaiju-smoke: stage=${mode} PASS"
