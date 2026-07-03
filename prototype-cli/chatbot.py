#!/usr/bin/env python3
"""
chatbot.py — Prototype CLI de chatbot embarqué avec llama.cpp

Cas d'usage couverts :
  1. Chat interactif (Q/R libre)
  2. Résumé de texte
  3. Classification de sentiment

Usage :
  python chatbot.py --model /path/to/model.gguf
  python chatbot.py --model /path/to/model.gguf --task summary
  python chatbot.py --mock   # mode démo sans modèle

Auteur : PFE Master IA — LLMs Embarqués sur Smartphone
"""

import argparse
import os
import sys
import time
from typing import Optional

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.text import Text
    from rich.markdown import Markdown
    from rich.table import Table
    from rich import print as rprint
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

from utils import (
    InferenceMetrics, get_ram_usage_mb, get_system_ram_mb,
    format_size, save_metrics, build_chat_prompt, mock_generate
)

console = Console() if RICH_AVAILABLE else None


# ── Constantes ────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = (
    "Tu es un assistant IA embarqué, exécuté localement sur un smartphone "
    "sans connexion internet. Tu réponds de manière concise et précise en français. "
    "Limite tes réponses à 3-4 phrases maximum sauf si l'utilisateur demande plus de détails."
)

TASK_PROMPTS = {
    "chat": "",
    "summary": (
        "Tu es un assistant spécialisé dans le résumé de textes. "
        "Résume le texte fourni en 3-5 points clés, en français, de manière concise."
    ),
    "classification": (
        "Tu es un classificateur de sentiment. Analyse le texte fourni et réponds "
        "uniquement par : [POSITIF], [NÉGATIF], ou [NEUTRE], suivi d'un score de "
        "confiance en pourcentage et d'une justification en une phrase."
    ),
}

BANNER = """
╔══════════════════════════════════════════════════════════╗
║        🤖 LLM Embarqué — Prototype CLI (PFE)            ║
║   Modèles de langage on-device · llama-cpp-python        ║
╚══════════════════════════════════════════════════════════╝
"""

# ── Chargement du modèle ──────────────────────────────────────────────────────

def load_model(model_path: str, n_ctx: int = 2048, n_threads: int = 4):
    """Charge un modèle GGUF avec llama-cpp-python."""
    try:
        from llama_cpp import Llama
    except ImportError:
        print("❌ llama-cpp-python non installé.")
        print("   Exécuter : pip install llama-cpp-python")
        print("   Ou lancer en mode mock : python chatbot.py --mock")
        sys.exit(1)

    if not os.path.exists(model_path):
        print(f"❌ Modèle introuvable : {model_path}")
        print("   Télécharger un modèle GGUF depuis HuggingFace :")
        print("   bash ../scripts/download_model.sh gemma2-2b")
        sys.exit(1)

    print(f"⏳ Chargement du modèle ({format_size(model_path)})...")
    ram_before = get_ram_usage_mb()
    t0 = time.time()

    llm = Llama(
        model_path=model_path,
        n_ctx=n_ctx,
        n_threads=n_threads,
        n_gpu_layers=0,     # CPU uniquement (compatible mobile)
        verbose=False,
        use_mmap=True,      # Memory-mapped file : réduit l'utilisation RAM
        use_mlock=False,
    )

    load_time = time.time() - t0
    ram_after = get_ram_usage_mb()
    model_name = os.path.basename(model_path)

    print(f"✅ Modèle chargé en {load_time:.1f}s | "
          f"RAM : +{ram_after - ram_before:.0f} Mo ({ram_after:.0f} Mo total)")
    print(f"   Modèle : {model_name}")
    print(f"   Contexte : {n_ctx} tokens | Threads : {n_threads}")

    return llm, model_name


# ── Inférence ─────────────────────────────────────────────────────────────────

