# Transcription Server Design

## Overview

A FastAPI server running on TheBeast (GPU workstation) that accepts audio file uploads
and returns plain text transcripts using whisperx. The primary client is a Raspberry Pi
on the same local network.

## Architecture

```
[Raspberry Pi]  --POST /transcribe-->  [FastAPI on TheBeast:8642]
                                           |
                                    [whisperx large-v2 in GPU VRAM]
                                           |
                <-- JSON response --       |
```

Single FastAPI process. Model loaded lazily on first request and kept in GPU VRAM.

## API

### `POST /transcribe`

**Input:**
- Body: multipart form-data with `file` field (audio file: wav, mp3, m4a, flac, ogg, webm)
- Query params:
  - `language` (optional, str) — `fr`, `en`, etc. Auto-detect if omitted.
  - `diarize` (optional, bool, default `false`) — enable speaker diarization
  - `min_speakers` / `max_speakers` (optional, int, default 2/2) — only used if diarize=true

**Output:**
```json
{"text": "the full transcript...", "language": "fr"}
```

### `GET /health`

Returns `{"status": "ok", "model_loaded": true/false}` for health checks.

## File Structure

```
transcription_server/
├── __init__.py
├── server.py          # FastAPI app, endpoint, model loading
```

Dependencies added to root `pyproject.toml`: fastapi, uvicorn, whisperx, python-multipart.

## WhisperX Parameters

Based on Louis's known-working command:
- Model: `large-v2`
- `compute_type`: `float32`
- `best_of`: 10
- `beam_size`: 10
- `patience`: 2

Diarization (when enabled):
- Requires HuggingFace token (for pyannote)
- `min_speakers` / `max_speakers` configurable per request

## Running

```bash
cd /home/ezalos/Setup
uv run uvicorn transcription_server.server:app --host 0.0.0.0 --port 8642
```

## Client Usage (from Pi)

```bash
# Basic (auto-detect language)
curl -X POST "http://<thebeast-ip>:8642/transcribe" -F "file=@recording.wav"

# Specify language
curl -X POST "http://<thebeast-ip>:8642/transcribe?language=fr" -F "file=@recording.wav"

# With diarization
curl -X POST "http://<thebeast-ip>:8642/transcribe?diarize=true&language=fr" -F "file=@recording.wav"
```

## Decisions

- **Lazy model loading**: Server starts fast; model loads on first /transcribe call.
- **In-process whisperx**: Model stays in VRAM between requests — no reload overhead.
- **Plain text output by default**: Simplest for Pi consumption.
- **Local network only**: Server binds 0.0.0.0, no auth needed on LAN.
