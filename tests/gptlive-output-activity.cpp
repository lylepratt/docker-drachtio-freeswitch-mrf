#include <cassert>
#include <cstdint>
#include "output_activity.hpp"

int main() {
  gptlive_s2s::OutputActivity activity;
  int16_t silence[160] = {};
  int16_t speech[160] = {};
  int16_t noise[160] = {};
  noise[0] = 46;
  noise[1] = -46;
  assert(activity.update(noise, 160, 8000) == 0);
  noise[0] = 100;
  noise[1] = -100;
  assert(activity.update(noise, 160, 8000) == 0);
  noise[0] = 111;
  assert(activity.update(noise, 160, 8000) == 1);
  assert(noise[0] == 111); // Observation never modifies the playback buffer.
  assert(activity.update(nullptr, 1600, 8000) == -1);
  speech[0] = 1000;
  // Continuous silent output must not look like speech, however long it runs.
  for (int i = 0; i < 1000; ++i) assert(activity.update(silence, 160, 8000) == 0);
  assert(activity.update(speech, 160, 8000) == 1);
  assert(activity.update(speech, 160, 8000) == 0);
  // Short quiet gaps inside speech must not produce playback transitions.
  for (int i = 0; i < 5; ++i) assert(activity.update(silence, 160, 8000) == 0);
  assert(activity.update(speech, 160, 8000) == 0);
  for (int i = 0; i < 9; ++i) assert(activity.update(silence, 160, 8000) == 0);
  assert(activity.update(silence, 160, 8000) == -1);
  assert(activity.update(silence, 160, 8000) == 0);
  assert(activity.update(speech, 160, 8000) == 1);
  // Queue underruns count as quiet without touching the playout samples.
  assert(activity.update(nullptr, 1600, 8000) == -1);
  // Full negative PCM range must not overflow the amplitude check.
  speech[0] = INT16_MIN;
  assert(activity.update(speech, 160, 8000) == 1);
  assert(activity.update(nullptr, 4800, 24000) == -1);
  assert(activity.update(speech, 0, 8000) == 0);
  assert(activity.update(speech, 160, 0) == 0);
}
