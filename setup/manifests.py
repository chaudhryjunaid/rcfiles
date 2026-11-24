#!/usr/bin/env python3
"""setup/manifests.py — what's installed on this machine vs the app manifests.

Shared by ../manifest-diff.sh (report only) and ../manifest-update.sh (write
the manifests); run those, not this. Usage:
    manifests.py diff     DISTRO REPO
    manifests.py update   DISTRO REPO [--prune] [--dry-run]

An app counts as installed here (a "candidate" for a manifest row) when a
person put it on this machine, as opposed to the OS installer:
  GUI: Flatpaks; snaps Ubuntu doesn't seed that have a launcher; distro
       packages installed after the OS that have a launcher (or are GNOME
       Shell extensions); entries in ~/.local/share/applications that aren't
       browser web apps or overrides of a system launcher; AppImages; GNOME
       Shell extensions in ~/.local/share.
  CLI: distro packages installed by hand after the OS (Ubuntu: apt's history
       and apt-mark; Fedora: dnf's user-installed list) without a launcher,
       other than what setup/<distro>.sh installs, libraries, fonts, boot and
       language packages, and the dependencies of another such package; snaps
       without a launcher; cargo, go, npm -g, uv and pip --user tools; files
       in /usr/local/bin and ~/.local/bin.
Rows are matched to candidates by package, then by name, so the odd one may
need a look by hand.
"""

import configparser
import csv
import glob
import gzip
import json
import os
import re
import shutil
import subprocess
import sys
from urllib.parse import quote, urlparse

GUI_COLUMNS = ["category", "name", "homepage", "description", "install", "ubuntu", "fedora"]
CLI_COLUMNS = ["category", "name", "homepage", "description", "install", "ubuntu", "fedora"]

HOME = os.path.expanduser("~")

# Never worth a row: boot and storage plumbing, the OS's meta packages,
# dictionaries, and snap runtimes (bases and content snaps).
IGNORE_NAMES = re.compile(
    r"^(grub|shim|efibootmgr|lvm2|mdadm|cryptsetup|linux-|kernel|ubuntu-|"
    r"w(british|american|canadian)$|hunspell-|myspell-|language-pack|langpacks-|"
    r"core\d*$|bare$|snapd|gnome-\d+-\d+|gtk-common-themes|kf\d+-core|mesa-\d+)"
)
# Debian sections of packages that are never a row of their own.
IGNORE_SECTIONS = {"libs", "oldlibs", "fonts", "kernel", "localization", "metapackages", "libdevel"}
# rustup's own proxies in ~/.cargo/bin (setup/common.sh installs rustup).
RUSTUP_BINS = {"cargo", "cargo-clippy", "cargo-fmt", "cargo-miri", "clippy-driver", "rls",
               "rust-analyzer", "rustc", "rustdoc", "rustfmt", "rust-gdb", "rust-gdbgui",
               "rust-lldb", "rustup"}
# Installed by the setup scripts (outside their package arrays).
SETUP_EXTRA = {"mise"}

# Desktop entry Categories -> manifest category, first match wins.
GUI_CATEGORIES = [
    ({"TerminalEmulator"}, "Terminals"),
    ({"WebBrowser"}, "Browsers"),
    ({"Development", "IDE", "TextEditor", "RevisionControl", "Database"}, "Editors and dev tools"),
    ({"Office", "WordProcessor", "Spreadsheet", "Presentation", "Publishing"}, "Writing and documents"),
    ({"InstantMessaging", "Chat", "Email", "VideoConference", "Telephony"}, "Communication"),
    ({"AudioVideo", "Audio", "Video", "Player", "Music"}, "Media"),
    ({"FileTransfer", "P2P", "Archiving", "Backup"}, "Sync, backup and downloads"),
    ({"System", "Settings", "Monitor", "Security", "PackageManager"}, "System"),
]
# Debian sections -> CLI manifest category.
CLI_SECTIONS = {
    "devel": "Dev and cloud", "vcs": "Dev and cloud", "python": "Dev and cloud",
    "interpreters": "Dev and cloud", "javascript": "Dev and cloud", "rust": "Dev and cloud",
    "golang": "Dev and cloud", "database": "Dev and cloud", "java": "Dev and cloud",
    "net": "Network and sharing", "web": "Network and sharing", "mail": "Network and sharing",
}
UNCATEGORIZED = "Uncategorized"


