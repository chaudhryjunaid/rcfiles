#!/bin/bash

# manifest-diff.sh — compare the app manifests (gui-apps.manifest.csv,
# cli-apps.manifest.csv) with what's installed on this machine. Read-only.
# Lists
#   - manifest apps that aren't found here (install them, or drop the row)
#   - desktop apps installed here that no manifest row mentions (add a row)
# An app counts as installed when its distro packages are, or a snap,
# Flatpak, AppImage, desktop entry or command of that name exists. "Installed
# here" means: Flatpaks, snaps other than the ones Ubuntu ships with,
# AppImages, entries in ~/.local/share/applications, and distro packages with
# a desktop entry that were installed after the OS (Ubuntu: from apt's
# history; Fedora: dnf's user-installed list, which includes some defaults).
# Matching is by name, so the odd row may need a look by hand.
#
# Usage: ./manifest-diff.sh

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

case "${1:-}" in
    "") ;;
    -h | --help)
        sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
esac

DISTRO=$(detect_distro) || die "Only Ubuntu and Fedora are supported."
command -v python3 >/dev/null 2>&1 || die "python3 not found."

exec python3 -I - "$DISTRO" "$REPO/gui-apps.manifest.csv" "$REPO/cli-apps.manifest.csv" <<'EOF'
import configparser, csv, glob, gzip, os, re, shutil, subprocess, sys

distro, gui_csv, cli_csv = sys.argv[1:]
home = os.path.expanduser("~")


def run(*cmd):
    """stdout lines of cmd, or [] if it's missing or fails."""
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return out.splitlines()


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


# ---- what's installed ----------------------------------------------------
if distro == "ubuntu":
    packages = {l.split()[-1] for l in run("dpkg-query", "-W", "-f=${db:Status-Abbrev} ${Package}\n")
                if l.startswith("ii ")}
else:
    packages = set(run("rpm", "-qa", "--qf", "%{NAME}\n"))

snaps = {l.split()[0] for l in run("snap", "list")[1:] if l.strip()}
seeded = set()
try:
    with open("/var/lib/snapd/seed/seed.yaml") as f:
        seeded = set(re.findall(r"^\s*name:\s*(\S+)", f.read(), re.M))
except OSError:
    pass
flatpaks = {}  # app id -> display name
for line in run("flatpak", "list", "--app", "--columns=application,name"):
    app_id, _, name = line.partition("\t")
    flatpaks[app_id] = name or app_id

APP_DIRS = ["/usr/share/applications", "/usr/local/share/applications",
            f"{home}/.local/share/applications", "/var/lib/snapd/desktop/applications",
            "/var/lib/flatpak/exports/share/applications",
            f"{home}/.local/share/flatpak/exports/share/applications"]
desktop = []  # (path, display name) of entries shown in the app grid
for d in APP_DIRS:
    for path in glob.glob(f"{d}/*.desktop"):
        cp = configparser.RawConfigParser(strict=False, interpolation=None)
        try:
            cp.read(path, encoding="utf-8")
            entry = cp["Desktop Entry"]
        except Exception:
            continue
        if entry.get("NoDisplay", "").lower() == "true" or entry.get("Hidden", "").lower() == "true":
            continue
        desktop.append((path, entry.get("Name", os.path.basename(path)[:-8])))

# GNOME Shell extensions, by their display name.
extensions = set()
for meta in glob.glob(f"{home}/.local/share/gnome-shell/extensions/*/metadata.json") + \
        glob.glob("/usr/share/gnome-shell/extensions/*/metadata.json"):
    try:
        with open(meta, encoding="utf-8") as f:
            m = re.search(r'"name"\s*:\s*"([^"]+)"', f.read())
        if m:
            extensions.add(m.group(1))
    except OSError:
        pass

appimages = []
for d in (f"{home}/AppImages", f"{home}/Applications", f"{home}/.local/bin"):
    appimages += glob.glob(f"{d}/*.AppImage") + glob.glob(f"{d}/*.appimage")

# Names an app can be found under.
names = set()
names |= {norm(s) for s in snaps}
for app_id, name in flatpaks.items():
    names |= {norm(app_id.split(".")[-1]), norm(name)}
for path, name in desktop:
    names |= {norm(name), norm(os.path.basename(path)[:-8].split("_")[0])}
for path in appimages:
    names.add(norm(re.split(r"[-_.]", os.path.basename(path))[0]))
names |= {norm(e) for e in extensions}

