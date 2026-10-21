"""Surveille les sauvegardes WoW et synchronise la base MJ avec Google Sheets.

Une entree enregistree dans WoW EXISTE : un /reload ou une deconnexion
declenche l'archivage et l'envoi de tout ce qui a ete enregistre et n'est pas
encore dans la base. Il n'y a pas de brouillon dormant (15 octobre 2026) : le
premier lancement et un nouveau compte publient eux aussi ce qu'ils trouvent.

Les suppressions, elles, ne partent que lorsqu'elles sont NOUVELLES : les masques
deja presents au premier passage datent de l'ancien modele, ou ils cachaient du
contenu sans l'effacer, et l'addon les oublie a sa mise a jour.
Les changements distants sont releves regulierement.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import time
from datetime import datetime
from pathlib import Path
from threading import Event

import psutil
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

import gsheet_base as db


STATE_FILE = db.ROOT / "Outils" / ".gsheet_auto_state.json"
LOG_FILE = db.ROOT / "Sauvegardes_LCM" / "synchro.log"
DEPLOY = (
    (db.lcm_db.PLAYER_OUTPUT, "LesContesMalveillants/Data/Genere/Atelier.lua"),
    (db.lcm_db.MJ_OUTPUT, "LesContesMalveillants_MJ/Genere/Atelier_MJ.lua"),
)


def log(message: str) -> None:
    line = f"{datetime.now().astimezone().isoformat(timespec='seconds')} {message}"
    print(line, flush=True)
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as stream:
        stream.write(line + "\n")


def read_state(sheet_id: str, retail: Path) -> dict:
    if not STATE_FILE.exists():
        return {"version": 1, "sheet_id": sheet_id, "retail": str(retail), "files": {}}
    state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    if state.get("version") != 1 or state.get("sheet_id") != sheet_id or state.get("retail") != str(retail):
        raise ValueError("etat automatique lie a un autre classeur ou dossier WoW")
    return state


def save_state(state: dict) -> None:
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(STATE_FILE)


def draft_row(family: str, definition: dict) -> list[object]:
    identifier = db.lcm_db.safe_id(definition.get("id"))
    return db.canonical([family, identifier, definition.get("label", identifier),
                         definition.get("description", ""),
                         db.lcm_db.side_for(family, definition) == "mj", db.ACTIVE,
                         db.lcm_db.lua_value(definition)])


def snapshot(file: Path) -> dict:
    raw = file.read_bytes()
    root = db.lcm_db.parse_assignments(raw.decode("utf-8", errors="replace"))
    saved = root.get("LCM_MJ_DB")
    if not isinstance(saved, dict):
        raise ValueError(f"LCM_MJ_DB absent : {file}")
    drafts: dict[str, list[object]] = {}
    for family, definitions in (saved.get("brouillons") or {}).items():
        if family not in db.lcm_db.FAMILIES or not isinstance(definitions, dict):
            continue
        for definition in definitions.values():
            if not isinstance(definition, dict):
                continue
            row = draft_row(family, definition)
            drafts[db.key(row)] = row
    masks = set()
    for family, identifiers in (saved.get("masques") or {}).items():
        if family not in db.lcm_db.FAMILIES or not isinstance(identifiers, dict):
            continue
        for identifier, active in identifiers.items():
            if active:
                masks.add(f"{family}/{db.lcm_db.safe_id(identifier)}")
    return {"sha256": hashlib.sha256(raw).hexdigest(), "drafts": drafts,
            "masks": sorted(masks)}


def record(snap: dict, published: dict[str, str] | None = None,
           held: list[str] | None = None) -> dict:
    return {"sha256": snap["sha256"],
            "drafts": {key: db.digest(row) for key, row in snap["drafts"].items()},
            "masks": snap["masks"], "published": published or {}, "held": held or []}


def mj_files(retail: Path) -> dict[str, Path]:
    account = retail / "WTF" / "Account"
    if not account.is_dir():
        raise FileNotFoundError(f"dossier WoW introuvable : {account}")
    return {path.relative_to(retail).as_posix(): path
            for path in sorted(account.glob("*/SavedVariables/LesContesMalveillants_MJ.lua"))}


def pending_rows(before: dict | None,
                 after: dict) -> tuple[dict[str, list[object]], set[str]]:
    """Ce qui doit partir : toute entree pas encore publiee sous cette forme,
    et les suppressions apparues depuis le passage precedent.

    On compare a `published`, pas a l'instantane precedent : une entree vue
    sans avoir ete publiee (l'ancien point de depart protege) part elle aussi.
    """
    published = (before or {}).get("published", {})
    drafts = {key: row for key, row in after["drafts"].items()
              if published.get(key) != db.digest(row)}
    known = set(before.get("masks", [])) if before is not None else set(after["masks"])
    masks = set(after["masks"]) - known
    return drafts, masks


def stale_rows(before: dict | None, drafts: dict[str, list[object]],
               local: dict[str, list[object]]) -> set[str]:
    """Les vieilles copies qui ecraseraient une autre version de la base.

    Une entree deja vue au passage precedent, jamais publiee et pas modifiee
    depuis (ou trouvee sur un compte inconnu) n'a pas ete ecrite sous ce
    service : c'est un reste de l'ancien modele. Absente de la base, elle part
    (c'etait le cas d'une armure qu'un coffre citait). Presente sous une AUTRE
    forme, elle ne part pas : un autre MJ l'a reecrite depuis, et une vieille
    copie n'a pas a effacer son travail sans que personne le sache
    (15 octobre 2026). Une entree modifiee en jeu, elle, part toujours.
    """
    old = (before or {}).get("drafts", {})
    return {key for key, row in drafts.items()
            if (before is None or old.get(key) == db.digest(row))
            and local.get(key) is not None and local[key] != row}


def stage_changes(api: db.Sheets, sheet_id: str,
                  changes: dict[str, list[object]], masks: set[str]) -> list[list[object]]:
    """Valide toutes les modifications avant la premiere ecriture locale."""
    plan = db.feuilles()
    by_family = {family: name for name, item in plan.items() for family in item["familles"]}
    remote_cache: dict[str, dict] = {}
    local_cache: dict[str, dict] = {}
    staged = []
    conflicts = []
    for key in sorted(set(changes) | masks):
        family, identifier = key.split("/", 1)
        tab = by_family[family]
        if family not in remote_cache:
            api.select(plan[tab]["titre"])
            remote_cache[family] = db.remote_rows(api.values())
            local_cache[family] = db.local_rows({family})
        remote = remote_cache[family].get(key)
        local = local_cache[family].get(key)
        base_hash = db.load_state(sheet_id, tab).get(key)
        remote_hash = db.digest(remote[1]) if remote else None
        local_hash = db.digest(local) if local else None
        if key in changes:
            row = changes[key]
        else:
            row = db.canonical([family, identifier,
                                remote[1][2] if remote else "",
                                remote[1][3] if remote else "",
                                remote[1][4] if remote else family in db.lcm_db.RESERVED_MJ,
                                db.DELETED, remote[1][6] if remote else ""])
        new_hash = db.digest(row)
        if remote_hash == new_hash:
            continue
        if remote_hash != base_hash or (local_hash not in (base_hash, new_hash)):
            # Un point pose ne bloque pas la synchronisation : le plus recent
            # l'emporte (gsheet_base.pose_plus_recente). Plus ancien que la
            # base, il ne part pas ; la base le remplacera ici.
            if family == "poses":
                if remote is None or db.pose_plus_recente(row, remote[1]):
                    staged.append(row)
                continue
            conflicts.append(key)
            continue
        staged.append(row)
    if conflicts:
        raise ValueError("conflit : contenu local et Sheet modifies : " + ", ".join(conflicts))
    return staged


def sync_content(api: db.Sheets, sheet_id: str) -> None:
    for name, item in db.feuilles().items():
        if item["familles"]:
            api.select(item["titre"])
            db.synchronise(api, sheet_id, name, set(item["familles"]),
                           prepare=False, verbose=False)


def wow_running() -> bool:
    for process in psutil.process_iter(["name"]):
        try:
            if (process.info["name"] or "").lower() == "wow.exe":
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return False


class SavedVariablesListener(FileSystemEventHandler):
    def __init__(self, changed: Event):
        self.changed = changed

    def on_any_event(self, event) -> None:
        if event.is_directory:
            return
        for path in (event.src_path, getattr(event, "dest_path", "")):
            if Path(path).name in {
                "LesContesMalveillants.lua", "LesContesMalveillants.lua.bak",
                "LesContesMalveillants_MJ.lua", "LesContesMalveillants_MJ.lua.bak",
            }:
                self.changed.set()
                return


def clear_published(file: Path, published: dict[str, str]) -> int:
    """Retire seulement les copies deja publiees, WoW ferme et apres archive."""
    raw = file.read_bytes()
    assignments = db.lcm_db.parse_assignments(raw.decode("utf-8", errors="replace"))
    saved = assignments.get("LCM_MJ_DB", {})
    drafts = saved.get("brouillons", {}) if isinstance(saved, dict) else {}
    removed = 0
    for family, definitions in drafts.items():
        if family not in db.lcm_db.FAMILIES or not isinstance(definitions, dict):
            continue
        for slot, definition in list(definitions.items()):
            if not isinstance(definition, dict):
                continue
            row = draft_row(family, definition)
            if published.get(db.key(row)) == db.digest(row):
                del definitions[slot]
                removed += 1
    if not removed:
        return 0
    source = "".join(name + " = " + db.lcm_db.lua_value(value) + "\n"
                     for name, value in assignments.items())
    if db.lcm_db.parse_assignments(source) != assignments:
        raise ValueError(f"reecriture Lua non equivalente : {file}")
    backup = db.ROOT / "Sauvegardes_LCM" / "avant_nettoyage" / datetime.now().strftime("%Y%m%d_%H%M%S")
    backup.mkdir(parents=True, exist_ok=True)
    previous = backup / file.parent.parent.name / file.name
    previous.parent.mkdir(parents=True, exist_ok=True)
    previous.write_bytes(raw)
    temporary = file.with_name(file.name + ".lcm_tmp")
    temporary.write_text(source, encoding="utf-8", newline="\n")
    temporary.replace(file)
    return removed


def deploy(retail: Path) -> int:
    addons = retail / "Interface" / "AddOns"
    changed = 0
    for source, relative in DEPLOY:
        target = addons / relative
        if not target.is_file():
            raise FileNotFoundError(f"addon MJ non installe : {target}")
        data = source.read_bytes()
        if target.read_bytes() == data:
            continue
        backup = db.ROOT / "Sauvegardes_LCM" / "deploiements" / datetime.now().strftime("%Y%m%d_%H%M%S")
        old = backup / relative
        old.parent.mkdir(parents=True, exist_ok=True)
        old.write_bytes(target.read_bytes())
        temporary = target.with_name(target.name + ".lcm_tmp")
        temporary.write_bytes(data)
        temporary.replace(target)
        changed += 1
    return changed


def run_once(api: db.Sheets, sheet_id: str, retail: Path,
             archive_event: bool = False) -> None:
    state = read_state(sheet_id, retail)
    files = mj_files(retail)
    current = {name: snapshot(file) for name, file in files.items()}
    # Une seule lecture du Sheet par passage, et aucune s'il n'a pas change
    # depuis la derniere : tout ce qui suit lit ce qui vient d'etre charge.
    api.actualiser(db.onglets_contenu())
    if not STATE_FILE.exists():
        # La comparaison avec la Sheet a besoin de son etat de reference.
        sync_content(api, sheet_id)
        log("Premier lancement : ce qui est enregistre dans WoW part dans la base.")
    work: dict[str, tuple[dict | None, dict, dict[str, list[object]]]] = {}
    drafts: dict[str, list[object]] = {}
    masks: set[str] = set()
    local: dict[str, list[object]] | None = None
    held_by_file: dict[str, list[str]] = {}
    for name, snap in current.items():
        before = state["files"].get(name)
        new_drafts, new_masks = pending_rows(before, snap)
        if new_drafts:
            local = db.local_rows() if local is None else local
            held = stale_rows(before, new_drafts, local)
            for key in sorted(held):
                del new_drafts[key]
            held_by_file[name] = sorted(held)
            # Dit une fois, pas a chaque releve de la Sheet.
            fresh = set(held) - set((before or {}).get("held", []))
            if fresh:
                log(f"{name} : vieille(s) copie(s) NON publiee(s), la base en a une autre version : "
                    + ", ".join(sorted(fresh)) + ". A trancher dans WoW (modifier l'entree la publie).")
                # Note tout de suite : une erreur de la Sheet plus loin ferait
                # sinon redire l'avertissement a chaque nouvelle tentative.
                if before is not None:
                    before["held"] = sorted(held)
                    save_state(state)
        if before is None or before.get("sha256") != snap["sha256"] or new_drafts or new_masks:
            work[name] = (before, snap, new_drafts)
        for key, row in new_drafts.items():
            if key in drafts and drafts[key] != row:
                raise ValueError(f"deux comptes ont modifie {key} differemment")
            drafts[key] = row
        masks.update(new_masks)
    if work:
        db.sauvegarder(api, retail)
        staged = stage_changes(api, sheet_id, drafts, masks) if drafts or masks else []
        backup = db.ROOT / "Sauvegardes_LCM" / "avant_import" / datetime.now().strftime("%Y%m%d_%H%M%S")
        for row in staged:
            db.apply_remote(row, backup)
        if staged:
            log(f"{len(staged)} entree(s) modifiee(s) dans WoW, envoi en cours.")
        sync_content(api, sheet_id)
        for name, (before, snap, sent) in work.items():
            # Deja dans la base telle quelle compte comme publie : la Sheet
            # l'avait, `stage_changes` l'a simplement saute.
            published = {key: value for key, value in (before or {}).get("published", {}).items()
                         if key in snap["drafts"] and db.digest(snap["drafts"][key]) == value}
            for key, row in sent.items():
                published[key] = db.digest(row)
            state["files"][name] = record(snap, published, held_by_file.get(name))
        save_state(state)
        log(f"Sauvegarde WoW et synchronisation terminees : {len(staged)} entree(s) publiee(s).")
    else:
        if archive_event:
            db.sauvegarder(api, retail)
        sync_content(api, sheet_id)
    # Les copies retenues ont ete dites : on le note, pour ne pas le redire a
    # chaque releve.
    retenues = False
    for name, held in held_by_file.items():
        if name in state["files"] and state["files"][name].get("held", []) != held:
            state["files"][name]["held"] = held
            retenues = True
    if retenues:
        save_state(state)
    if not wow_running():
        for name, file in files.items():
            published = state["files"].get(name, {}).get("published", {})
            if not published:
                continue
            if any(key in current[name]["drafts"] and
                   db.digest(current[name]["drafts"][key]) == value
                   for key, value in published.items()):
                db.sauvegarder(api, retail)
                removed = clear_published(file, published)
                if removed:
                    snap = snapshot(file)
                    state["files"][name] = record(snap, {key: value for key, value in published.items()
                                                         if key in snap["drafts"]},
                                                  state["files"][name].get("held"))
                    save_state(state)
                    log(f"{removed} entree(s) deja dans la base retiree(s) de la file d'envoi de {name}.")
    deployed = deploy(retail)
    if deployed:
        log(f"{deployed} fichier(s) d'addon actualise(s) ; /reload requis si WoW est ouvert.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("once", "watch"))
    parser.add_argument("--sheet-id", required=True)
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--retail", required=True, type=Path)
    # Deux minutes : un releve ne coute plus qu'une question a Drive tant que
    # le classeur ne bouge pas, mais le quota est partage avec l'autre MJ.
    parser.add_argument("--interval", type=int, default=120,
                        help="secondes entre deux releves du Sheet (defaut : 120)")
    args = parser.parse_args()
    retail = args.retail.resolve()
    api = db.Sheets(args.credentials, args.sheet_id, journal=log)
    if args.mode == "once":
        run_once(api, args.sheet_id, retail)
        return
    log("Ecoute des sauvegardes WoW demarree, sans fenetre de terminal.")
    next_remote = 0.0
    game_was_running = False
    changed = Event()
    observer = Observer()
    observer.schedule(SavedVariablesListener(changed),
                      str(retail / "WTF" / "Account"), recursive=True)
    observer.start()
    try:
        while True:
            game_is_running = game_was_running
            try:
                now = time.monotonic()
                game_is_running = wow_running()
                file_changed = changed.is_set()
                if game_is_running and not game_was_running:
                    log("WoW ouvert : recuperation immediate du contenu partage.")
                    changed.clear()
                    run_once(api, args.sheet_id, retail, archive_event=file_changed)
                    next_remote = time.monotonic() + args.interval
                elif file_changed:
                    changed.clear()
                    time.sleep(2)  # Laisser WoW terminer son ecriture.
                    changed.clear()
                    run_once(api, args.sheet_id, retail, archive_event=True)
                    next_remote = time.monotonic() + args.interval
                elif game_was_running and not game_is_running:
                    log("WoW ferme : verification de la derniere sauvegarde.")
                    run_once(api, args.sheet_id, retail)
                elif game_is_running and now >= next_remote:
                    run_once(api, args.sheet_id, retail)
                    next_remote = time.monotonic() + args.interval
                game_was_running = game_is_running
                changed.wait(2)
            except (OSError, ValueError, RuntimeError, db.lcm_db.LuaError) as error:
                log(f"ERREUR : {error}")
                # L'etat de WoW est NOTE meme quand le passage echoue : sinon la
                # tentative suivante refaisait tout le passage « WoW ouvert »,
                # et un quota depasse ne retombait jamais (15 octobre 2026).
                game_was_running = game_is_running
                # Le quota de Google se compte a la minute : retenter au bout
                # de 30 s retombait dans la meme fenetre. Ce qui n'est pas
                # parti repart au releve suivant, rien n'est perdu.
                attente = 90 if "(429)" in str(error) else 30
                next_remote = time.monotonic() + attente
                time.sleep(attente)
    finally:
        observer.stop()
        observer.join()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, db.lcm_db.LuaError) as error:
        log(f"ERREUR : {error}")
        raise SystemExit(1) from error
