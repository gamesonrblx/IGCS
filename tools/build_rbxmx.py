#!/usr/bin/env python3
"""Build the IGCS v2 Roblox model without requiring Rojo in CI.

The source model in template/ is v1.4's existing communication stack. This
builder keeps that stack, replaces its imperative client with src/client/,
removes only the Adonis bridge, and embeds Wally's generated Packages folder.

Run `wally install` before the default build. For a source-only smoke test,
pass --skip-packages.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Iterable
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "template" / "IGCS_V1.4.a.rbxmx"
CLIENT = ROOT / "src" / "client"
CONFIGURATION = ROOT / "src" / "shared" / "IGCSConfiguration.lua"
PACKAGES = ROOT / "Packages"
DEFAULT_OUTPUT = ROOT / "dist" / "IGCS-v2.rbxmx"

_referent = 0


def next_referent() -> str:
    global _referent
    _referent += 1
    return f"RBX{_referent}"


def property_node(item: ET.Element, tag: str, name: str) -> ET.Element | None:
    return item.find(f"./Properties/{tag}[@name='{name}']")


def instance_name(item: ET.Element) -> str:
    node = property_node(item, "string", "Name")
    if node is None or node.text is None:
        raise RuntimeError(f"Malformed instance without a name: {item.get('class')}")
    return node.text


def children(item: ET.Element) -> Iterable[ET.Element]:
    return item.findall("./Item")


def child_named(item: ET.Element, name: str) -> ET.Element:
    for child in children(item):
        if instance_name(child) == name:
            return child
    raise RuntimeError(f"Couldn't find {name} under {instance_name(item)}")


def remove_children_named(item: ET.Element, name: str) -> None:
    for child in list(children(item)):
        if instance_name(child) == name:
            item.remove(child)


def read_source(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def set_source(item: ET.Element, source: str) -> None:
    properties = item.find("./Properties")
    if properties is None:
        properties = ET.SubElement(item, "Properties")
    node = property_node(item, "ProtectedString", "Source")
    if node is None:
        node = ET.SubElement(properties, "ProtectedString", {"name": "Source"})
    node.text = source


def make_instance(class_name: str, name: str, source: str | None = None) -> ET.Element:
    item = ET.Element("Item", {"class": class_name, "referent": next_referent()})
    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", {"name": "Name"}).text = name
    if source is not None:
        ET.SubElement(properties, "ProtectedString", {"name": "Source"}).text = source
    return item


def script_name(path: Path) -> str:
    for suffix in (".client.lua", ".client.luau", ".server.lua", ".server.luau", ".lua", ".luau"):
        if path.name.endswith(suffix):
            return path.name[: -len(suffix)]
    return path.name


def file_instance(path: Path) -> ET.Element | None:
    if path.name.endswith((".client.lua", ".client.luau")):
        return make_instance("LocalScript", script_name(path), read_source(path))
    if path.name.endswith((".server.lua", ".server.luau")):
        return make_instance("Script", script_name(path), read_source(path))
    if path.name.endswith((".lua", ".luau")):
        return make_instance("ModuleScript", script_name(path), read_source(path))
    return None


def build_directory(path: Path, name: str) -> ET.Element:
    project_file = path / "default.project.json"
    if project_file.exists():
        import json

        project = json.loads(project_file.read_text(encoding="utf-8"))
        return build_project_node(path, project["tree"], name)

    init = next((candidate for candidate in ("init.lua", "init.luau", "init.server.lua") if (path / candidate).exists()), None)
    class_name = "Script" if init and init.endswith(".server.lua") else "ModuleScript" if init else "Folder"
    item = make_instance(class_name, name, read_source(path / init) if init else None)

    for entry in sorted(path.iterdir()):
        if init and entry.name == init:
            continue
        if entry.is_dir():
            item.append(build_directory(entry, entry.name))
        else:
            built = file_instance(entry)
            if built is not None:
                item.append(built)
    return item


def build_project_node(base: Path, node: dict, name: str) -> ET.Element:
    node_path = node.get("$path")
    if node_path is not None:
        target = base / node_path
        if target.is_dir():
            return build_directory(target, name)
        built = file_instance(target)
        if built is None:
            raise RuntimeError(f"Cannot map project path: {target}")
        name_node = property_node(built, "string", "Name")
        assert name_node is not None
        name_node.text = name
        return built

    item = make_instance(node.get("$className", "Folder"), name)
    for key, child in node.items():
        if not key.startswith("$"):
            item.append(build_project_node(base, child, key))
    return item


def replace_client(content: ET.Element) -> None:
    gui = child_named(content, "IGCS_Client")
    cmain = child_named(gui, "CMain")
    set_source(cmain, read_source(CLIENT / "ReactChat.client.lua"))

    remove_children_named(gui, "OuterFrame")
    for name in ("ChatApp", "CommandAdapter", "Theme"):
        remove_children_named(gui, name)
        gui.append(make_instance("ModuleScript", name, read_source(CLIENT / f"{name}.lua")))


def replace_configuration(igcs: ET.Element) -> None:
    config = child_named(igcs, "IGCSConfiguration")
    set_source(config, read_source(CONFIGURATION))


def remove_adonis_bridge(content: ET.Element) -> None:
    remove_children_named(content, "IGCS_AdminBridge")

    chat_server = child_named(content, "ChatServer.server")
    source_node = property_node(chat_server, "ProtectedString", "Source")
    if source_node is None or source_node.text is None:
        raise RuntimeError("ChatServer.server has no source")

    replacement = '''\t\t-- Admin commands still hit hidden normal chat on the client (transport
\t\t-- for admin tools). Do not call an Adonis or BindableEvent API from IGCS.
\t\t-- Bubbles use the same IGCS Chat:Chat path as global chat for consistency.
\t\tif parsed.kind == "admin" then
\t\t\tlocal filtered = filterForBroadcast(player, parsed.message)
\t\t\tif filtered then
\t\t\t\tbubbleChatForPlayer(player, filtered)
\t\t\t\tbroadcastMessageRE:FireAllClients({
\t\t\t\t\tscope = "global",
\t\t\t\t\tuserId = player.UserId,
\t\t\t\t\tdisplayName = player.DisplayName,
\t\t\t\t\tusername = player.Name,
\t\t\t\t\ttext = filtered,
\t\t\t\t\tsystem = false,
\t\t\t\t\tt = os.time(),
\t\t\t\t})
\t\t\tend
\t\t\treturn
\t\tend

\t\t-- Emote commands'''
    pattern = r'\t\t-- Admin commands - fire to Adonis plugin via BindableEvent\n\t\tif parsed\.kind == "admin" then.*?\n\t\tend\n\n\t\t-- Emote commands'
    source, substitutions = re.subn(pattern, replacement, source_node.text, count=1, flags=re.DOTALL)
    if substitutions != 1:
        raise RuntimeError("Couldn't replace the v1.4 Adonis branch")

    # CoreGui cannot be changed from a server ModuleScript. The React client
    # owns visual hiding through TextChatService configurations instead.
    source = source.replace('\n\tlocal StarterGui = game:GetService("StarterGui")', "")
    source = source.replace(
        '\n\t-- Disable Roblox default chat UI (server-side; client disable still recommended)\n'
        '\tStarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)\n',
        "\n",
    )
    source_node.text = source


def prevent_duplicate_normal_chat_bubbles(content: ET.Element) -> None:
    chat_server = child_named(content, "ChatServer.server")
    source_node = property_node(chat_server, "ProtectedString", "Source")
    if source_node is None or source_node.text is None:
        raise RuntimeError("ChatServer.server has no source")

    replacement = '''\t\t-- Normal IGCS messages stay on the filtered IGCS relay. Sending them
\t\t-- through TextChatService as well makes Roblox create a second bubble.
\t\tbubbleChatForPlayer(fromPlayer, filteredText)

\t\tbroadcastMessageRE:FireAllClients({
\t\t\tscope = "global",
\t\t\tuserId = fromPlayer.UserId,
\t\t\tdisplayName = fromPlayer.DisplayName,
\t\t\tusername = fromPlayer.Name,
\t\t\ttext = filteredText,
\t\t\tsystem = false,
\t\t\tt = os.time(),
\t\t})
'''
    pattern = (
        r'\t\t-- Forward ALL messages to legacy chat system.*?'
        r'\n\t\t-- Only create bubble manually if legacy chat didn\'t work.*?'
        r'\n\t\tif not legacyWorked then'
        r'\n\t\t\tbubbleChatForPlayer\(fromPlayer, filteredText\)'
        r'\n\t\tend\n'
    )
    source, substitutions = re.subn(pattern, replacement, source_node.text, count=1, flags=re.DOTALL)
    if substitutions != 1:
        raise RuntimeError("Couldn't remove the duplicate normal-chat bubble route")
    source_node.text = source

def update_initialise(igcs: ET.Element, content: ET.Element, packages: ET.Element | None) -> None:
    initialise = child_named(igcs, "Initialise")
    source_node = property_node(initialise, "ProtectedString", "Source")
    if source_node is None or source_node.text is None:
        raise RuntimeError("Initialise has no source")

    source = source_node.text
    source = source.replace('\nlocal bridge = must(content, "IGCS_AdminBridge")', "")
    source = source.replace('installClone(iconModule, ReplicatedStorage, "IGCS_AdminBridge")\n', "")
    source = source.replace('local StarterGuiService = game:GetService("StarterGui")\n', "")
    source = source.replace(
        '\n-- ===== Disable default Roblox chat UI (server-side) =====\n'
        'StarterGuiService:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)\n',
        "\n",
    )

    if packages is not None:
        anchor = 'local configModule = must(igcsRoot, "IGCSConfiguration") -- ModuleScript\n'
        source = source.replace(anchor, anchor + 'local packages = must(content, "Packages") -- Folder\n')
        install_anchor = 'installClone(configModule, ReplicatedStorage, "IGCSConfiguration")\n'
        source = source.replace(install_anchor, install_anchor + 'installClone(packages, ReplicatedStorage, "Packages")\n')
    source_node.text = source


def build(output: Path, include_packages: bool) -> None:
    if not TEMPLATE.exists():
        raise RuntimeError(f"Missing source template: {TEMPLATE}")
    if include_packages and not PACKAGES.exists():
        raise RuntimeError("Packages/ is missing. Run `wally install` before building.")

    tree = ET.parse(TEMPLATE)
    document = tree.getroot()
    igcs = next((item for item in children(document) if instance_name(item) == "IGCS"), None)
    if igcs is None:
        raise RuntimeError("The template does not contain a top-level IGCS folder")
    content = child_named(igcs, "Content")

    replace_client(content)
    replace_configuration(igcs)
    remove_adonis_bridge(content)
    prevent_duplicate_normal_chat_bubbles(content)
    remove_children_named(content, "Packages")
    packages = build_directory(PACKAGES, "Packages") if include_packages else None
    if packages is not None:
        content.append(packages)
    update_initialise(igcs, content, packages)

    ET.indent(tree, space="\t")
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=True)
    print(f"Wrote {output} ({output.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--skip-packages", action="store_true", help="Build without Wally packages for a source smoke test")
    args = parser.parse_args()
    build(args.output, include_packages=not args.skip_packages)


if __name__ == "__main__":
    main()

