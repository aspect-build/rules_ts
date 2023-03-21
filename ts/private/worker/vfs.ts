
import * as path from "node:path";
import * as fs from "node:fs";
import {debug} from "./debugging";
import type { Inputs } from "./types";

const TypeSymbol = Symbol.for("fileSystemTree#type");
const SymlinkSymbol = Symbol.for("fileSystemTree#symlink");
const WatcherSymbol = Symbol.for("fileSystemTree#watcher");

const enum Type {
    DIR = 1,
    FILE = 2,
    SYMLINK = 3
}

const enum EventType {
    ADDED =  0,
    UPDATED = 1,
    REMOVED = 2,
}

type Node = {
    [TypeSymbol]?: Type,
    [SymlinkSymbol]?: string, 
    [k: string]: Node
}

type TraversalNode = {
    parent: TraversalNode,
    segment: string,
    current: Node
}

type WatchNode = {
    [WatcherSymbol]?: Set<{recursive: boolean, callback: WatcherCallback}>,
    [k: string]: WatchNode
}

type WatcherCallback = (path: string, type: EventType) => void;

export function createFilesystemTree(root: string, inputs: Inputs) {
    const tree: Node = {};
    const watchingTree: WatchNode = {};


    for (const p in inputs) {
        add(p);
    }

    function printTree() {
        const output = ["."]
        const walk = (node: Node, prefix: string) => {
            const subnodes = Object.keys(node).sort((a, b) => node[a][TypeSymbol] - node[b][TypeSymbol]);
            for (const [index, key] of subnodes.entries()) {
                const subnode = node[key];
                const parts = index == subnodes.length - 1 ? ["└── ", "    "] : ["├── ", "│   "];
                if (subnode[TypeSymbol] == Type.SYMLINK) {
                    output.push(`${prefix}${parts[0]}${key} -> ${subnode[SymlinkSymbol]}`);
                } else if (subnode[TypeSymbol] == Type.FILE) {
                    output.push(`${prefix}${parts[0]}<file> ${key}`);
                } else {
                    output.push(`${prefix}${parts[0]}<dir> ${key}`);
                    walk(subnode, `${prefix}${parts[1]}`);
                }
            }
        }
        walk(tree, "");
        debug(output.join("\n"));
    }

    function getNode(p: string): Node | undefined {
        const segments = p.split(path.sep);
        let node = tree;
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                return undefined;
            }
            node = node[segment];
            if (node[TypeSymbol] == Type.SYMLINK) {
                node = getNode(node[SymlinkSymbol]);
                // dangling symlink; symlinks point to a non-existing path.
                if (!node) {
                    return undefined;
                }
            }
        }
        return node;
    }

    function followSymlinkUsingRealFs(p: string) {
        const absolutePath = path.join(root, p)
        const stat = fs.lstatSync(absolutePath)
        // bazel does not expose any information on whether an input is a REGULAR FILE,DIR or SYMLINK
        // therefore a real filesystem call has to be made for each input to determine the symlinks.
        // NOTE: making a readlink call is more expensive than making a lstat call
        if (stat.isSymbolicLink()) {
            const linkpath = fs.readlinkSync(absolutePath);
            const absoluteLinkPath = path.isAbsolute(linkpath) ? linkpath : path.resolve(path.dirname(absolutePath), linkpath)
            return path.relative(root, absoluteLinkPath);
        }
        return p;
    }

    function add(p: string) {
        const segments = p.split(path.sep);
        const parents = [];
        let node = tree;
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];

            if (node && node[TypeSymbol] == Type.SYMLINK) {
                // stop; this is possibly path to a symlink which points to a treeartifact.
                //// version 6.0.0 has a weird behavior where it expands symlinks that point to treeartifact when --experimental_allow_unresolved_symlinks is turned off.
                debug(`WEIRD_BAZEL_6_BEHAVIOR: stopping at ${parents.join(path.sep)}`)
                return;
            }

            const currentp = path.join(...parents, segment);

            if (typeof node[segment] != "object") {
                const possiblyResolvedSymlinkPath = followSymlinkUsingRealFs(currentp)
                if (possiblyResolvedSymlinkPath != currentp) {
                    node[segment] = {
                        [TypeSymbol]: Type.SYMLINK,
                        [SymlinkSymbol]: possiblyResolvedSymlinkPath
                    }
                    notifyWatchers(parents, segment, Type.SYMLINK, EventType.ADDED);
                    return;
                }

                // last of the segments; which assumed to be a file
                if (i == segments.length - 1) {
                    node[segment] = { [TypeSymbol]: Type.FILE };
                    notifyWatchers(parents, segment, Type.FILE, EventType.ADDED);
                } else {
                    node[segment] = { [TypeSymbol]: Type.DIR };
                    notifyWatchers(parents, segment, Type.DIR, EventType.ADDED);
                }
            }
            node = node[segment];
            parents.push(segment);
        }
    }

    function remove(p: string) {
        const segments = p.split(path.sep).filter(seg => seg != "");
        let node: TraversalNode = {
            parent: undefined,
            segment: undefined,
            current: tree
        };
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            if (node.current[TypeSymbol] == Type.SYMLINK) {
                debug(`WEIRD_BAZEL_6_BEHAVIOR: removing ${p} starting from the symlink parent since it's a node with a parent that is a symlink.`)
                segments.splice(i) // remove rest of the elements starting from i which comes right after symlink segment.
                break;
            }
            const current = node.current[segment];
            if (!current) {
                // It is not likely to end up here unless fstree does something undesired. 
                // we will soft fail here due to regression in bazel 6.0
                debug(`remove: could not find ${p}`);
                return;
            }
            node = {
                parent: node,
                segment: segment,
                current: current
            }
        }

        // parent path of current path(p)
        const parentSegments = segments.slice(0, -1);

        // remove current node using parent node
        delete node.parent.current[node.segment];
        notifyWatchers(parentSegments, node.segment, node.current[TypeSymbol], EventType.REMOVED)

        // start traversing from parent of last segment
        let removal = node.parent;
        let parents = [...parentSegments]
        while (removal.parent) {
            const keys = Object.keys(removal.current);
            if (keys.length > 0) {
                // if current node has subnodes, DIR, FILE, SYMLINK etc, then stop traversing up as we reached a parent node that has subnodes. 
                break;
            }

            // walk one segment up/parent to avoid calling slice for notifyWatchers. 
            parents.pop();

            if (removal.current[TypeSymbol] == Type.DIR) {
                // current node has no children. remove current node using its parent node
                delete removal.parent.current[removal.segment];
                notifyWatchers(parents, removal.segment, Type.DIR, EventType.REMOVED)
            }

            // traverse up
            removal = removal.parent;
        }
    }

    function update(p: string) {
        const segments = p.split(path.sep);
        const parent = [];
        let node = tree;
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            parent.push(segment);
            const currentp = parent.join(path.sep);

            if (!node[segment]) {
                debug(`WEIRD_BAZEL_6_BEHAVIOR: can't walk down the path ${p} from ${currentp} inside ${segment}`);
                // bazel 6 + --noexperimental_allow_unresolved_symlinks: has a weird behavior where bazel will won't report symlink changes but 
                // rather reports changes in the treeartifact that symlink points to. even if symlink points to somewhere new. :(
                // since `remove` removed this node previously,  we just need to call add to create necessary nodes.
                // see: no_unresolved_symlink_tests.bats for test cases
                return add(p);
            }

            node = node[segment];

            if (node[TypeSymbol] == Type.SYMLINK) {
                const newSymlinkPath = followSymlinkUsingRealFs(currentp);
                if (newSymlinkPath == currentp) {
                    // not a symlink anymore.
                    debug(`${currentp} is no longer a symlink since ${currentp} == ${newSymlinkPath}`)
                    node[TypeSymbol] = Type.FILE;
                    delete node[SymlinkSymbol];
                } else if (node[SymlinkSymbol] != newSymlinkPath) {
                    debug(`updating symlink ${currentp} from ${node[SymlinkSymbol]} to ${newSymlinkPath}`)
                    node[SymlinkSymbol] = newSymlinkPath;
                }
                notifyWatchers(parent, segment, node[TypeSymbol], EventType.UPDATED);
                return; // return the loop as we don't anything to be symlinks from on;
            }
        }
        // did not encounter any symlinks along the way. it's a DIR or FILE at this point.
        const basename = parent.pop();
        notifyWatchers(parent, basename, node[TypeSymbol], EventType.UPDATED);
    }

    function notify(p: string) {
        const dirname = path.dirname(p);
        const basename = path.basename(p);
        notifyWatchers(dirname.split(path.sep), basename, Type.FILE, EventType.ADDED);
    }


    function fileExists(p: string) {
        const node = getNode(p);
        return typeof node == "object" && node[TypeSymbol] == Type.FILE;
    }

    function directoryExists(p: string) {
        const node = getNode(p);
        return typeof node == "object" && node[TypeSymbol] == Type.DIR;
    }

    function normalizeIfSymlink(p: string) {
        const segments = p.split(path.sep);
        let node = tree;
        let parents = [];
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                break;
            }
            node = node[segment];
            parents.push(segment);
            if (node[TypeSymbol] == Type.SYMLINK) {
               // ideally this condition would not met until the last segment of the path unless there's a symlink segment in
               // earlier segments. this indeed happens in bazel 6.0 with --experimental_allow_unresolved_symlinks turned off.
               break;
            }
        }

        if (typeof node == "object" && node[TypeSymbol] == Type.SYMLINK) {
           return parents.join(path.sep);
        }
        
        return undefined;
    }

    function realpath(p: string) {
        const segments = p.split(path.sep);
        let node = tree;
        let currentPath = "";
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                break;
            }
            node = node[segment];
            currentPath = path.join(currentPath, segment);
            if (node[TypeSymbol] == Type.SYMLINK) {
                currentPath = node[SymlinkSymbol];
                node = getNode(node[SymlinkSymbol]);
                // dangling symlink; symlinks point to a non-existing path. can't follow it
                if (!node) {
                    break;
                }
            }
        }
        return path.isAbsolute(currentPath) ? currentPath : "/" + currentPath;
    }

    function readDirectory(p: string, extensions?: string[], exclude?: string[], include?: string[], depth?: number) {
        const node = getNode(p);
        if (!node || node[TypeSymbol] != Type.DIR) {
            return []
        }
        const result: string[] = [];
        let currentDepth = 0;
        const walk = (p: string, node: Node) => {
            currentDepth++;
            for (const key in node) {
                const subp = path.join(p, key);
                const subnode = node[key];
                result.push(subp);
                if (subnode[TypeSymbol] == Type.DIR) {
                    if (currentDepth >= depth || !depth) {
                        continue;
                    }
                    walk(subp, subnode);
                } else if (subnode[TypeSymbol] == Type.SYMLINK) {
                    continue;
                }
            }
        }
        walk(p, node);
        return result;
    }

    function getDirectories(p: string) {
        const node = getNode(p);
        if (!node) {
            return []
        }
        const dirs = [];
        for (const part in node) {
            let subnode = node[part];
            if (subnode[TypeSymbol] == Type.SYMLINK) {
                // get the node where the symlink points to
                subnode = getNode(subnode[SymlinkSymbol]);
            }

            if (subnode[TypeSymbol] == Type.DIR) {
                dirs.push(part);
            }
        }
        return dirs
    }

    function notifyWatchers(trail: string[], segment: string, type: Type, eventType: EventType) {
        const final = [...trail, segment];
        const finalPath = final.join(path.sep);
        if (type == Type.FILE) {
            // notify file watchers watching at the file path, excluding recursive ones. 
            notifyWatcher(final, finalPath, eventType, /* recursive */ false);
            // notify directory watchers watching at the parent of the file, including the recursive directory watchers at parent.
            notifyWatcher(trail, finalPath, eventType);
        } else {
            // notify directory watchers watching at the parent of the directory, including recursive ones.
            notifyWatcher(trail, finalPath, eventType);
        }


        // recursively invoke watchers starting from trail;
        //  given path `/path/to/something/else`
        // this loop will call watchers all at `segment` with combination of these arguments;
        //  parent = /path/to/something     path = /path/to/something/else
        //  parent = /path/to               path = /path/to/something/else
        //  parent = /path                  path = /path/to/something/else
        let parent = [...trail];
        while (parent.length) {
            parent.pop();
            // invoke only recursive watchers
            notifyWatcher(parent, finalPath, eventType, true);
        }
    }

    function notifyWatcher(parent: string[], path: string, eventType: EventType, recursive?: boolean) {
        let node = getWatcherNode(parent);
        if (typeof node == "object" && WatcherSymbol in node) {
            for (const watcher of node[WatcherSymbol] as any) {
                // if recursive argument isn't provided, invoke both recursive and non-recursive watchers.
                if (recursive != undefined && watcher.recursive != recursive) {
                    continue;
                }
                watcher.callback(path, eventType);
            }
        }
    }

    function getWatcherNode(parts: string[]) {
        let node = watchingTree;
        for (const part of parts) {
            if (!(part in node)) {
                return undefined;
            }
            node = node[part];
        }
        return node;
    }

    function watch(p: string, callback: WatcherCallback, recursive = false) {
        const parts = p.split(path.sep);
        let node = watchingTree;
        for (const part of parts) {
            if (!part) {
                continue;
            }
            if (!(part in node)) {
                node[part] = {};
            }
            node = node[part];
        }
        if (!(WatcherSymbol in node)) {
            node[WatcherSymbol] = new Set();
        }
        const watcher = { callback, recursive };
        node[WatcherSymbol].add(watcher);
        return () => node[WatcherSymbol].delete(watcher)
    }

    function watchFile(p: string, callback: WatcherCallback) {
        return watch(p, callback)
    }

    return { add, remove, update, notify, fileExists, directoryExists, normalizeIfSymlink, realpath, readDirectory, getDirectories, watchDirectory: watch, watchFile: watchFile, printTree }
}
