kaiju 1.10.3-r1

Purpose:
  Classify metagenomic reads against a selected protein FM-index and taxonomy.

Usage:
  taf-kaiju kaiju -t nodes.dmp -f database.fmi -i reads.fq.gz -o calls.tsv -z 8
  taf-kaiju kaiju -t nodes.dmp -f database.fmi -i R1.fq.gz -j R2.fq.gz -o calls.tsv
  taf-kaiju kaiju -p -t nodes.dmp -f database.fmi -i proteins.faa -o calls.tsv
  taf-kaiju -- -h

Common tasks:
  taf-kaiju kaiju2table -t nodes.dmp -n names.dmp -r species -o abundance.tsv calls.tsv
  taf-kaiju kaiju-addTaxonNames -t nodes.dmp -n names.dmp -i calls.tsv -o named.tsv
  taf-kaiju kaiju2krona -t nodes.dmp -n names.dmp -i calls.tsv -o krona.tsv
  taf-kaiju kaijup -f database.fmi -i proteins.faa -o matches.tsv
  taf-kaiju kaijux -f database.fmi -i reads.fq.gz -o matches.tsv
  taf-kaiju kaiju-mkbwt -n 2 -a ACDEFGHIKLMNPQRSTVWY -o custom proteins.faa
  taf-kaiju kaiju-mkfmi custom

Required inputs:
  FASTA/FASTQ reads (gzip accepted); -p changes queries to protein sequences.
  One compatible .fmi and its matching nodes.dmp; names.dmp for named reports.
  Custom reference FASTA IDs must end in _NCBI-taxid for classification.
  No production database is bundled; select its biological scope and date first.

Common options and outputs:
  -z threads; -a greedy|mem; -e mismatches in greedy mode; -E E-value cutoff.
  -m minimum match length; -s minimum greedy score; -X disables SEG filtering.
  calls.tsv starts with C/U (classified/unclassified), read ID and taxon ID.
  krona.tsv is text for a separate Krona renderer, not an HTML dashboard.
  Use new output paths; existing upstream outputs may be overwritten.

Database preparation:
  Obtain a reviewed fixed recipe from your administrator (README: first pin).
  mkdir -p "$HOME/.local/share/taffish/databases/kaiju"
  DBROOT="$HOME/.local/share/taffish/databases/kaiju"
  chmod 755 "$DBROOT"
  Docker install (recipe.json in current directory):
    TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="--user $(id -u):$(id -g) -v '$DBROOT:/db-install'" taf-kaiju kaiju-db install --recipe recipe.json --db-root /db-install --rights-reviewed
  Podman install:
    TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="--userns keep-id -v '$DBROOT:/db-install'" taf-kaiju kaiju-db install --recipe recipe.json --db-root /db-install --rights-reviewed
  Apptainer install (native Linux):
    TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind '$DBROOT:/db-install'" taf-kaiju kaiju-db install --recipe recipe.json --db-root /db-install --rights-reviewed
  Add --dry-run to preview. For local archives, add --source-dir ARCHIVE_DIR.
  Repeat to resume/verify; no --force. Reserve space for archive + unpacked files.

Read-only database reuse, including administrator-installed shared databases:
  DBROOT=/usr/local/share/taffish/databases/kaiju
  Set DBROOT to your actual root; replace ID--DATE and FILE.fmi below.
  Docker:
    export TAFFISH_CONTAINER_BACKEND=docker
    export TAFFISH_DOCKER_RUN_ARGS="-v '$DBROOT:/db:ro'"
  Podman:
    export TAFFISH_CONTAINER_BACKEND=podman
    export TAFFISH_PODMAN_RUN_ARGS="-v '$DBROOT:/db:ro'"
  Apptainer (native Linux):
    export TAFFISH_CONTAINER_BACKEND=apptainer
    export TAFFISH_APPTAINER_RUN_ARGS="--bind '$DBROOT:/db:ro'"
  Then, with any of these three backend selections:
    taf-kaiju kaiju-db list --db-root /db
    taf-kaiju kaiju-db verify --db-root /db --id ID--DATE
    taf-kaiju kaiju -t /db/ID--DATE/nodes.dmp -f /db/ID--DATE/FILE.fmi -i reads.fq.gz -o calls.tsv
  No automatic discovery or download: select explicit paths, or unset that
  backend's TAFFISH_*_RUN_ARGS to remove the optional mount and use local files.

Immediate notes:
  Native amd64/arm64 Linux; Apptainer requires Linux, not macOS itself.
  Large databases need substantial RAM; choose a database your machine can load.
  kaiju-makedb writes/downloads in its current directory: use a new writable
  directory. Its rolling downloads are not a fixed, checksum-pinned resource.
  In 1.10.3, refseq_nr contains bacterial/archaeal nonredundant proteins plus
  viral proteins; its upstream --help still misleadingly lists fungi/eukaryotes.
  For paths with spaces, preserve inner quotes: -i "'reads/query 1.faa'".
  Missing taxonomy/index: check paths and actual mounts; no fallback is selected.

More help:
  taf-kaiju kaiju -h
  Upstream -h prints help and exits 1 by design; this is not a runtime failure.
  taf-kaiju kaiju-db --help
  taf-kaiju kaiju-makedb --help
  https://github.com/taffish/kaiju

Wrapper options:
  taf-kaiju --help       Show this usage help.
  taf-kaiju --version    Wrapper version; upstream version is in kaiju -h.
  taf-kaiju --compile    Print the generated wrapper shell.