def run(*cmd, check=True):
    """stdout lines of cmd, or [] if it's missing or (with check) fails."""
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, check=check,
                             stdin=subprocess.DEVNULL).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return out.splitlines()


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def tidy(text):
    """One line, no trailing period, lowercase start (the manifests' style)."""
    text = " ".join((text or "").split()).rstrip(".")
    first = text.split(" ", 1)[0] if text else ""
    if first[:1].isupper() and (len(first) == 1 or first[1:].islower()):
        text = text[0].lower() + text[1:]
    return text


def chunks(items, n=200):
    items = list(items)
    for i in range(0, len(items), n):
        yield items[i:i + n]


def read_desktop(path):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        return dict(cp["Desktop Entry"])
    except Exception:
        return None


def metainfo(root, app_id):
    """(homepage, summary) from an AppStream metainfo file under root."""
    for sub in ("metainfo", "appdata"):
        for path in glob.glob(f"{root}/share/{sub}/{app_id}*.xml"):
            try:
                with open(path, encoding="utf-8") as f:
                    text = f.read()
            except OSError:
                continue
            url = re.search(r'<url type="homepage">\s*([^<\s]+)\s*</url>', text)
            summary = re.search(r"<summary>([^<]+)</summary>", text)
            return (url.group(1) if url else "", summary.group(1) if summary else "")
    return "", ""


