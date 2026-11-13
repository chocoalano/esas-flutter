#!/usr/bin/env python3
"""secret-guard: refuse credentials and signing material before they reach Git.

Check-only. It never writes a file, never touches the index or the working
tree, and never prints a matched value - only the path, the rule and the line.

Usage:
  secret-guard.py                 the files staged for commit (git diff --cached)
  secret-guard.py --all-tracked   every file Git tracks (git ls-files)
  secret-guard.py [--] PATH...    these files on disk (a directory is walked)

Exit status: 0 nothing blocked, 1 something blocked, 2 usage or git error.

Staged and tracked files are read from the index - what a commit would
contain - not from the working tree.

A content finding on a line that also carries the marker `secret-guard: allow`
is skipped and counted - for reviewed dummy test fixtures only. A file-name
finding (a keystore, an .env, an APK) cannot be allowed.

Opt-in pre-commit hook (activation is the repository owner's choice):
  git config core.hooksPath .githooks

Firebase *client* configuration - google-services.json,
GoogleService-Info.plist, firebase_options.dart and the AIza... browser keys in
them - is public by design, ships inside every app build, and is NOT flagged.
A Firebase *service account* key (private_key) is.

The same file lives in esas-selfservices (tool/) and tenancy-app (scripts/);
keep the two copies identical. Python 3.8+, standard library only.
"""

import fnmatch
import os
import re
import subprocess
import sys

# --- Rules on the file name -------------------------------------------------

FORBIDDEN_EXTENSIONS = (
    '.jks', '.keystore', '.p12', '.pfx', '.p8',
    '.mobileprovision', '.ipa', '.apk', '.aab',
)


def name_findings(path):
    base = os.path.basename(path).lower()
    found = []

    for ext in FORBIDDEN_EXTENSIONS:
        if base.endswith(ext):
            found.append(('forbidden-file', 'keystore, signing key, provisioning profile or app binary (%s) is never committed' % ext))
            break

    if base == 'key.properties':
        found.append(('signing-properties', 'key.properties names a keystore and carries its passwords'))

    if (base == '.env' or base.startswith('.env.')) and not base.endswith('.example'):
        found.append(('env-file', 'environment file holds live configuration and secrets; only .env.example is committed'))

    if fnmatch.fnmatch(base, 'firebase-adminsdk*.json'):
        found.append(('service-account-file', 'Firebase Admin SDK service account key file'))

    # Database dumps carry real tenant rows (SEC-DATA-01). Laravel's
    # `schema:dump` output under database/schema/ is structure only and stays
    # committable.
    normalized = '/' + path.replace('\\', '/').lstrip('/')
    if base.endswith(('.sql', '.sql.gz', '.dump')) and '/database/schema/' not in normalized:
        found.append(('database-dump', 'database dump file; tenant data is never committed (schema dumps belong in database/schema/)'))

    return found


# --- Rules on the content ---------------------------------------------------
# Every pattern starts with a literal prefix followed by a character class, so
# this file never matches its own source.

CONTENT_RULES = (
    ('private-key', re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), 'PEM private key'),
    ('google-oauth-client-secret', re.compile(r'GOCSPX-[0-9A-Za-z_-]{10,}'), 'Google OAuth client secret'),
    ('github-token', re.compile(r'\b(?:ghp_[0-9A-Za-z]{30,}|github_pat_[0-9A-Za-z_]{30,})'), 'GitHub token'),
    ('aws-access-key-id', re.compile(r'\bAKIA[0-9A-Z]{16}\b'), 'AWS access key id'),
    ('slack-token', re.compile(r'\bxox[abprs]-[0-9A-Za-z-]{10,}'), 'Slack token'),
    ('stripe-live-secret', re.compile(r'\bsk_live_[0-9A-Za-z]{10,}'), 'Stripe live secret key'),
    ('midtrans-server-key', re.compile(r'Mid-server-[0-9A-Za-z_-]{10,}'), 'Midtrans server key'),
    ('fcm-legacy-server-key', re.compile(r'\bAAAA[0-9A-Za-z_-]{7}:APA91b[0-9A-Za-z_-]{30,}'), 'FCM legacy server key'),
)

