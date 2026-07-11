kaiju 1.10.2-r1

Purpose:
  Protein-level taxonomic classification of metagenomic and metatranscriptomic
  reads, plus Kaiju database construction and result-conversion utilities.

Version identity:
  This app packages official v1.10.2, although upstream version.hpp still makes
  help print "Kaiju 1.10.1"; tag, commit, checksum and the -X fix bind identity.

Usage:
  taf-kaiju kaiju -t nodes.dmp -f database.fmi -i reads.fastq.gz -o out.tsv
  taf-kaiju kaiju -t nodes.dmp -f database.fmi -i R1.fq.gz -j R2.fq.gz
  taf-kaiju kaiju-makedb --help

Packaged classifiers:
  kaiju              Taxonomic classification of nucleotide or protein reads.
  kaiju-multi        Process comma-separated lists of samples.
  kaijup             Search protein queries without taxonomy assignment.
  kaijux             Translate nucleotide queries and report database matches.

Packaged database and result tools:
  kaiju-makedb       Download/convert a supported source and build an index.
  kaiju-mkbwt        Build the protein Burrows-Wheeler transform.
  kaiju-mkfmi        Build the final .fmi index.
  kaiju2table        Create rank-level abundance/count tables.
  kaiju2krona        Create text input for Krona; it does not render HTML.
  kaiju-addTaxonNames, kaiju-mergeOutputs
  kaiju-convertNR, kaiju-convertRefSeq, kaiju-gbk2faa.pl

Database requirements:
  Production databases are not embedded. Classification requires a matching
  .fmi index and nodes.dmp; name/table helpers also require names.dmp.

  Pre-built route:
    1. Open https://bioinformatics-centre.github.io/kaiju/downloads.html
    2. Choose a database and dated snapshot.
    3. Download its .tgz archive into a persistent project directory.
    4. Extract the .fmi, nodes.dmp and names.dmp files together.
    5. Record database name, date, URL and checksums with the analysis.

  Upstream build route:
    mkdir -p kaiju-db-build
    cd kaiju-db-build
    taf-kaiju kaiju-makedb -s viruses -t 4

  kaiju-makedb uses the network and writes into the current directory. Valid
  sources include refseq, refseq_nr, refseq_ref, progenomes, nr, nr_euk,
  fungi, viruses, plasmids and rvdb. Large builds can need hundreds of GB.

Examples:
  Single-end classification:
    taf-kaiju kaiju -z 8 -t "$PWD/db/nodes.dmp" \
      -f "$PWD/db/kaiju_db_viruses.fmi" -i reads.fq.gz -o sample.tsv

  MEM mode with SEG filtering disabled:
    taf-kaiju kaiju -a mem -X -t "$PWD/db/nodes.dmp" \
      -f "$PWD/db/kaiju_db_viruses.fmi" -i reads.fq.gz -o sample.tsv

  Species summary:
    taf-kaiju kaiju2table -t "$PWD/db/nodes.dmp" \
      -n "$PWD/db/names.dmp" -r species -o species.tsv sample.tsv

  Custom protein index:
    taf-kaiju kaiju-mkbwt -n 8 -a ACDEFGHIKLMNPQRSTVWY \
      -o custom proteins.faa
    taf-kaiju kaiju-mkfmi custom

Inputs and outputs:
  kaiju accepts plain or gzip FASTA/FASTQ. Paired files must have matching read
  names and order. Default output is tab-separated status, read id and taxon id;
  -v adds match details. -z controls classifier threads; makedb uses -t.

Platform and boundaries:
  Native linux/amd64 and linux/arm64 images are built from source. No GPU, MPI
  or service is needed. RAM is dominated by the selected database index.
  Do not mix an .fmi file with taxonomy files from another snapshot.
  Kaiju accepts explicit paths, so this app does not force a database mount.
  Paths outside the backend-visible working directory must be mounted manually.
  kaiju2krona output still needs a separate Krona ktImportText command.

Detailed documentation:
  https://github.com/bioinformatics-centre/kaiju/blob/v1.10.2/README.md
  https://bioinformatics-centre.github.io/kaiju/downloads.html

Wrapper options:
  taf-kaiju --help       Show this TAFFISH help.
  taf-kaiju --version    Show TAFFISH wrapper version.
  taf-kaiju --compile    Compile the TAFFISH wrapper.
  taf-kaiju -- -h        Show help for the default upstream kaiju command.
