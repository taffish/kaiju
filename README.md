# kaiju

`kaiju` packages the complete Kaiju command-line suite for TAFFISH. Kaiju
classifies metagenomic or metatranscriptomic reads by translating nucleotide
sequences and searching a protein FM-index against the NCBI taxonomy.

## Package Identity

- Name: `kaiju`
- Command: `taf-kaiju`
- Kind: `tool`
- TAFFISH version: `1.10.2-r1`
- Container image: `ghcr.io/taffish/kaiju:1.10.2-r1`
- Upstream: [`bioinformatics-centre/kaiju`](https://github.com/bioinformatics-centre/kaiju)
- Upstream release: `v1.10.2`
- Upstream commit: `9b70819cf119b0874ab9b0100ed36b1fff41b7ea`
- TAFFISH app license: `Apache-2.0`
- Upstream license: `GPL-3.0-or-later`

## What This App Packages

The image builds the official `v1.10.2` source release with its upstream
C/C++11 Makefiles. It includes the classifier, database-index builders,
taxonomy-aware result converters, the database download/build script, its
Perl GenBank converter, and the data files required by `kaiju-makedb`.

No production reference database is embedded in the image. Kaiju database
snapshots are large, change independently of the software, and determine much
of the scientific result. Keep them as explicit project or site data.

## Runtime Version Note

The official `v1.10.2` tag still defines `KAIJUVERSION` as `1.10.1` in
`src/version.hpp`, so upstream help banners honestly print `Kaiju 1.10.1`.
This app does not patch that string. Release identity is instead fixed by the
official `v1.10.2` tag, commit, source SHA256, and the release-specific `-X`
implementation in both `kaijup` and `kaijux`.

The source archive SHA256 is:

```text
8d6d10c583799b040b77f28907c6b554363199e912681b3007b93ae7d817d172
```

## Scope

This app supports:

- single-end and paired-end nucleotide classification with `kaiju`
- multi-sample classification with `kaiju-multi`
- MEM and Greedy search modes, including the `-X` SEG-disable option
- protein-query search with `kaijup`
- translated nucleotide-query search without taxonomy assignment with `kaijux`
- plain or gzip-compressed FASTA and FASTQ input
- custom protein index construction with `kaiju-mkbwt` and `kaiju-mkfmi`
- official database acquisition and construction with `kaiju-makedb`
- Kaiju-to-Krona, summary-table, taxon-name, and merged-output helpers
- NCBI NR/RefSeq conversion helpers and GenBank protein extraction

This app does not choose a scientifically appropriate database, bundle a
production database, download data during ordinary classification, or include
Krona's HTML renderer. `kaiju2krona` creates Krona input; render that output
with a separate Krona installation or `taf-krona` app.

## Container Contents

Classifiers:

- `kaiju`
- `kaiju-multi`
- `kaijup`
- `kaijux`

Index and database tools:

- `kaiju-mkbwt`
- `kaiju-mkfmi`
- `kaiju-makedb`
- `kaiju-convertNR`
- `kaiju-convertRefSeq`
- `kaiju-gbk2faa.pl`

Result tools:

- `kaiju2table`
- `kaiju2krona`
- `kaiju-addTaxonNames`
- `kaiju-mergeOutputs`

The runtime also includes the download, compression, Perl, and POSIX shell
utilities that the upstream `kaiju-makedb` script actually invokes.

## Database Boundary

Classification needs:

- a protein FM-index such as `kaiju_db_nr.fmi`
- the matching NCBI taxonomy `nodes.dmp`
- `names.dmp` for name- and summary-producing helper commands

### Download An Official Pre-Built Index

1. Open the official [Kaiju index download page](https://bioinformatics-centre.github.io/kaiju/downloads.html).
2. Choose the database and dated snapshot appropriate for the analysis.
3. Download and unpack the archive in a persistent project directory.
4. Record the database name, snapshot date, URL and checksums with the result.

For example, the small dated virus snapshot currently listed upstream can be
prepared with:

```sh
mkdir -p kaiju-db
curl -fL \
  https://kaiju-idx.s3.eu-central-1.amazonaws.com/2024/kaiju_db_viruses_2024-08-15.tgz \
  -o kaiju-db/kaiju_db_viruses_2024-08-15.tgz
tar -xzf kaiju-db/kaiju_db_viruses_2024-08-15.tgz -C kaiju-db
find kaiju-db -maxdepth 1 -type f -print
```

The extracted directory should contain an `.fmi` file plus matching
`nodes.dmp` and `names.dmp` files.

### Build From Current Upstream Sources

Run `kaiju-makedb` from the persistent directory where downloads and generated
indexes should remain:

```sh
mkdir -p kaiju-db-build
cd kaiju-db-build
taf-kaiju kaiju-makedb -s viruses -t 4
```

Valid source names in `v1.10.2` include `refseq`, `refseq_nr`, `refseq_ref`,
`progenomes`, `nr`, `nr_euk`, `fungi`, `viruses`, `plasmids`, and `rvdb`.
This command intentionally uses the network. Larger choices may require
hundreds of gigabytes of disk and hundreds of gigabytes of RAM while building.

### Build A Custom Protein Index

Protein FASTA headers must end in a numeric NCBI taxon id, and sequences may
contain only the standard 20 uppercase amino-acid letters:

```sh
taf-kaiju kaiju-mkbwt \
  -n 8 -a ACDEFGHIKLMNPQRSTVWY -o custom proteins.faa
taf-kaiju kaiju-mkfmi custom
```

This creates `custom.fmi`; supply compatible NCBI taxonomy files separately.

Kaiju accepts database paths directly, so this app does not impose a fixed
container database path or automatic mount policy. Keep reads and the database
under the mounted project working directory, or explicitly mount a controlled
shared database directory through the selected container backend.

## Usage

Show wrapper and upstream help:

```sh
taf-kaiju --help
taf-kaiju --version
taf-kaiju -- -h
taf-kaiju kaiju -h
```

Classify single-end reads:

```sh
taf-kaiju kaiju \
  -t "$PWD/kaiju-db/nodes.dmp" \
  -f "$PWD/kaiju-db/kaiju_db_viruses.fmi" \
  -i reads.fastq.gz \
  -o sample.kaiju.tsv \
  -z 8
```

Classify paired-end reads:

```sh
taf-kaiju kaiju \
  -t "$PWD/kaiju-db/nodes.dmp" \
  -f "$PWD/kaiju-db/kaiju_db_viruses.fmi" \
  -i reads_R1.fastq.gz \
  -j reads_R2.fastq.gz \
  -o sample.kaiju.tsv \
  -z 8
```

Use MEM mode or disable the default SEG low-complexity filter:

```sh
taf-kaiju kaiju -a mem -X \
  -t "$PWD/kaiju-db/nodes.dmp" \
  -f "$PWD/kaiju-db/kaiju_db_viruses.fmi" \
  -i reads.fastq.gz -o sample.mem.tsv
```

Create a species table and add taxon names:

```sh
taf-kaiju kaiju2table \
  -t "$PWD/kaiju-db/nodes.dmp" \
  -n "$PWD/kaiju-db/names.dmp" \
  -r species -o sample.species.tsv sample.kaiju.tsv

taf-kaiju kaiju-addTaxonNames \
  -t "$PWD/kaiju-db/nodes.dmp" \
  -n "$PWD/kaiju-db/names.dmp" \
  -i sample.kaiju.tsv -o sample.names.tsv
```

Create Krona input:

```sh
taf-kaiju kaiju2krona \
  -t "$PWD/kaiju-db/nodes.dmp" \
  -n "$PWD/kaiju-db/names.dmp" \
  -i sample.kaiju.tsv -o sample.krona.tsv
```

## Command Mode

The default command is `kaiju`, so option-leading classification arguments can
also be passed directly:

```sh
taf-kaiju -t nodes.dmp -f database.fmi -i reads.fastq.gz
taf-kaiju -- -h
```

Use automatic command mode for every other packaged executable:

```sh
taf-kaiju kaiju-multi -h
taf-kaiju kaijup -h
taf-kaiju kaijux -h
taf-kaiju kaiju-makedb --help
taf-kaiju kaiju2table -h
```

## Inputs And Outputs

`kaiju` and `kaiju-multi` accept FASTA or FASTQ nucleotide reads, including
gzip-compressed files. Paired files must contain reads in the same order and
with matching names. The `-p` option treats input as protein sequences.

Default output is tab-separated, one record per read or read pair. The first
three columns are classification status (`C` or `U`), read name, and NCBI taxon
id. `-v` appends score/match details. Summary and name helpers require taxonomy
files from the same database snapshot.

## Resources, Databases, And Platform

Native images are built for `linux/amd64` and `linux/arm64`. Classification is
CPU-only and supports threads through `-z`; database construction uses `-t`.
No GPU, MPI runtime or service is required.

The build makes upstream's required signed-`char` BWT semantics explicit with
`-fsigned-char`. This keeps the original algorithm while avoiding AArch64's
different compiler default; native tiny index construction and classification
are tested on both architectures.

RAM is dominated by the selected `.fmi` index. The official download page
currently lists examples from about 0.5 GB RAM for the virus index to more than
200 GB for large NR indexes. Database construction can need substantially more
RAM and temporary disk than classification.

## Boundaries And Troubleshooting

- `kaiju-makedb` downloads from NCBI and other upstream providers; ordinary
  classification is offline once the database is present.
- Database contents and taxonomy snapshots are scientific inputs. Do not mix
  an `.fmi` file with unrelated `nodes.dmp` or `names.dmp` snapshots.
- `kaiju-convertNR` and `kaiju-convertRefSeq` are production-scale converters
  that reserve memory for very large accession maps; their help and linkage are
  tested, but smoke does not allocate their production-scale maps.
- `kaiju2krona` does not generate HTML by itself. Use Krona's `ktImportText`
  separately.
- If a path is outside the working directory visible to Docker, Podman or
  Apptainer, mount that host directory explicitly before passing the path.

## Testing

The offline smoke suite independently checks:

- all packaged command interfaces, companion data and dynamic libraries
- exact source provenance and the upstream `1.10.1` runtime-banner mismatch
- direct tiny index construction and offline `kaiju-makedb --index-only`
- nucleotide, protein, gzip and multi-sample classification
- the release-specific `-X` path in `kaiju`, `kaijup` and `kaijux`
- table, Krona-input, taxon-name and output-merge helpers
- compressed GenBank conversion through Perl `IO::Uncompress`

The tiny synthetic smoke index is only a packaging fixture. Smoke does not
download a production database or establish scientific accuracy on real data.

## License And Citation

TAFFISH packaging files are licensed under Apache-2.0. Upstream Kaiju is
GPL-3.0-or-later. The image retains the upstream GPL text, the bundled `zstr`
MIT license, and the NCBI BLAST core public-domain notice.

Cite:

> Menzel P, Ng KL, Krogh A. Fast and sensitive taxonomic classification for
> metagenomics with Kaiju. Nature Communications. 2016;7:11257.
> https://doi.org/10.1038/ncomms11257

Also record and cite the database source and snapshot used for classification.

## Upstream Resources

- [Project homepage](https://bioinformatics-centre.github.io/kaiju/)
- [Official release](https://github.com/bioinformatics-centre/kaiju/releases/tag/v1.10.2)
- [Upstream README](https://github.com/bioinformatics-centre/kaiju/blob/v1.10.2/README.md)
- [Quickstart](https://github.com/bioinformatics-centre/kaiju/blob/v1.10.2/Quickstart.md)
- [Pre-built indexes](https://bioinformatics-centre.github.io/kaiju/downloads.html)