SERVICE_ACCOUNT_TYPE = re.compile(r'"type"\s*:\s*"service_account"')
SERVICE_ACCOUNT_KEY = re.compile(r'"private_key"\s*:\s*"[^"\s]')

APP_KEY = re.compile(r'\bAPP_KEY[ \t]*=[ \t]*["\']?base64:[A-Za-z0-9+/=]{40,}')

# key.properties-style files: `storePassword=hunter2`. Empty values and
# `<placeholder>` / `${VARIABLE}` values are templates, not secrets.
PROPERTIES_PASSWORD = re.compile(
    r'^[ \t]*[\w.-]*pass(?:word|wd)[\w.-]*[ \t]*[=:][ \t]*(?!<[^>\n]*>[ \t]*$)(?!\$\{[^}\n]*\}[ \t]*$)[^\s#!]',
    re.IGNORECASE | re.MULTILINE,
)

# Gradle (Groovy or Kotlin DSL): `storePassword = "hunter2"`, `storePassword 'x'`,
# `storePassword("x")`. A value read from a variable, a property or a `$` template
# is not a literal and passes.
GRADLE_PASSWORD = re.compile(
    r'\b\w*pass(?:word|wd)\w*(?:[ \t]*=[ \t]*|[ \t]*\([ \t]*|[ \t]+)["\'][^"\'$\n]+["\']',
    re.IGNORECASE,
)


def is_example(base):
    return base.endswith('.example')


ALLOW_MARKER = 'secret-guard: allow'


def line_of(text, offset):
    return text.count('\n', 0, offset) + 1


def allowed(text, offset):
    start = text.rfind('\n', 0, offset) + 1
    end = text.find('\n', offset)
    return ALLOW_MARKER in text[start:end if end != -1 else len(text)]


def content_findings(path, data):
    # Binary files (keystores, images, fonts) are judged by name only - the
    # same heuristic Git uses for "binary": a NUL byte near the start.
    if b'\0' in data[:8000]:
        return [], 0

    text = data.decode('utf-8', errors='replace')
    base = os.path.basename(path).lower()
    found = []  # (rule, label, offset)

    for rule, pattern, label in CONTENT_RULES:
        for match in pattern.finditer(text):
            found.append((rule, label, match.start()))

    if SERVICE_ACCOUNT_TYPE.search(text):
        key = SERVICE_ACCOUNT_KEY.search(text)
        if key:
            found.append(('service-account-key', 'Google service account JSON with a private_key', key.start()))

    if not is_example(base):
        for match in APP_KEY.finditer(text):
            found.append(('app-key', 'Laravel APP_KEY value outside .env.example', match.start()))

    if base.endswith('.properties') or base.endswith('.properties.example'):
        for match in PROPERTIES_PASSWORD.finditer(text):
            found.append(('literal-password', 'password with a literal value in a properties file', match.start()))

    if base.endswith('.gradle') or base.endswith('.gradle.kts'):
        for match in GRADLE_PASSWORD.finditer(text):
            found.append(('literal-password', 'password with a literal value in a Gradle script', match.start()))

    kept = sorted(((rule, label, line_of(text, at)) for rule, label, at in found if not allowed(text, at)), key=lambda f: f[2])
    return kept, len(found) - len(kept)


# --- Sources ----------------------------------------------------------------

class GitError(Exception):
    pass