def generate_response(
    llm,
    prompt: str,
    model_name: str,
    max_tokens: int = 512,
    temperature: float = 0.7,
    stream: bool = True,
) -> tuple[str, InferenceMetrics]:
    """Génère une réponse et mesure les performances."""

    import psutil
    cpu_before = psutil.cpu_percent(interval=None)
    ram_before = get_ram_usage_mb()
    t_start = time.time()

    full_response = ""
    token_count = 0
    first_token_time = None

    if stream:
        print("\n🤖 Assistant : ", end="", flush=True)
        for chunk in llm(
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            top_k=40,
            top_p=0.95,
            stream=True,
            stop=["<|user|>", "\nUser:", "\nHuman:"],
        ):
            token_text = chunk["choices"][0]["text"]
            if first_token_time is None:
                first_token_time = time.time()
            full_response += token_text
            token_count += 1
            print(token_text, end="", flush=True)
        print()
    else:
        output = llm(
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            top_k=40,
            stop=["<|user|>", "\nUser:"],
        )
        full_response = output["choices"][0]["text"]
        first_token_time = t_start + 0.1  # estimation

    t_end = time.time()
    ram_after = get_ram_usage_mb()
    cpu_after = psutil.cpu_percent(interval=0.1)

    # Estimer le nombre de tokens du prompt
    prompt_tokens = len(prompt.split()) * 4 // 3  # approximation grossière

    prefill_time = (first_token_time or t_start) - t_start
    decode_time = t_end - (first_token_time or t_start)

    metrics = InferenceMetrics(
        model_name=model_name,
        prompt_tokens=prompt_tokens,
        generated_tokens=token_count or len(full_response.split()),
        prefill_time_s=max(prefill_time, 0.01),
        decode_time_s=max(decode_time, 0.01),
        total_time_s=t_end - t_start,
        prefill_speed_tps=prompt_tokens / max(prefill_time, 0.01),
        decode_speed_tps=token_count / max(decode_time, 0.01),
        ram_before_mb=ram_before,
        ram_after_mb=ram_after,
        ram_delta_mb=ram_after - ram_before,
        cpu_percent=(cpu_before + cpu_after) / 2,
    )

    return full_response.strip(), metrics


# ── Modes de tâche ────────────────────────────────────────────────────────────

def run_chat_mode(llm, model_name: str, mock: bool = False):
    """Mode chat interactif."""
    print("\n💬 Mode CHAT interactif")
    print("   Tapez votre message et appuyez sur Entrée.")
    print("   Commandes : /résumé, /classify, /stats, /quit\n")

    conversation = []
    all_metrics = []

    while True:
        try:
            user_input = input("👤 Vous : ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\n\nAu revoir !")
            break

        if not user_input:
            continue

        # Commandes spéciales
        if user_input.lower() in ("/quit", "/exit", "/q"):
            print("Au revoir !")
            break

        if user_input.lower() == "/stats" and all_metrics:
            m = all_metrics[-1]
            print(m.summary())
            continue

        if user_input.lower().startswith("/résumé "):
            text_to_summarize = user_input[8:]
            prompt = (TASK_PROMPTS["summary"] + "\n\nTexte à résumer :\n" + text_to_summarize)
            conversation_for_prompt = [{"role": "user", "content": prompt}]
        elif user_input.lower().startswith("/classify "):
            text_to_classify = user_input[10:]
            prompt = (TASK_PROMPTS["classification"] + "\n\nTexte : " + text_to_classify)
            conversation_for_prompt = [{"role": "user", "content": prompt}]
        else:
            conversation.append({"role": "user", "content": user_input})
            conversation_for_prompt = conversation

        # Construire le prompt
        full_prompt = build_chat_prompt(
            conversation_for_prompt,
            system_prompt=SYSTEM_PROMPT
        )

        # Générer la réponse
        if mock:
            print("\n🤖 Assistant [MOCK] : ", end="", flush=True)
            response, delay = mock_generate(user_input)
            print(response)
        else:
            response, metrics = generate_response(llm, full_prompt, model_name)
            all_metrics.append(metrics)
            save_metrics(metrics)
            print(f"\n   ⚡ {metrics.decode_speed_tps:.1f} tok/s | "
                  f"{metrics.total_time_s:.1f}s | "
                  f"+{metrics.ram_delta_mb:.0f} Mo RAM")

        conversation.append({"role": "assistant", "content": response})
        print()