class Machine:
    """What's installed here."""

    def __init__(self, distro, repo):
        self.distro = distro
        self.repo = repo
        self._packages()
        self._snaps()
        self._flatpaks()
        self._desktop()
        self._extensions()
        self.appimages = []
        for d in (f"{HOME}/AppImages", f"{HOME}/Applications", f"{HOME}/.local/bin"):
            self.appimages += glob.glob(f"{d}/*.AppImage") + glob.glob(f"{d}/*.appimage")

        # Names an app can be found under.
        self.names = {norm(s) for s in self.snaps}
        for app_id, name in self.flatpaks.items():
            self.names |= {norm(app_id.split(".")[-1]), norm(name)}
        for e in self.desktop:
            self.names |= {norm(e["name"]), norm(e["base"].split("_")[0])}
        for path in self.appimages:
            self.names.add(norm(re.split(r"[-_.]", os.path.basename(path))[0]))
        self.names |= {norm(e["name"]) for e in self.extensions}

    # ---- sources -----------------------------------------------------------
    def _packages(self):
        self.pkginfo = {}  # name -> {homepage, summary, section}
        if self.distro == "ubuntu":
            fmt = "${db:Status-Abbrev}\t${Package}\t${Section}\t${Homepage}\t${binary:Summary}\n"
            for line in run("dpkg-query", "-W", f"-f={fmt}"):
                status, name, section, homepage, summary = (line.split("\t") + [""] * 5)[:5]
                if status.startswith("ii"):
                    self.pkginfo[name] = {"section": section.split("/")[-1],
                                          "homepage": homepage, "summary": summary}
        else:
            for line in run("rpm", "-qa", "--qf", "%{NAME}\t%{URL}\t%{SUMMARY}\n"):
                name, homepage, summary = (line.split("\t") + [""] * 3)[:3]
                self.pkginfo[name] = {"section": "", "homepage": homepage, "summary": summary}
        self.packages = set(self.pkginfo)

    def _snaps(self):
        self.snaps = {}  # name -> notes column
        for line in run("snap", "list")[1:]:
            parts = line.split()
            if parts:
                self.snaps[parts[0]] = parts[-1]
        self.seeded = set()
        try:
            with open("/var/lib/snapd/seed/seed.yaml") as f:
                self.seeded = set(re.findall(r"^\s*name:\s*(\S+)", f.read(), re.M))
        except OSError:
            pass

    def _flatpaks(self):
        self.flatpaks = {}  # app id -> display name
        for line in run("flatpak", "list", "--app", "--columns=application,name"):
            app_id, _, name = line.partition("\t")
            self.flatpaks[app_id] = name or app_id

    def _desktop(self):
        local_dir = f"{HOME}/.local/share/applications"
        dirs = ["/usr/share/applications", "/usr/local/share/applications", local_dir,
                "/var/lib/snapd/desktop/applications",
                "/var/lib/flatpak/exports/share/applications",
                f"{HOME}/.local/share/flatpak/exports/share/applications"]
        entries = []
        for d in dirs:
            for path in sorted(glob.glob(f"{d}/*.desktop")):
                entry = read_desktop(path)
                if entry is None:
                    continue
                base = os.path.basename(path)[:-8]
                entries.append({
                    "path": path, "dir": d, "base": base,
                    "name": entry.get("Name", base),
                    "comment": entry.get("Comment") or entry.get("GenericName", ""),
                    "categories": set(filter(None, entry.get("Categories", "").split(";"))),
                    "exec": entry.get("Exec", ""),
                    "hidden": entry.get("NoDisplay", "").lower() == "true"
                    or entry.get("Hidden", "").lower() == "true",
                })
        # A launcher in ~/.local/share/applications overrides the one of the
        # same name elsewhere: to hide it (NoDisplay), or to tweak it.
        local = {e["base"]: e for e in entries if e["dir"] == local_dir}
        # Launchers shown in the app grid.
        self.desktop = [e for e in entries if not e["hidden"]
                        and (e["dir"] == local_dir or e["base"] not in local)]
        # Every distro-package launcher, shown or not, and the ones shown
        # (directly, or through a local override that isn't hidden).
        self.system_all = [e for e in entries if e["dir"] in ("/usr/share/applications",
                                                               "/usr/local/share/applications")]
        self.system_shown = [e for e in self.system_all if not e["hidden"]
                             and not (e["base"] in local and local[e["base"]]["hidden"])]
        self.overridden = {e["base"] for e in self.system_all if e["base"] in local}
        self.exec_names = set()
        for e in self.desktop:
            words = e["exec"].split()
            if words:
                self.exec_names.add(os.path.basename(words[0]))

    def _extensions(self):
        self.extensions = []  # GNOME Shell extensions
        for meta in sorted(glob.glob(f"{HOME}/.local/share/gnome-shell/extensions/*/metadata.json") +
                           glob.glob("/usr/share/gnome-shell/extensions/*/metadata.json")):
            try:
                with open(meta, encoding="utf-8") as f:
                    m = json.load(f)
            except (OSError, ValueError):
                continue
            if m.get("name"):
                self.extensions.append({"path": meta, "name": m["name"], "url": m.get("url", ""),
                                        "uuid": m.get("uuid") or os.path.basename(os.path.dirname(meta)),
                                        "description": m.get("description", "").split("\n")[0],
                                        "user": meta.startswith(HOME)})

    def installed_by_hand(self):
        """Distro packages installed by hand after the OS install."""
        if self.distro == "fedora":
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
        # The earliest transaction is the installer laying down the OS. Of
        # the rest, only what's still marked manual (not pulled in as a dep).
        after = set().union(*(p for _, p in entries[1:])) if len(entries) > 1 else set()
        return after & set(run("apt-mark", "showmanual"))

    def owners(self, paths):
        """path -> owning distro package."""
        out = {}
        for chunk in chunks(paths):
            if self.distro == "ubuntu":
                for line in run("dpkg", "-S", *chunk, check=False):
                    if ": " in line:
                        pkg, path = line.split(": ", 1)
                        out.setdefault(path, pkg.split(", ")[0].split(":")[0])
            else:
                for path in chunk:
                    pkg = run("rpm", "-qf", "--qf", "%{NAME}\n", path)
                    if pkg and " " not in pkg[0]:
                        out[path] = pkg[0]
        return out

    def launcher_owners(self, entries):
        """launcher path -> distro package, by the launcher file or else by
        the program it runs (some packages write their launcher at install)."""
        out = self.owners([e["path"] for e in entries])
        progs = {}
        for e in entries:
            if e["path"] in out or not e["exec"].split():
                continue
            prog = e["exec"].split()[0].strip('"')
            prog = prog if os.path.isabs(prog) else shutil.which(prog)
            if prog:
                progs[os.path.realpath(prog)] = e["path"]
        for prog, pkg in self.owners(list(progs)).items():
            out[progs[prog]] = pkg
        return out

    def origins(self, pkgs):
        """pkg -> "distro", "vendor:<repo>" or "local" (a .deb/.rpm file)."""
        out = {}
        if self.distro == "ubuntu":
            pkg = None
            in_installed = False
            for line in run("apt-cache", "policy", *pkgs):
                if line and not line.startswith(" ") and line.endswith(":"):
                    pkg, in_installed = line[:-1].split(":")[0], False
                    out[pkg] = set()
                elif line.startswith(" *** "):
                    in_installed = True
                elif re.match(r"^ {5}\S", line):
                    in_installed = False
                elif in_installed and pkg:
                    m = re.match(r"^\s+-?\d+\s+(\S+)", line)
                    if m:
                        out[pkg].add(m.group(1))
            result = {}
            for p, urls in out.items():
                hosts = [urlparse(u).hostname or "" for u in urls if "://" in u]
                if any(h.endswith(("archive.ubuntu.com", "ports.ubuntu.com", "security.ubuntu.com"))
                       for h in hosts):
                    result[p] = "distro"
                elif hosts:
                    result[p] = "vendor:" + hosts[0]
                else:
                    result[p] = "local"
            return result
        result = {}
        for line in run("dnf", "repoquery", "--installed", "--qf", "%{name}\t%{from_repo}\n", *pkgs):
            name, _, repo = line.partition("\t")
            if repo in ("fedora", "updates", "updates-testing", "anaconda", ""):
                result[name] = "distro"
            elif repo.startswith("@") or repo == "<unknown>":
                result[name] = "local"
            else:
                result[name] = "vendor:" + repo
        return result

    def dependencies(self, pkgs):
        """Packages that something in pkgs depends on or recommends."""
        deps = set()
        if self.distro == "ubuntu":
            fmt = "${Depends}, ${Recommends}, ${Pre-Depends}\n"
            for chunk in chunks(pkgs):
                for line in run("dpkg-query", "-W", f"-f={fmt}", *chunk):
                    for alt in line.split(","):
                        for dep in alt.split("|"):
                            m = re.match(r"\s*([a-z0-9][a-z0-9.+-]*)", dep)
                            if m:
                                deps.add(m.group(1))
        else:
            for chunk in chunks(pkgs):
                for line in run("rpm", "-q", "--requires", *chunk):
                    deps.add(line.split()[0])
        return deps

    def setup_packages(self):
        """Packages setup/<distro>.sh installs (its *PKGS=( ... ) arrays)."""
        pkgs = set(SETUP_EXTRA)
        try:
            with open(f"{self.repo}/setup/{self.distro}.sh", encoding="utf-8") as f:
                text = f.read()
        except OSError:
            return pkgs
        for body in re.findall(r"^\s*[A-Z_]*PKGS=\(([^)]*)\)", text, re.M):
            for line in body.splitlines():
                pkgs.update(line.split("#")[0].split())
        return pkgs

    def snap_info(self, name):
        """(homepage, summary) of an installed snap."""
        fields, key = {}, None
        for line in run("snap", "info", name):
            m = re.match(r"^([a-z-]+):\s*(.*)$", line)
            if m:
                key = m.group(1)
                fields[key] = m.group(2)
            elif key == "summary" and line.startswith("  "):
                fields[key] += " " + line.strip()
            elif key == "description":
                break
        homepage = ""
        for k in ("website", "contact"):
            if fields.get(k, "").startswith(("http://", "https://")):
                homepage = fields[k]
                break
        return homepage or f"https://snapcraft.io/{name}", fields.get("summary", "")


