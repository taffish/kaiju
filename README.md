# taf-kaiju

`taf-kaiju` packages [Kaiju](https://github.com/bioinformatics-centre/kaiju),
a CPU protein-level metagenomic classifier, for TAFFISH.

Package identity: tool `kaiju`, command `taf-kaiju`, version `1.10.3-r1`,
image `ghcr.io/taffish/kaiju:1.10.3-r1`, native `linux/amd64,linux/arm64`.
Packaging is Apache-2.0; upstream software is GPL-3.0-or-later.

## What This App Packages

The complete upstream command suite built from unchanged v1.10.3 source,
with explicit `-fsigned-char` on both architectures for BWT compatibility.
The thin command-mode entry passes arguments directly to Kaiju. The separate
`kaiju-db` helper installs fixed prebuilt members; it does not intercept
classification, choose a biological database or download implicitly.

The [1.10.3 release](https://github.com/bioinformatics-centre/kaiju/releases/tag/v1.10.3)
fixes RefSeq assembly URLs with trailing slashes and adds viral proteins to
`refseq_nr`. Runtime now reports `Kaiju 1.10.3`; the earlier 1.10.2 tag still
reported 1.10.1. Here `refseq_nr` means bacterial/archaeal nonredundant proteins
plus viral proteins, not fungi/microbial eukaryotes. Upstream README/code agree,
but the unchanged `kaiju-makedb --help` description still lists the latter.
Record the actual database contents/date, not just that historical label.

## Scope and Container Contents

- Classification: `kaiju`, `kaiju-multi`; non-taxonomic queries: `kaijup`, `kaijux`.
- Reports: `kaiju2table`, `kaiju2krona`, `kaiju-addTaxonNames`, `kaiju-mergeOutputs`.
- Indexing/conversion: `kaiju-mkbwt`, `kaiju-mkfmi`, `kaiju-makedb`,
  `kaiju-convertNR`, `kaiju-convertRefSeq`, `kaiju-gbk2faa.pl`, upstream taxon/exclusion lists.
- Resources: `kaiju-db`, Python3, HTTPS curl and CA certificates.
- Perl IO::Uncompress, wget, xargs/find, awk, coreutils, tar, gzip, bzip2, xz,
  C++ runtime/zlib; upstream README/Quickstart and legal notices.

No production database, trained model, GPU runtime, GUI or service is bundled.
Official source, README, Quickstart and companion links were inspected:
the [original hosted Kaiju server shut down in 2024](https://bioinformatics-centre.github.io/kaiju/).
Galaxy is an independent hosted platform, not a Kaiju GUI extra.
`kaiju2krona` emits text for the independent Krona renderer (`taf-krona`),
not an in-process GUI. No GUI ports, browser lifecycle or device flags apply.

## Installation and Command Mode

After publication:

```sh
taf update
taf install kaiju 1.10.3-r1
taf-kaiju --help
taf-kaiju --version
taf-kaiju kaiju -h
```

Before publication, maintainers may use `taf install --from .` in the checkout.
Wrapper `--help`, `--version`, `--compile` belong to TAFFISH. Use
`taf-kaiju -- -h` for upstream help; Kaiju has no dedicated `--version`.
A non-option first argument selects a container executable. Upstream Kaiju -h
prints usage and intentionally exits 1; help markers and this exact status are
tested without changing upstream behavior.

## Usage, Inputs and Outputs

```sh
taf-kaiju kaiju -t nodes.dmp -f database.fmi -i reads.fq.gz -o calls.tsv -z 8
taf-kaiju kaiju -t nodes.dmp -f database.fmi -i R1.fq.gz -j R2.fq.gz -o paired.tsv
taf-kaiju kaiju -p -t nodes.dmp -f database.fmi -i proteins.faa -o proteins.tsv
taf-kaiju kaiju2table -t nodes.dmp -n names.dmp -r species -o abundance.tsv calls.tsv
taf-kaiju kaiju-addTaxonNames -t nodes.dmp -n names.dmp -i calls.tsv -o named.tsv
taf-kaiju kaiju2krona -t nodes.dmp -n names.dmp -i calls.tsv -o krona.tsv
taf-kaiju kaijup -f database.fmi -i proteins.faa -o matches.tsv
taf-kaiju kaijux -f database.fmi -i reads.fq.gz -o translated.tsv
taf-kaiju kaiju-mkbwt -n 2 -a ACDEFGHIKLMNPQRSTVWY -o custom proteins.faa
taf-kaiju kaiju-mkfmi custom
```

Queries are FASTA/FASTQ (gzip accepted); `-p` means protein input. Paired files
must correspond. Classification requires a compatible FMI and matching
`nodes.dmp`; named reports require matching `names.dmp`. Custom protein reference
IDs end in `_NCBI-taxid`; KaijuP/KaijuX non-taxonomic searches use sequence IDs.
The FMI is reusable; BWT/SA build intermediates are not needed for classification.

`calls.tsv` starts with C/U, read ID and taxon ID; verbose mode adds match details.
`kaiju2table` writes abundance tables; Krona output is text, not HTML.
`-z` controls threads; `-a mem|greedy`, `-e`, `-E`, `-m`, `-s` set search criteria;
`-X` disables SEG. Reference/filter choices change scientific interpretation.
Use new output paths: existing files may be overwritten. With spaces, preserve
literal inner quotes for TAFFISH command reconstruction:
`-i "'reads/query 1.faa'" -o "'results/calls 1.tsv'"`.

## Fixed Resources and Personal/System-Wide Sharing

The smallest reusable unit is **one selected dated FMI plus matching taxonomy**,
not the whole evolving database family. Official members and disk/RAM estimates:
[Kaiju downloads](https://bioinformatics-centre.github.io/kaiju/downloads.html).
Custom project sequences remain user inputs; small bundled exclusion/taxon lists
stay versioned inside the image. There are no trained models.

The catalog does not supply an authenticated SHA256 manifest. Do not invent one
or treat a multipart S3 ETag as SHA256. An administrator reviews one fixed official
HTTPS acquisition and pins it locally, or receives an already reviewed recipe.
First pin is trust-on-first-use under HTTPS/source review, **not an upstream
signature**. Later installs require the recorded size/SHA256 and reject changed
bytes even at the same URL.

Select the dated URL from the official page and save the applicable data
attribution/permission notice in `RESOURCE_LICENSE.txt`. After setting `URL` to
that selected HTTPS URL (not a mutable latest alias):

```sh
mkdir acquisition
cd acquisition
curl --fail --location --proto '=https' --proto-redir '=https' --continue-at - --output selected.tgz "$URL"
# Supply reviewed RESOURCE_LICENSE.txt before pinning.
taf-kaiju kaiju-db pin --archive selected.tgz --url "$URL" --id chosen-family --resource-version YYYY-MM-DD --license-file RESOURCE_LICENSE.txt --rights-reviewed > recipe.json
```

Pin requires top-level regular `nodes.dmp`, `names.dmp` and exactly one FMI.
Selected symlinks, duplicate names, traversal and sparse members are rejected.
It reads/hashes the archive without executing it. Check any separately published
provider checksum before first pin when available. Custom bundles may contain
the same three files from a recorded custom build. Pin proves byte identity,
not biological correctness or semantic validity of an arbitrary FMI.

Schema `taffish.kaiju.recipe.v1` records `id`, `version`, `source`, `license`,
and `files` entries with `name`, HTTPS `url`, exact `size`, `sha256`, and
selected `extract` names. Archive names are local input names, not inferred from
URLs. Transfer the recipe with its review. Use a new version for changed resources.

Create an installer-owned root, not group/world writable:

```sh
DBROOT="$HOME/.local/share/taffish/databases/kaiju"
mkdir -p "$DBROOT"
chmod 755 "$DBROOT"
```

For site reuse, the administrator instead creates
`/usr/local/share/taffish/databases/kaiju` (or a site-selected root), with
traversable parents and owner-only writes. The helper never invokes sudo or
creates/modifies system paths automatically. Personal Docker installs use the
real user's UID/GID; administrator/root identity is only for an authorized site
install. Podman keep-id preserves the caller; Apptainer uses the caller UID.
Ordinary users cannot install into a root-owned site root.

Installed help supplies all three backend commands with an actual writable bind
to `/db-install`. Add `--source-dir .` in the acquisition directory to import
the pinned archive without another download. Add `--dry-run` to inspect identity,
destination and download bytes. Without `--source-dir`, the helper performs a
resumable HTTPS download. Only the explicit member is installed, never all.

Install contract: private0700 download cache; exact size/SHA256; exclusive root
lock; unique staging; no-clobber same-filesystem atomic promotion; member0755/
files0644; full `manifest.json` inventory and hashed `READY`. Verified archives
are deleted from the private cache after promotion. Reinstall verifies an
identical member and rejects corruption/different recipes instead of replacing.
`verify --id ID--DATE` fully rehashes one member; `list` verifies visible partial
inventory without selecting a member. These work read-only but may take time.
Disk must fit compressed plus unpacked files and `--reserve-gb` (default10GiB);
space is checked before download and each extraction. RAM is a separate concern.

Repeat the same install after interruption to resume its private partial file.
Checksum failures retain the exact partial for inspection. There is no force.
Never remove an active lock. After abnormal termination, an administrator must
confirm no installer is running and quarantine only the stale lock/stage or
damaged member. Ordinary users must not chmod/chown shared resources.

## Backend Usage and Capability Matrix

| Capability | Docker | Podman | Apptainer |
| --- | --- | --- | --- |
| Native architecture | amd64, arm64 | matching Linux architecture | matching native Linux, read-only SIF |
| Select backend | `TAFFISH_CONTAINER_BACKEND=docker` | `...=podman` | `...=apptainer` |
| Optional writable install | `-v ROOT:/db-install`, installer UID | `-v ROOT:/db-install`, keep-id | `--bind ROOT:/db-install`, caller UID |
| Read-only reuse | `-v ROOT:/db:ro` | `-v ROOT:/db:ro` | `--bind ROOT:/db:ro` |

Put the optional mount in `TAFFISH_DOCKER_RUN_ARGS`, `TAFFISH_PODMAN_RUN_ARGS`
or `TAFFISH_APPTAINER_RUN_ARGS`; help gives complete commands. These are per-run/
site policy, not hidden app requirements. No GPU/port/platform emulation switches
are intrinsic. Apptainer requires Linux, not macOS itself. ARM64 Apptainer is
not separately validated in this release; use a matching Linux runner.

There is deliberately **no automatic discovery or selection**: databases have
different biological scopes and Kaiju already accepts explicit `-f/-t/-n` paths.
These paths are the resource-specific override. Disable shared-root exposure by
unsetting the selected backend run-args variable, and use files under the working
directory as a backend-neutral fallback. Missing resources never trigger a
download or another member. Users only read site resources; results/scratch go
to their working directory and /tmp, never the image or shared database.

## Boundaries and Troubleshooting

`kaiju-makedb` remains the original rolling-source builder. Run it explicitly in
a fresh writable directory, never inside an installed member. URLs/content,
intermediate size and converter RAM may change; some upstream paths use HTTP.
It is not the fixed HTTPS recipe installer. Preserve source/build provenance
before sharing. This release does not download/certify full NR/RefSeq databases:
the trailing-slash fix is executed on synthetic assembly rows; the added viral
branch is source-contract audited. Do not mix unrelated taxonomy and indexes.

- Missing files: check real binds and exact paths. Marker env vars do not create
  mounts or make a read-only SIF writable.
- Permission failure: installer must own its root; readers need read/search
  permission through site parents. Keep actual read-only binds for analysis.
- Corruption: verify/reinstall fail closed; have the administrator inspect the
  exact member/cache before creating a replacement version.
- Memory exhaustion: provision enough RAM or choose a scientifically suitable
  smaller resource; tiny success does not imply all database sizes fit.

## Provenance, Size and Testing

Source tag `v1.10.3`, commit `a36cd21d1c04d17a4f7e3744c17e8e8508e69e3b`,
SHA256 `712dc0b73944349ddf0e49b61e780864244e901ca89cd5c80180a97130a724d5`.
These are recorded in `/opt/kaiju/share/doc/kaiju/source.txt`.
The pinned Debian12-slim multi-stage build excludes compilers/build trees/source
archives; apt caches are removed in-layer. Build-time checks use stable help,
ldd and real tiny indexing/search, not rendered man pages or browser assertions.

Native Linux amd64 (xjp) and arm64 (local Docker/Podman Linux VMs) builds pass.
Every one of the 39 command-existence probes and nine exact manifest tests passes
in independent offline containers: Docker/Podman normal and read-only roots on
both architectures, plus actual read-only Apptainer SIF on native x86_64 Linux
(432 exact invocations). The SIF was generated from the same amd64 OCI contents.
Each of those five backend/platform runtime combinations passes 30 real-wrapper
checks, including actual binds, paths with spaces, installation, read-only reuse,
missing-resource failures and unchanged host inputs. ARM64 Apptainer is not
separately validated; this is not an untested backend or an emulation claim.

Administrator-once mechanics pass with a root-owned synthetic database in a
private xjp test directory: three ordinary-user backends and another numeric UID
can read, writes are rejected, and the temporary root is cleaned. This does not
claim a full production/site database installation. HTTPS interruption/Range
resumption and original exit-37 failure diagnostics pass on all three x86_64
backends and additionally ARM64 Docker. Initial harness errors (taf CLI supplied
instead of taffish core, and treating upstream help exit1 as failure) are retained
in evidence; corrected successor runs pass without runtime/threshold changes.

Uncompressed image size: amd64 177,234,360 bytes; arm64 203,867,853 bytes.
Kaiju is about3.3/3.4MiB, Python stdlib27/29MiB, legal docs2.9MiB; apt lists and
temporary build directory are4KiB each. CPython stdlib bytecode is retained as
read-only runtime content, not a pip/download/build cache. No compiler, sysroot
or development headers remain. Native build-time tiny tests remain lightweight.

No backend exception is required. Synthetic tests cover nucleotide/protein/
gzip/multi searches, reports, index-only/GBK, trailing-slash URLs and resource
failure paths. These are runtime evidence, not production scientific qualification.

## License and Citation

Packaging/helper code: Apache-2.0. Kaiju: GPL-3.0-or-later; zstr: MIT; NCBI BLAST
core retains its public-domain notice. Full notices are under
`/opt/kaiju/share/licenses/kaiju` and `/usr/share/doc`.
Resource terms are independent: [NCBI molecular-data policy](https://www.ncbi.nlm.nih.gov/home/about/policies/)
places no NCBI restrictions on data use/distribution while noting possible
submitter rights. Review other providers separately; software GPL does not grant
universal database rights. Record permissions/attribution in each recipe.

Cite Menzel, Ng and Krogh (2016), *Fast and sensitive taxonomic classification
for metagenomics with Kaiju*, Nature Communications7:11257,
[doi:10.1038/ncomms11257](https://doi.org/10.1038/ncomms11257), PMID27071849,
plus the actual reference database used.
