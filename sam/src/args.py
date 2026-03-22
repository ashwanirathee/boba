"""
Name: Ashwani
Email: arathee1@ucsc.edu
"""

import argparse


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--run_id", type=str, default="run_default_gsam", help="Run ID for logging"
    )
    p.add_argument(
        "--log-level",
        type=str,
        default="WARNING",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging level",
    )
    p.add_argument(
        "--tts_model",
        type=str,
    )
    p.add_argument(
        "--tts_voice",
        type=str,
    )
    p.add_argument(
        "--stt_model",
        type=str,
    )
    p.add_argument(
        "--llm_model",
        type=str,
    )
    p.add_argument(
        "--ollama_base_url",
        type=str,
    )

    return p


def parse_args(argv=None):
    return build_parser().parse_args(argv)
