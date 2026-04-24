from __future__ import annotations

import json
from pathlib import Path

import networkx as nx


class KnowledgeGraph:
    def __init__(self) -> None:
        self.graph = nx.MultiDiGraph()

    @classmethod
    def from_jsonl(cls, nodes_path: str | Path, edges_path: str | Path) -> "KnowledgeGraph":
        kg = cls()
        for line in Path(nodes_path).read_text(encoding="utf-8").splitlines():
            if line.strip():
                node = json.loads(line)
                kg.graph.add_node(node["id"], **node)
        for line in Path(edges_path).read_text(encoding="utf-8").splitlines():
            if line.strip():
                edge = json.loads(line)
                attrs = dict(edge)
                source = attrs.pop("source")
                target = attrs.pop("target")
                kg.graph.add_edge(source, target, **attrs)
        return kg

    def semantic_paths(self, start_terms: list[str], max_hops: int = 4) -> list[list[str]]:
        paths: list[list[str]] = []
        for node_id, attrs in self.graph.nodes(data=True):
            label = f"{node_id} {attrs.get('label','')} {attrs.get('type','')}".lower()
            if any(term.lower() in label for term in start_terms):
                for target_id, target_attrs in self.graph.nodes(data=True):
                    if target_id == node_id:
                        continue
                    target_type = target_attrs.get("type")
                    if target_type in {"Policy", "Procedure", "Circular", "Action", "Document"}:
                        try:
                            for path in nx.all_simple_paths(self.graph, node_id, target_id, cutoff=max_hops):
                                paths.append(path)
                                if len(paths) >= 8:
                                    return paths
                        except nx.NetworkXNoPath:
                            continue
        return paths

    def edges_for_path(self, path: list[str]) -> list[str]:
        labels = []
        for a, b in zip(path, path[1:]):
            data = self.graph.get_edge_data(a, b) or {}
            relations = [v.get("relation", "RELATED_TO") for v in data.values()]
            labels.append(f"{a} -[{relations[0]}]-> {b}")
        return labels
