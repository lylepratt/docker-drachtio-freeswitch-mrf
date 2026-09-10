# GPT-Live production module checks

Run `node --test tests/gptlive-production-protocol.test.cjs` with Node.js, a C++17 compiler, tar, and patch installed.

The checks extract the exact packaged source and apply the same ABI and production patches as the image installer. They verify the wire protocol packaging and compile/run the output-activity detector against silence, noise, speech onset, quiet pauses, and underruns. This does not replace a module build or real communication-harness calls.

## Production module contract

The original tarball contains alpha documentation. The applied production patch supersedes it:

- Connect to `api.openai.com/v1/live/sessions` using the existing bearer authentication command. No alpha header or browser Origin is sent.
- Backend sends `session.start` with model `gpt-live-1` and `audio.format: {type: "audio/pcm", rate: 24000}`. Caller audio remains gated until `session.started`.
- Module sends `session.input_audio.append.audio` and plays `session.output_audio.delta.delta`. PCM16 mono 24 kHz transport and existing resampling stay unchanged.
- All non-audio server events are forwarded unchanged. Backend handles transcript deltas, the nested `response.event`, tools, and usage.
- Local `output_audio.playback_started` and `output_audio.playback_stopped` events now describe audible output activity, not queue occupancy. Production streams silent PCM between speech bursts. The detector uses peak amplitude above 100 and 200 ms of quiet, based on measured output. It observes samples before mixing and never changes or suppresses audio.
- These events do not prove that a semantic response is finished and do not command a hangup. Backend retains its quiet-period safeguard.
- Obsolete alpha `turn.created` projections no longer clear the playback queue. GPT-Live manages listening and speaking continuously. Transcript fragments are not used as interruption events.

Official protocol: https://developers.openai.com/api/docs/guides/voice-websockets?api=live
