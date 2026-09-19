#!/usr/bin/python3
"""Offline synthetic resource and upstream URL-regression tests, never production data."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tarfile
import tempfile


def run(stage, argv, fail=False, marker=None):
    result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=240)
    if (result.returncode == 0) == fail or (marker is not None and marker not in result.stdout):
        print(f'kaiju-resource-smoke: stage={stage} exit={result.returncode}', file=sys.stderr)
        print(result.stdout[-16000:], file=sys.stderr)
        raise SystemExit(result.returncode if result.returncode > 0 else 1)
    return result.stdout


def upstream():
    script = Path('/opt/kaiju/bin/kaiju-makedb').read_text()
    programs = [shlex.split(line)[1] for line in script.splitlines()
                if line.strip().startswith('awk ') and '_genomic.gbff.gz' in line]
    assert len(programs) == 3
    rows = []
    for url in ['https://example.invalid/GCF_123', 'https://example.invalid/GCF_123/']:
        row = ['unused'] * 20
        row[4], row[10], row[11], row[19] = 'reference genome', 'latest', 'Complete Genome', url
        rows.append('\t'.join(row))
    Path('assembly.tsv').write_text('\n'.join(rows) + '\n')
    for i, program in enumerate(programs):
        result = run(f'upstream-awk-{i}', ['awk', program, 'assembly.tsv'])
        assert result.splitlines() == ['https://example.invalid/GCF_123/GCF_123_genomic.gbff.gz'] * 2
    # Source-contract assertion only: the multi-hundred-GB conversion is not run here.
    branch = script.split('if [ "$DB" = "refseq_nr" ]\nthen', 1)[1].split('#-----', 1)[0]
    assert 'viral.[1-9].genomic.gbff.gz' in branch
    assert 'viral.[1-9][0-9].genomic.gbff.gz' in branch
    converter = next(line for line in branch.splitlines() if ' | kaiju-convertRefSeq ' in line)
    assert ' -l ' not in converter
    assert 'kaiju-gbk2faa.pl' in branch and '>>$DB/kaiju_db_$DB.faa' in branch


def fixture(directory):
    directory.mkdir()
    run('fixture', ['/opt/kaiju/share/testdata/kaiju-smoke.sh', 'fixture',
                    '/tmp/taf-kaiju-resource-fixture', str(directory)])
    with tarfile.open(directory / 'synthetic.tgz', 'w:gz') as archive:
        for name in ('tiny.fmi', 'nodes.dmp', 'names.dmp'):
            archive.add(directory / name, arcname=name)
    (directory / 'LICENSE.txt').write_text('Wholly synthetic technical fixture; CC0-1.0. No scientific validation.\n')
    recipe = run('pin', ['kaiju-db', 'pin', '--archive', str(directory / 'synthetic.tgz'),
                        '--url', 'https://example.invalid/synthetic-1.tgz', '--id', 'synthetic',
                        '--resource-version', '1', '--license-file', str(directory / 'LICENSE.txt'),
                        '--rights-reviewed'])
    (directory / 'recipe.json').write_text(recipe)
    return json.loads(recipe)


def resources():
    source = Path.cwd() / 'source'
    recipe = fixture(source)
    root = Path.cwd() / 'resources'; root.mkdir(mode=0o755)
    install = ['kaiju-db', 'install', '--recipe', str(source / 'recipe.json'),
               '--db-root', str(root), '--source-dir', str(source), '--reserve-gb', '0', '--rights-reviewed']
    run('dry-run', install + ['--dry-run'], marker='synthetic--1')
    assert not list(root.iterdir())
    run('install', install, marker='installed:')
    member = root / 'synthetic--1'
    identity = (member / 'READY').read_bytes()
    run('idempotent', install, marker='already complete:')
    assert (member / 'READY').read_bytes() == identity
    verify = ['kaiju-db', 'verify', '--db-root', str(root), '--id', 'synthetic--1']
    record = json.loads(run('verify', verify))
    assert len(record['files']) == 5 and not list(root.glob('*.stage-*'))
    assert len(json.loads(run('list', ['kaiju-db', 'list', '--db-root', str(root)]))) == 1
    run('installed-classify', ['kaiju', '-a', 'mem', '-m', '11', '-p', '-X', '-z', '1',
        '-t', str(member / 'nodes.dmp'), '-f', str(member / 'tiny.fmi'),
        '-i', str(source / 'protein-query.faa'), '-o', 'shared.out'])
    assert 'C\tread_protein\t562' in Path('shared.out').read_text()
    # Explicit second selection; no automatic fallback to another member.
    recipe2 = copy.deepcopy(recipe); recipe2['id'] = 'second'
    (source / 'second.json').write_text(json.dumps(recipe2))
    second = install.copy(); second[second.index('--recipe') + 1] = str(source / 'second.json')
    run('second-member', second, marker='installed:')
    assert len(json.loads(run('partial-inventory', ['kaiju-db', 'list', '--db-root', str(root)]))) == 2
    bad = copy.deepcopy(recipe); bad['id'] = 'bad'; bad['files'][0]['sha256'] = '0' * 64
    (source / 'bad.json').write_text(json.dumps(bad))
    wrong = install.copy(); wrong[wrong.index('--recipe') + 1] = str(source / 'bad.json')
    run('checksum-rejected', wrong, fail=True, marker='checksum/size mismatch')
    assert not (root / 'bad--1').exists() and not (root / '.install.lock').exists()
    (root / '.install.lock').mkdir()
    run('lock-rejected', wrong, fail=True, marker='install lock exists')
    (root / '.install.lock').rmdir()
    for name, body in [('nodes.dmp', b'X'), ('extra', b'X')]:
        path = member / name
        original = path.read_bytes() if path.exists() else None
        path.write_bytes(body)
        run('inventory-rejected-' + name, verify, fail=True)
        run('no-overwrite-' + name, install, fail=True)
        if original is None: path.unlink()
        else: path.write_bytes(original)
    (member / 'tiny.fmi').chmod(0o666)
    run('permission-rejected', verify, fail=True, marker='permission drift')
    (member / 'tiny.fmi').chmod(0o644)
    run('restored', verify)
    # Validate selected tar members without ever extractall-ing untrusted paths.
    for kind in ('symlink', 'duplicate', 'traversal'):
        archive_path = source / (kind + '.tgz')
        with tarfile.open(archive_path, 'w:gz') as archive:
            for name in ('nodes.dmp', 'names.dmp', 'tiny.fmi'):
                item = tarfile.TarInfo(name)
                item.size = 1
                if name == 'tiny.fmi' and kind == 'symlink':
                    item.type = tarfile.SYMTYPE; item.linkname = '/etc/passwd'; item.size = 0
                if name == 'tiny.fmi' and kind == 'traversal': item.name = '../tiny.fmi'
                archive.addfile(item, io.BytesIO(b'X'))
                if name == 'tiny.fmi' and kind == 'duplicate': archive.addfile(item, io.BytesIO(b'X'))
        run('pin-reject-' + kind, ['kaiju-db', 'pin', '--archive', str(archive_path),
            '--url', 'https://example.invalid/bad.tgz', '--id', kind, '--resource-version', '1',
            '--license-file', str(source / 'LICENSE.txt'), '--rights-reviewed'], fail=True)


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'resources'
    try:
        with tempfile.TemporaryDirectory(prefix='taf-kaiju-resource-') as scratch:
            os.chdir(scratch)
            {'resources': resources, 'upstream': upstream}[mode]()
        print('kaiju-resource-smoke: stage=' + mode + ' PASS')
    except Exception as error:
        print(f'kaiju-resource-smoke: stage={mode} exit=1: {error}', file=sys.stderr)
        raise