def run_summary_mode(llm, model_name: str, input_file: Optional[str] = None, mock: bool = False):
    """Mode résumé de texte."""
    print("\n📝 Mode RÉSUMÉ de texte")

    if input_file and os.path.exists(input_file):
        with open(input_file) as f:
            text = f.read()
        print(f"   Fichier : {input_file} ({len(text)} caractères)")
    else:
        print("   Entrez le texte à résumer (terminez avec une ligne vide) :")
        lines = []
        while True:
            line = input()
            if not line:
                break
            lines.append(line)
        text = "\n".join(lines)

    if not text.strip():
        print("❌ Aucun texte fourni.")
        return

    prompt = build_chat_prompt(
        [{"role": "user", "content": f"Résume ce texte en 5 points clés :\n\n{text}"}],
        system_prompt=TASK_PROMPTS["summary"]
    )

    if mock:
        print("\n📋 Résumé [MOCK] :")
        response, _ = mock_generate(text, task="résumé")
        print(response)
    else:
        print("\n📋 Résumé en cours de génération...")
        response, metrics = generate_response(llm, prompt, model_name, stream=True)
        print(metrics.summary())
        save_metrics(metrics)


def run_classification_mode(llm, model_name: str, mock: bool = False):
    """Mode classification de sentiment."""
    print("\n🏷️  Mode CLASSIFICATION de sentiment")
    print("   Entrez le texte à classifier :")

    text = input("📝 Texte : ").strip()
    if not text:
        return

    prompt = build_chat_prompt(
        [{"role": "user", "content": text}],
        system_prompt=TASK_PROMPTS["classification"]
    )

    if mock:
        response, _ = mock_generate(text, task="classification")
        print(f"\n🏷️  Résultat [MOCK] : {response}")
    else:
        response, metrics = generate_response(
            llm, prompt, model_name, max_tokens=100, stream=False
        )
        print(f"\n🏷️  Résultat : {response}")
        print(metrics.summary())
        save_metrics(metrics)


# ── Point d'entrée ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Prototype CLI — Chatbot LLM embarqué (llama-cpp-python)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  python chatbot.py --mock                    # Démo sans modèle
  python chatbot.py --model model.gguf        # Chat interactif
  python chatbot.py --model model.gguf --task summary
  python chatbot.py --model model.gguf --task classify
        """
    )
    parser.add_argument("--model", type=str, help="Chemin vers le fichier GGUF")
    parser.add_argument("--mock", action="store_true", help="Mode démo sans modèle réel")
    parser.add_argument("--task", choices=["chat", "summary", "classify"],
                        default="chat", help="Tâche à exécuter (défaut: chat)")
    parser.add_argument("--n-ctx", type=int, default=2048, help="Taille du contexte")
    parser.add_argument("--threads", type=int, default=4, help="Nombre de threads CPU")
    parser.add_argument("--max-tokens", type=int, default=512, help="Tokens max générés")
    parser.add_argument("--input-file", type=str, help="Fichier texte d'entrée (mode summary)")
    parser.add_argument("--no-stream", action="store_true", help="Désactiver le streaming")

    args = parser.parse_args()

    # Afficher le banner
    print(BANNER)

    # Vérifications
    if not args.mock and not args.model:
        print("❌ Spécifier --model <chemin.gguf> ou --mock pour le mode démo.")
        print("   Exemple : python chatbot.py --mock")
        sys.exit(1)

    # Infos système
    ram = get_system_ram_mb()
    print(f"💻 Système : {ram['total_mb']:.0f} Mo RAM total | "
          f"{ram['available_mb']:.0f} Mo disponibles ({100-ram['percent']:.0f}% libre)")

    if args.mock:
        print("🎭 Mode MOCK activé — Réponses simulées (pas de modèle réel chargé)\n")
        llm = None
        model_name = "mock-model"
    else:
        llm, model_name = load_model(args.model, args.n_ctx, args.threads)

    # Lancer la tâche
    if args.task == "chat":
        run_chat_mode(llm, model_name, mock=args.mock)
    elif args.task == "summary":
        run_summary_mode(llm, model_name, args.input_file, mock=args.mock)
    elif args.task == "classify":
        run_classification_mode(llm, model_name, mock=args.mock)


if __name__ == "__main__":
    main()
