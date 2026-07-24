"""Server-side speech transcription for languages the browser's Web Speech
API can't handle reliably (notably Malay / ms-MY).

The frontend records a short audio clip with MediaRecorder (WebM/Opus) and
POSTs it here; we transcribe it with a local faster-whisper model and compare
the result to the target word. Whisper's multilingual model covers Malay well,
so this works regardless of the user's browser.
"""

import difflib
import os
import re
import tempfile
import threading

from flask import Blueprint, jsonify, request

bp = Blueprint("speech", __name__)

# ---------------------------------------------------------------------------
# Model (lazy singleton)
# ---------------------------------------------------------------------------
# The Whisper model is a few hundred MB and takes several seconds to load, and
# most sessions never touch speech practice — so we defer loading to the first
# transcription request instead of paying that cost at every backend boot.
_model = None
_model_lock = threading.Lock()
_MODEL_SIZE = os.environ.get("WHISPER_MODEL", "small")

# Frontend language code -> Whisper language code.
_LANG_MAP = {"en": "en", "ms": "ms", "zh": "zh"}

_PUNCT_RE = re.compile(r"[。！？，、,.!?~～]+")
_WS_RE = re.compile(r"\s+")


def _get_model():
    """Load (once) and return the shared WhisperModel. Raises RuntimeError with
    a clear message if faster-whisper isn't installed yet."""
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                try:
                    from faster_whisper import WhisperModel
                except ImportError as e:
                    raise RuntimeError(
                        "faster-whisper is not installed. Run "
                        "`pip install faster-whisper` in the backend venv."
                    ) from e
                # int8 keeps it fast and light on CPU; first run downloads the
                # model weights from HuggingFace (needs internet once, cached
                # afterwards).
                _model = WhisperModel(
                    _MODEL_SIZE, device="cpu", compute_type="int8"
                )
    return _model


def warm_model():
    """Preload the Whisper model so the first real transcription request doesn't
    pay the ~3s load cost mid-request. Called once at server startup. Safe to
    fail (e.g. faster-whisper not installed) — the route still loads lazily."""
    try:
        _get_model()
        print(f"Whisper model '{_MODEL_SIZE}' warmed and ready.")
    except Exception as e:  # noqa: BLE001
        print(f"Whisper warm-up skipped: {e}")


def _normalize(s):
    """Mirror the frontend's normalisation: lowercase, strip punctuation
    (incl. CJK full-width marks Whisper sometimes appends), collapse spaces."""
    s = _PUNCT_RE.sub("", (s or "").lower())
    return _WS_RE.sub(" ", s).strip()


def _is_match(transcript, target):
    t, w = _normalize(transcript), _normalize(target)
    if not t or not w:
        return False
    if t == w:
        return True
    # Whisper often wraps a single word in a short phrase ("Ini bola.") — accept
    # when the target appears as a whole token, or the two are close overall.
    if w in t.split():
        return True
    return difflib.SequenceMatcher(None, t, w).ratio() >= 0.8


def _transcribe(audio_path, lang):
    model = _get_model()
    segments, _info = model.transcribe(
        audio_path,
        language=_LANG_MAP.get(lang, "en"),
        beam_size=1,
        vad_filter=True,
    )
    return " ".join(seg.text for seg in segments).strip()


@bp.post("/speech/transcribe")
def transcribe():
    audio = request.files.get("audio")
    if audio is None:
        return jsonify({"status": "error", "message": "audio file required"}), 400

    lang = request.form.get("lang", "en")
    target = request.form.get("target", "")

    # Persist to a temp file so PyAV can demux/seek the WebM container.
    fd, tmp_path = tempfile.mkstemp(suffix=".webm")
    os.close(fd)
    audio.save(tmp_path)

    try:
        # NOTE: we deliberately do NOT offload this to eventlet.tpool. ctranslate2
        # (faster-whisper's backend) spawns its own native threads, and handing
        # the call to tpool under eventlet's monkey-patched threading triggers
        # "greenlet.error: Cannot switch to a different thread", which hangs the
        # request forever (the "stuck transcribing" bug). Calling it directly
        # works reliably; it blocks this eventlet worker for ~3s per clip, which
        # is acceptable for solo speech practice.
        transcript = _transcribe(tmp_path, lang)
    except RuntimeError as e:
        return jsonify({"status": "error", "message": str(e)}), 503
    except Exception as e:  # noqa: BLE001 — surface decode/model errors to client
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        try:
            os.remove(tmp_path)
        except OSError:
            pass

    return jsonify({"transcript": transcript, "correct": _is_match(transcript, target)})
