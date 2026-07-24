# Eventlet gives the Socket.IO server real concurrency: every connected student
# becomes a lightweight green thread on one OS thread, instead of one OS thread
# per connection as in the previous `threading` mode (which stalled with only a
# few tabs open). monkey_patch() rewrites the stdlib's socket/threading calls to
# their cooperative equivalents, so it MUST run before anything else imports
# them — keep this block at the very top of the file.
import eventlet
eventlet.monkey_patch()

import state
import vocab

vocab.load_vocab_cache()

import sockets  # noqa: F401 — registers Socket.IO event handlers on state.socketio
from routes import (auth, children, class_code, classroom, health, logs, quiz,
                    report, revision, speech, vocabulary)

app = state.app
socketio = state.socketio

for _bp in (health.bp, vocabulary.bp, auth.bp, children.bp, logs.bp, quiz.bp,
            class_code.bp, classroom.bp, revision.bp, report.bp, speech.bp):
    app.register_blueprint(_bp)


if __name__ == "__main__":
    # Preload the Whisper speech model in the background so the first Malay
    # speech-practice request is fast instead of waiting ~3s for the model to
    # load mid-request.
    socketio.start_background_task(speech.warm_model)
    socketio.run(app, host='0.0.0.0', port=5000)