# ---- manifests -----------------------------------------------------------------
def load(path, kind):
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        row["_kind"] = kind
    return rows


def row_packages(row):
    """Distro packages a row names: its ubuntu/fedora columns, and the ones
    in its install column ("apt, from Docker's repo: docker-ce ...")."""
    pkgs = set(row.get("ubuntu", "").split()) | set(row.get("fedora", "").split())
    install = row.get("install", "")
    if re.match(r"^(apt|dnf|\.deb|\.rpm)\b", install) and ":" in install:
        pkgs |= set(re.findall(r"[a-z0-9][a-z0-9.+-]+", install.rsplit(":", 1)[1]))
    return pkgs


def row_install(row):
    """(kind, name) from a row's install column for the ones setup can
    install: ("snap", "<name> [--classic]"), ("flatpak", "<app id>"),
    ("extension", "<uuid>"); else (None, "")."""
    m = re.match(r"^(snap|flatpak|extension):\s*(.+)$", row.get("install", "").strip())
    return (m.group(1), m.group(2).strip()) if m else (None, "")


def row_commands(row):
    """Commands a row could be: its name, or the command a CLI row's
    description ends with after a comma ("..., claude"), or that the whole
    description is ("mongosh"). Only then: a description's last word is
    otherwise just a word ("... editor"), and often a command too."""
    cmds = {row["name"].lower().replace(" ", "-"), row["name"].lower().replace(" ", "")}
    m = re.search(r"(?:^|,\s*)([A-Za-z0-9_.-]+)$", row.get("description", "").strip())
    if m:
        cmds.add(m.group(1))
    return cmds


