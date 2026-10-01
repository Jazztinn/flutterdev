"""extract playback envelopes from local songs."""
import array
import json
import math
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
tracks = {}
for source in sorted((root / "assets/music").glob("*.mp3")):
    pcm = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(source),
        "-f", "f32le", "-ac", "1", "-ar", "8000", "pipe:1",
    ])
    samples = array.array("f", pcm)
    levels = [
        math.sqrt(sum(x * x for x in samples[i:i + 400]) / len(samples[i:i + 400]))
        for i in range(0, len(samples), 400)
    ]
    peak = max(levels) or 1
    tracks[f"music/{source.name}"] = {
        "stepMs": 50,
        "durationMs": round(len(samples) / 8),
        "levels": [round((level / peak) ** 0.65, 3) for level in levels],
    }
output = root / "assets/music/waveforms.json"
output.write_text(json.dumps(tracks, separators=(",", ":")) + "\n")
print(f"{len(tracks)} tracks; {output.stat().st_size} bytes")