def git(args, cwd):
    result = subprocess.run(['git'] + args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise GitError('git %s failed: %s' % (' '.join(args), result.stderr.decode('utf-8', 'replace').strip()))
    return result.stdout


def repository_root():
    return git(['rev-parse', '--show-toplevel'], None).decode('utf-8', 'surrogateescape').strip()


def index_blobs(root, paths):
    """Yield (path, bytes or None) for each path, read from the index (stage 0)."""
    batch = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for path in paths:
            raw = path.encode('utf-8', 'surrogateescape')
            if b'\n' in raw:
                single = subprocess.run(['git', 'cat-file', 'blob', ':' + path], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                yield path, (single.stdout if single.returncode == 0 else None)
                continue

            batch.stdin.write(b':' + raw + b'\n')
            batch.stdin.flush()
            header = batch.stdout.readline().rstrip(b'\n')

            if header.endswith(b' missing') or header.endswith(b' ambiguous'):
                yield path, None
                continue

            _, kind, size = header.rsplit(b' ', 2)
            body = batch.stdout.read(int(size))
            batch.stdout.read(1)
            # A submodule (commit) is not content of this repository.
            yield path, (body if kind == b'blob' else None)
    finally:
        batch.stdin.close()
        batch.wait()


def git_paths(root, args):
    out = git(args, root)
    return [p.decode('utf-8', 'surrogateescape') for p in out.split(b'\0') if p]


def disk_files(paths):
    for path in paths:
        if os.path.isdir(path):
            for directory, subdirs, files in os.walk(path):
                subdirs[:] = [d for d in subdirs if d != '.git']
                for name in sorted(files):
                    yield os.path.join(directory, name)
        else:
            yield path


def read_disk(path):
    try:
        with open(path, 'rb') as handle:
            return handle.read()
    except OSError:
        return None


# --- Main -------------------------------------------------------------------

def check(entries):
    """entries: iterable of (path, bytes or None). Returns (checked, findings, allowed)."""
    findings = []
    checked = 0
    skipped = 0
    for path, data in entries:
        checked += 1
        for rule, label in name_findings(path):
            findings.append((path, None, rule, label))
        if data is not None:
            kept, allowed_here = content_findings(path, data)
            skipped += allowed_here
            for rule, label, line in kept:
                findings.append((path, line, rule, label))
    return checked, findings, skipped


def main(argv):
    args = list(argv)
    if args and args[0] in ('-h', '--help'):
        print(__doc__.strip())
        return 0

    try:
        if args == ['--all-tracked']:
            root = repository_root()
            mode = 'tracked'
            checked, findings, skipped = check(index_blobs(root, git_paths(root, ['ls-files', '-z'])))
        elif not args:
            root = repository_root()
            mode = 'staged'
            paths = git_paths(root, ['diff', '--cached', '--name-only', '-z', '--diff-filter=d'])
            checked, findings, skipped = check(index_blobs(root, paths))
        else:
            if args[0] == '--':
                args = args[1:]
            elif args[0].startswith('-'):
                sys.stderr.write('secret-guard: unknown option %s (see --help)\n' % args[0])
                return 2
            if not args:
                sys.stderr.write('secret-guard: no paths given (see --help)\n')
                return 2
            missing = [p for p in args if not os.path.exists(p)]
            if missing:
                for p in missing:
                    sys.stderr.write('secret-guard: no such file: %s\n' % p)
                return 2
            mode = 'on-disk'
            checked, findings, skipped = check((p, read_disk(p)) for p in disk_files(args))
    except (GitError, OSError) as error:
        sys.stderr.write('secret-guard: %s\n' % error)
        return 2

    note = ' %d line(s) skipped by `%s`.' % (skipped, ALLOW_MARKER) if skipped else ''

    if not findings:
        print('secret-guard: OK - %d %s file(s) checked, nothing blocked.%s' % (checked, mode, note))
        return 0

    for path, line, rule, label in findings:
        where = path if line is None else '%s:%d' % (path, line)
        print('secret-guard: BLOCKED %s [%s] %s' % (where, rule, label))

    files = len(set(f[0] for f in findings))
    print('secret-guard: %d finding(s) in %d file(s) out of %d %s file(s). Matched values are never printed.%s' % (len(findings), files, checked, mode, note))
    print('secret-guard: keep secrets in a password manager or a path outside the repository; unstage with `git restore --staged <path>`.')
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