def write(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=columns, lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


# ---- candidates ----------------------------------------------------------------
def candidates(m):
    """Apps a person installed here, each a dict with the manifest columns
    plus _kind (GUI/CLI), _source, _pkgs and _cmds."""
    gui, cli = [], []
    by_hand = m.installed_by_hand()
    pkg_col = m.distro  # "ubuntu" or "fedora"
    pm = "apt" if m.distro == "ubuntu" else "dnf"

    def gui_category(cats):
        for keys, cat in GUI_CATEGORIES:
            if cats & keys:
                return cat
        return UNCATEGORIZED

    def pkg_install(pkg, origin):
        """How a distro package got here, for the install column."""
        if origin == "distro":
            return f"{pm}: {pkg}"
        if origin == "local":
            return f".{'deb' if m.distro == 'ubuntu' else 'rpm'} from the homepage: {pkg}"
        return f"{pm}, from {origin[7:]}'s repo: {pkg}"

    def add_gui(name, homepage, description, source, install="", pkgs=(),
                category=UNCATEGORIZED, pkg_value=""):
        gui.append({"category": category, "name": name, "homepage": homepage,
                    "description": tidy(description), "install": install, "ubuntu": "",
                    "fedora": "", pkg_col: pkg_value, "_kind": "GUI", "_source": source,
                    "_pkgs": set(pkgs), "_cmds": set()})

    # Flatpaks.
    for app_id, name in m.flatpaks.items():
        homepage, summary = "", ""
        for root in (f"/var/lib/flatpak/app/{app_id}/current/active/files",
                     f"{HOME}/.local/share/flatpak/app/{app_id}/current/active/files"):
            homepage, summary = metainfo(root, app_id)
            if homepage or summary:
                break
        entry = next((e for e in m.desktop if e["base"] == app_id), None)
        summary = summary or (entry["comment"] if entry else "")
        add_gui(name, homepage or f"https://flathub.org/apps/{app_id}",
                tidy(summary) or name, "Flatpak", install=f"flatpak: {app_id}",
                category=gui_category(entry["categories"] if entry else set()))

    # Snaps with a launcher, other than the ones Ubuntu seeds.
    snap_launchers = {}
    for e in m.desktop:
        if e["dir"] == "/var/lib/snapd/desktop/applications":
            snap_launchers.setdefault(e["base"].split("_")[0], e)
    for name, e in snap_launchers.items():
        if name in m.seeded or name not in m.snaps:
            continue
        homepage, summary = m.snap_info(name)
        classic = " --classic" if "classic" in m.snaps[name] else ""
        add_gui(e["name"], homepage, tidy(summary or e["comment"]) or e["name"],
                "snap", install=f"snap: {name}{classic}", category=gui_category(e["categories"]))

    # Distro packages with a launcher (or a Shell extension), installed by hand.
    # Packages whose launchers are all hidden still count as GUI, not CLI.
    owners = m.launcher_owners(m.system_all)
    gui_pkgs = set(owners.values())
    system = m.system_shown
    ext_owners = m.owners([e["path"] for e in m.extensions if not e["user"]])
    gui_pkgs |= set(ext_owners.values())
    hand_gui = sorted(gui_pkgs & by_hand)
    origins = m.origins(hand_gui) if hand_gui else {}
    seen = set()
    for e in system:
        pkg = owners.get(e["path"])
        if pkg not in by_hand or pkg in seen:
            continue
        # One row per package: its launcher named like it, else the first.
        same = [x for x in system if owners.get(x["path"]) == pkg]
        e = next((x for x in same if norm(x["base"].split(".")[-1]) == norm(pkg)), same[0])
        seen.add(pkg)
        info = m.pkginfo.get(pkg, {})
        distro = origins.get(pkg) == "distro"
        add_gui(e["name"], info.get("homepage", ""), e["comment"] or info.get("summary", ""),
                f"{pm}: {pkg}", install=pkg_install(pkg, origins.get(pkg, "distro")), pkgs=[pkg],
                category=gui_category(e["categories"]), pkg_value=pkg if distro else "")
    for ext in m.extensions:
        pkg = ext_owners.get(ext["path"])
        if ext["user"] or (pkg in by_hand and pkg not in seen):
            if pkg:
                seen.add(pkg)
            distro = pkg and origins.get(pkg) == "distro"
            homepage = ext["url"] or (m.pkginfo.get(pkg, {}).get("homepage", "") if pkg else "")
            add_gui(ext["name"], homepage or "https://extensions.gnome.org",
                    ext["description"], f"{pm}: {pkg}" if pkg else "GNOME extension",
                    install=pkg_install(pkg, origins.get(pkg, "distro")) if pkg else f"extension: {ext['uuid']}",
                    pkgs=[pkg] if pkg else [], category="GNOME extensions",
                    pkg_value=pkg if distro else "")

    # Launchers in ~/.local/share/applications (AppImages, hand-made ones),
    # but not browser web apps, and not overrides of a system launcher.
    appimage_names = set()
    for e in m.desktop:
        if e["dir"] != f"{HOME}/.local/share/applications":
            continue
        if e["base"].startswith(("chrome-", "msedge-", "brave-", "vivaldi-")):
            continue
        if e["base"] in m.overridden or e["base"] in m.flatpaks or \
                e["base"].split("_")[0] in m.snaps:
            continue
        is_appimage = ".appimage" in e["exec"].lower()
        if is_appimage:
            appimage_names.add(os.path.basename(e["exec"].split()[0]))
        add_gui(e["name"], "", tidy(e["comment"]) or e["name"],
                "AppImage" if is_appimage else "~/.local/share/applications",
                install="AppImage" if is_appimage else "", category=gui_category(e["categories"]))
    for path in m.appimages:
        if os.path.basename(path) not in appimage_names:
            name = re.split(r"[-_.]", os.path.basename(path))[0]
            add_gui(name, "", name, "AppImage", install="AppImage")

    # ---- CLI -------------------------------------------------------------------
    def add_cli(name, homepage, description, install, source, pkgs=(), cmds=(),
                category=UNCATEGORIZED, pkg_value=""):
        cli.append({"category": category, "name": name, "homepage": homepage,
                    "description": tidy(description), "install": install,
                    "ubuntu": "", "fedora": "", pkg_col: pkg_value, "_kind": "CLI",
                    "_source": source, "_pkgs": set(pkgs), "_cmds": set(cmds) | {name}})

    setup = m.setup_packages()
    cli_pkgs = set()
    for pkg in by_hand - gui_pkgs - setup:
        info = m.pkginfo.get(pkg)
        if info is None or IGNORE_NAMES.match(pkg) or info["section"] in IGNORE_SECTIONS:
            continue
        if m.distro == "fedora" and (re.match(r"^lib(?!reoffice)", pkg) or pkg.endswith("-fonts")):
            continue
        cli_pkgs.add(pkg)
    # A package another one depends on or recommends goes with it.
    cli_pkgs -= m.dependencies(sorted(by_hand))
    cli_origins = m.origins(sorted(cli_pkgs)) if cli_pkgs else {}
    for pkg in sorted(cli_pkgs):
        info = m.pkginfo[pkg]
        origin = cli_origins.get(pkg, "distro")
        install = pkg_install(pkg, origin)
        fallback = "" if origin != "distro" else (
            f"https://packages.ubuntu.com/{pkg}" if m.distro == "ubuntu"
            else f"https://packages.fedoraproject.org/pkgs/{pkg}/")
        add_cli(pkg, info["homepage"] or fallback, info["summary"], install, f"{pm}: {pkg}",
                pkgs=[pkg], category=CLI_SECTIONS.get(info["section"], UNCATEGORIZED),
                pkg_value=pkg if origin == "distro" else "")
        cli[-1]["_origin"] = origin

    # Snaps without a launcher.
    for name, notes in m.snaps.items():
        if name in m.seeded or name in snap_launchers or IGNORE_NAMES.match(name):
            continue
        if notes in ("base", "snapd", "core", "gadget", "kernel"):
            continue
        homepage, summary = m.snap_info(name)
        add_cli(name, homepage, summary, f"snap: {name}", "snap")

    # Language package managers.
    cargo = run("cargo", "install", "--list")
    for line in cargo:
        mm = re.match(r"^(\S+) v\S+", line)
        if mm:
            crate = mm.group(1)
            add_cli(crate, f"https://crates.io/crates/{crate}", "", f"cargo install {crate}",
                    "cargo", category="Dev and cloud")
    gopath = (run("go", "env", "GOPATH") or [""])[0]
    for path in sorted(glob.glob(f"{gopath}/bin/*")) if gopath else []:
        mod = ""
        for line in run("go", "version", "-m", path):
            parts = line.split()
            if len(parts) >= 2 and parts[0] == "path":
                mod = parts[1]
                break
        name = os.path.basename(path)
        add_cli(name, f"https://pkg.go.dev/{mod}" if mod else "", "",
                f"go install {mod}@latest" if mod else "go install", "go",
                cmds=[name], category="Dev and cloud")
    npm = run("npm", "-g", "ls", "--depth=0", "--json")
    try:
        deps = json.loads("\n".join(npm) or "{}").get("dependencies", {})
    except ValueError:
        deps = {}
    for name in sorted(deps):
        if name in ("npm", "corepack"):
            continue
        add_cli(name, f"https://www.npmjs.com/package/{name}", "", f"npm install -g {name}",
                "npm", category="Dev and cloud")
    uv_tools = set()
    for line in run("uv", "tool", "list"):
        mm = re.match(r"^([A-Za-z0-9_.-]+) v\S+", line)
        if mm:
            uv_tools.add(mm.group(1))
            add_cli(mm.group(1), f"https://pypi.org/project/{mm.group(1)}/", "",
                    f"uv tool install {mm.group(1)}", "uv", category="Dev and cloud")
    pip_scripts = set()
    pip = run(sys.executable, "-m", "pip", "list", "--user", "--not-required", "--format=json",
              "--disable-pip-version-check")
    try:
        user_dists = [d["name"] for d in json.loads("\n".join(pip) or "[]")]
    except (ValueError, KeyError, TypeError):
        user_dists = []
    if user_dists:
        show = "\n".join(run(sys.executable, "-m", "pip", "show", "-f",
                             "--disable-pip-version-check", *user_dists))
        for block in re.split(r"\n---\n", show):
            name = re.search(r"^Name: (.+)$", block, re.M)
            if not name:
                continue
            summary = re.search(r"^Summary: (.*)$", block, re.M)
            scripts = re.findall(r"^\s+\S*/bin/([^/\s]+)$", block, re.M)
            pip_scripts.update(scripts)
            n = name.group(1)
            add_cli(n, f"https://pypi.org/project/{n}/", summary.group(1) if summary else "",
                    f"pip install --user {n}", "pip --user", cmds=scripts, category="Dev and cloud")

    # Loose files in /usr/local/bin and ~/.local/bin.
    for d in ("/usr/local/bin", f"{HOME}/.local/bin"):
        for path in sorted(glob.glob(f"{d}/*")):
            name = os.path.basename(path)
            if not (os.path.isfile(path) and os.access(path, os.X_OK)):
                continue
            if name in SETUP_EXTRA or name in m.exec_names or name in pip_scripts or name in uv_tools:
                continue
            if name.lower().endswith(".appimage"):
                continue
            target = os.path.realpath(path)
            if "/mise/" in target or target.startswith("/opt/"):
                continue  # mise's own files; /opt apps have a launcher
            src = "release binary in /usr/local/bin" if d == "/usr/local/bin" else "installer into ~/.local/bin"
            add_cli(name, "", "", src, src, cmds=[name])
    return gui, cli


# ---- matching ------------------------------------------------------------------
def match(rows, cands, m):
    """(found rows, uncovered candidates, {id(row): the candidate it covers})."""
    pkg_to_row = {}
    origin_to_row = {}
    for row in rows:
        for p in row_packages(row):
            pkg_to_row.setdefault(p, row)
    # Other packages from the same vendor repo as a row's packages belong to
    # that row (docker-model-plugin with Docker Engine).
    vendor_pkgs = [p for p in pkg_to_row if p in m.packages]
    if vendor_pkgs:
        for p, origin in m.origins(vendor_pkgs).items():
            if origin.startswith("vendor:"):
                origin_to_row.setdefault(origin, pkg_to_row[p])
    norm_rows = {}
    cmd_rows = {}
    for row in rows:
        norm_rows.setdefault(norm(row["name"]), row)
        for c in row_commands(row):
            cmd_rows.setdefault(c, row)

    def fuzzy(name):
        n = norm(name)
        for key, row in norm_rows.items():
            if row["_kind"] == "GUI" and ((len(key) > 3 and key in n) or (len(n) > 3 and n in key)):
                return row
        return None

    covered_by = {}
    uncovered = []
    hit = set()
    for c in cands:
        row = next((pkg_to_row[p] for p in c["_pkgs"] if p in pkg_to_row), None)
        row = row or origin_to_row.get(c.get("_origin", ""))
        row = row or norm_rows.get(norm(c["name"]))
        row = row or next((cmd_rows[x] for x in c["_cmds"] if x in cmd_rows), None)
        if row is None and c["_kind"] == "GUI":
            row = fuzzy(c["name"])
        if row is None:
            uncovered.append(c)
        else:
            hit.add(id(row))
            covered_by.setdefault(id(row), c)

    def found(row):
        if id(row) in hit:
            return True
        pkgs = row.get(m.distro, "").split()
        if pkgs and all(p in m.packages for p in pkgs):
            return True
        vendor = row_packages(row) - set(row.get("ubuntu", "").split()) - set(row.get("fedora", "").split())
        if vendor and all(p in m.packages for p in vendor):
            return True
        kind, what = row_install(row)
        if kind == "snap" and what.split()[0] in m.snaps:
            return True
        if kind == "flatpak" and what in m.flatpaks:
            return True
        if kind == "extension" and any(os.path.basename(os.path.dirname(e["path"])) == what
                                       for e in m.extensions):
            return True
        if norm(row["name"]) in m.names:
            return True
        return any(shutil.which(c) for c in row_commands(row))

    return [r for r in rows if found(r)], uncovered, covered_by


def merge(rows, new):
    """rows plus new ones, each after the last row of its category (new
    categories at the end, Uncategorized last)."""
    out = list(rows)
    for cat in dict.fromkeys(sorted({c["category"] for c in new},
                                    key=lambda c: (c == UNCATEGORIZED, c.lower()))):
        add = sorted((c for c in new if c["category"] == cat), key=lambda c: c["name"].lower())
        last = max((i for i, r in enumerate(out) if r["category"] == cat), default=len(out) - 1)
        out[last + 1:last + 1] = add
    return out


# ---- commands ------------------------------------------------------------------
def main():
    cmd, distro, repo, *opts = sys.argv[1:]
    prune = "--prune" in opts
    dry_run = "--dry-run" in opts
    gui_csv, cli_csv = f"{repo}/gui-apps.manifest.csv", f"{repo}/cli-apps.manifest.csv"
    gui_rows, cli_rows = load(gui_csv, "GUI"), load(cli_csv, "CLI")
    rows = gui_rows + cli_rows

    m = Machine(distro, repo)
    gui_c, cli_c = candidates(m)
    # Dedupe by name (a snap and a Flatpak of the same app, ...).
    cands, names = [], set()
    for c in gui_c + cli_c:
        if norm(c["name"]) not in names:
            names.add(norm(c["name"]))
            cands.append(c)
    found_rows, new, covers = match(rows, cands, m)
    found_ids = {id(r) for r in found_rows}
    missing = [r for r in rows if id(r) not in found_ids]

    if cmd == "diff":
        print(f"==> In the manifests but not found here ({len(missing)})")
        for r in sorted(missing, key=lambda r: (r["_kind"], r["name"].lower())):
            print(f"    {r['_kind']}  {r['name']:<28} {r.get('homepage', '')}")
        print(f"\n==> Installed here but not in a manifest ({len(new)})")
        for c in sorted(new, key=lambda c: (c["_kind"], c["name"].lower())):
            print(f"    {c['_kind']}  {c['name']:<28} ({c['_source']})")
        if not missing and not new:
            print("\nThe manifests match this machine.")
        return 0

    keep = [r for r in rows if not prune or id(r) in found_ids]
    # Rows with no install column yet get it from what's installed here.
    filled = []
    for r in keep:
        c = covers.get(id(r))
        if not r.get("install") and c is not None and c.get("install"):
            r["install"] = c["install"]
            filled.append(r)
    new_gui = [c for c in new if c["_kind"] == "GUI"]
    new_cli = [c for c in new if c["_kind"] == "CLI"]
    out_gui = merge([r for r in keep if r["_kind"] == "GUI"], new_gui)
    out_cli = merge([r for r in keep if r["_kind"] == "CLI"], new_cli)

    print(f"==> Added ({len(new)})")
    for c in sorted(new, key=lambda c: (c["_kind"], c["name"].lower())):
        print(f"    {c['_kind']}  {c['name']:<28} ({c['_source']})")
    if filled:
        print(f"\n==> Install column filled in ({len(filled)})")
        for r in filled:
            print(f"    {r['_kind']}  {r['name']:<28} {r['install']}")
    label = "Removed, not found here" if prune else "Kept, though not found here (--prune drops them)"
    print(f"\n==> {label} ({len(missing)})")
    for r in sorted(missing, key=lambda r: (r["_kind"], r["name"].lower())):
        print(f"    {r['_kind']}  {r['name']}")
    todo = [c for c in new if not c["homepage"] or not c["description"] or c["category"] == UNCATEGORIZED]
    if todo:
        print(f"\n==> New rows to finish by hand ({len(todo)}): empty homepage (lint.sh fails"
              " until it's set) or description, or category Uncategorized")
        for c in sorted(todo, key=lambda c: (c["_kind"], c["name"].lower())):
            gaps = [g for g, bad in (("homepage", not c["homepage"]), ("description", not c["description"]),
                                     ("category", c["category"] == UNCATEGORIZED)) if bad]
            print(f"    {c['_kind']}  {c['name']:<28} {', '.join(gaps)}")
    if dry_run:
        print("\n(dry run: nothing written)")
    else:
        write(gui_csv, GUI_COLUMNS, out_gui)
        write(cli_csv, CLI_COLUMNS, out_cli)
        print("\nWrote gui-apps.manifest.csv and cli-apps.manifest.csv; review with git diff.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