# ---- manifest rows ---------------------------------------------------------
rows = []
for path, kind in ((gui_csv, "GUI"), (cli_csv, "CLI")):
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            row["kind"] = kind
            rows.append(row)


def found(row):
    pkgs = row.get(distro, "").split()
    if pkgs and all(p in packages for p in pkgs):
        return True
    # CLI rows from a vendor repo name their packages in the install column
    # ("apt, from Docker's repo: docker-ce docker-ce-cli ...").
    install = row.get("install", "")
    if ":" in install and not install.startswith("installer"):
        vendor = re.findall(r"[a-z0-9][a-z0-9.+-]+", install.rsplit(":", 1)[1])
        if vendor and all(p in packages for p in vendor):
            return True
    if norm(row["name"]) in names:
        return True
    # Commands: the name ("GitHub CLI" -> no) or the last word of the
    # description, which for CLI rows is the command ("..., claude").
    candidates = {row["name"].lower().replace(" ", "-"), row["name"].lower().replace(" ", "")}
    words = re.findall(r"[A-Za-z0-9_.-]+", row.get("description", ""))
    if words:
        candidates.add(words[-1])
    return any(shutil.which(c) for c in candidates)


missing = [r for r in rows if not found(r)]

# ---- installed desktop apps no row mentions -------------------------------
def installed_after_os():
    """Distro packages installed by hand after the OS install."""
    if distro == "fedora":
        return set(run("dnf", "repoquery", "--userinstalled", "--qf", "%{name}\n"))
    entries = []
    for path in glob.glob("/var/log/apt/history.log*"):
        opener = gzip.open if path.endswith(".gz") else open
        try:
            with opener(path, "rt", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        for block in text.split("\n\n"):
            date = re.search(r"^Start-Date: (.+)$", block, re.M)
            inst = re.search(r"^Install: (.+)$", block, re.M)
            if date and inst:
                pkgs = {p.split(":")[0].strip() for p in re.split(r"\),\s*", inst.group(1))}
                entries.append((date.group(1), pkgs))
    entries.sort()
    # The earliest transaction is the installer laying down the OS.
    return set().union(*(p for _, p in entries[1:])) if len(entries) > 1 else set()


manifest_names = [norm(r["name"]) for r in rows]


def in_manifest(name):
    n = norm(name)
    return any(n == m or (len(m) > 3 and m in n) or (len(n) > 3 and n in m) for m in manifest_names)


extra = {}  # display name -> where it's from
for app_id, name in flatpaks.items():
    extra.setdefault(name, "Flatpak")
for path, name in desktop:
    base = os.path.basename(path)
    if path.startswith("/var/lib/snapd/desktop/applications/"):
        if base.split("_")[0] not in seeded:
            extra.setdefault(name, "snap")
    elif path.startswith(f"{home}/.local/share/applications/"):
        if not base.startswith(("chrome-", "msedge-", "brave-")):  # web apps
            extra.setdefault(name, "~/.local/share/applications")
by_hand = installed_after_os()
if by_hand:
    system = [p for p, _ in desktop if p.startswith("/usr/share/applications/")]
    owners = {}
    query = ["dpkg", "-S"] if distro == "ubuntu" else ["rpm", "-qf", "--qf", "%{NAME}\n"]
    for chunk in (system[i:i + 200] for i in range(0, len(system), 200)):
        for line in run(*query, *chunk):
            if distro == "ubuntu" and ": " in line:
                pkg, path = line.split(": ", 1)
                for p in pkg.split(", "):
                    owners.setdefault(path, p.split(":")[0])
        if distro == "fedora":
            for path, pkg in zip(chunk, run(*query, *chunk)):
                owners[path] = pkg
    for path, name in desktop:
        if owners.get(path) in by_hand:
            extra.setdefault(name, f"{'apt' if distro == 'ubuntu' else 'dnf'}: {owners[path]}")
for path in appimages:
    extra.setdefault(os.path.basename(path), "AppImage")
extra = {n: src for n, src in extra.items() if not in_manifest(n)}

# ---- report ------------------------------------------------------------------
print(f"==> In the manifests but not found here ({len(missing)})")
for r in sorted(missing, key=lambda r: (r["kind"], r["name"].lower())):
    print(f"    {r['kind']}  {r['name']:<28} {r.get('homepage', '')}")
print(f"\n==> Installed here but not in a manifest ({len(extra)})")
for name in sorted(extra, key=str.lower):
    print(f"    {name:<34} ({extra[name]})")
if not missing and not extra:
    print("\nThe manifests match this machine.")
EOF
