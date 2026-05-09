#!/bin/bash
set -e

echo "Pulling models..."

ollama pull deepseek-r1:14b
ollama pull qwen2.5-coder:14b
ollama pull qwen3:14b

echo "Creating 16k context variants..."

printf "FROM deepseek-r1:14b\nPARAMETER num_ctx 16384\n" > /tmp/Mf_deepseek
ollama create deepseek-r1:14b-16k -f /tmp/Mf_deepseek

printf "FROM qwen2.5-coder:14b\nPARAMETER num_ctx 16384\n" > /tmp/Mf_qwen
ollama create qwen2.5-coder:14b-16k -f /tmp/Mf_qwen

echo "Ollama init complete."
