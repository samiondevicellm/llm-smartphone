"""
utils.py — Fonctions utilitaires pour le prototype CLI LLM embarqué.
"""

import time
import psutil
import os
import json
from dataclasses import dataclass, asdict
from typing import Optional


@dataclass
class InferenceMetrics:
    """Métriques d'une inférence."""
    model_name: str
    prompt_tokens: int
    generated_tokens: int
    prefill_time_s: float       # Temps de traitement du prompt
    decode_time_s: float        # Temps de génération des tokens
    total_time_s: float
    prefill_speed_tps: float    # tokens/s pendant le prefill
    decode_speed_tps: float     # tokens/s pendant le decode
    ram_before_mb: float
    ram_after_mb: float
    ram_delta_mb: float
    cpu_percent: float

    def to_dict(self) -> dict:
        return asdict(self)

    def summary(self) -> str:
        return (
            f"\n{'─'*50}\n"
            f"  Modèle       : {self.model_name}\n"
            f"  Prompt       : {self.prompt_tokens} tokens\n"
            f"  Généré       : {self.generated_tokens} tokens\n"
            f"  Prefill      : {self.prefill_time_s:.2f}s "
            f"({self.prefill_speed_tps:.1f} tok/s)\n"
            f"  Decode       : {self.decode_time_s:.2f}s "
            f"({self.decode_speed_tps:.1f} tok/s)\n"
            f"  Total        : {self.total_time_s:.2f}s\n"
            f"  RAM delta    : +{self.ram_delta_mb:.0f} Mo "
            f"({self.ram_after_mb:.0f} Mo total)\n"
            f"  CPU usage    : {self.cpu_percent:.1f}%\n"
            f"{'─'*50}"
        )


def get_ram_usage_mb() -> float:
    """Retourne la RAM utilisée par le processus courant en Mo."""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)


def get_system_ram_mb() -> dict:
    """Retourne l'utilisation RAM système."""
    mem = psutil.virtual_memory()
    return {
        "total_mb": mem.total / (1024 * 1024),
        "used_mb": mem.used / (1024 * 1024),
        "available_mb": mem.available / (1024 * 1024),
        "percent": mem.percent,
    }


def format_size(path: str) -> str:
    """Retourne la taille d'un fichier en format lisible."""
    size = os.path.getsize(path)
    for unit in ["o", "Ko", "Mo", "Go"]:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} To"


def save_metrics(metrics: InferenceMetrics, output_file: str = "results/metrics.json"):
    """Sauvegarde les métriques dans un fichier JSON."""
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    # Charger l'historique existant
    history = []
    if os.path.exists(output_file):
        with open(output_file) as f:
            history = json.load(f)

    history.append({
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        **metrics.to_dict()
    })

    with open(output_file, "w") as f:
        json.dump(history, f, indent=2, ensure_ascii=False)


def build_chat_prompt(messages: list[dict], system_prompt: str = "") -> str:
    """
    Construit un prompt au format chat compatible avec les modèles instruction.
    Supporte les formats Gemma, LLaMA, ChatML.
    """
    prompt = ""
    if system_prompt:
        prompt += f"<|system|>\n{system_prompt}\n"

    for msg in messages:
        role = msg["role"]
        content = msg["content"]
        if role == "user":
            prompt += f"<|user|>\n{content}\n<|assistant|>\n"
        elif role == "assistant":
            prompt += f"{content}\n"

    return prompt


MOCK_RESPONSES = {
    "default": (
        "Je suis un modèle de langage embarqué simulé. "
        "En mode réel, je serais exécuté localement via llama.cpp "
        "sur votre appareil sans connexion internet."
    ),
    "résumé": (
        "Résumé généré localement : Ce texte porte sur les modèles de langage "
        "embarqués sur smartphone. Les points clés sont : (1) la quantification "
        "réduit la taille des modèles de 70 %, (2) INT4 est le meilleur compromis "
        "qualité/performance pour les modèles 3-7B, (3) llama.cpp est le framework "
        "open source de référence pour Android."
    ),
    "classification": "Classification : [POSITIF] — Confiance : 87%",
}


def mock_generate(prompt: str, task: str = "default") -> tuple[str, float]:
    """Génère une réponse simulée avec délai réaliste."""
    import random

    response = MOCK_RESPONSES.get(task, MOCK_RESPONSES["default"])

    # Simuler une latence réaliste (10-15 tok/s sur mobile)
    tokens = len(response.split())
    delay = tokens / random.uniform(10, 15)
    time.sleep(min(delay, 3.0))  # Plafonné à 3s pour la démo

    return response, delay
