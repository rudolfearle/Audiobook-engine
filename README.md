# 📚 audiobook-engine

Convert `.epub` files into MP3 audiobooks using local, offline text-to-speech. No cloud services, no API keys — everything runs on your machine.

Built around [Piper TTS](https://github.com/rhasspy/piper) and `ffmpeg`, with automatic chapter detection and per-chapter progress logging.


---

## Features

- Converts any `.epub` to a full-length MP3 audiobook
- Automatic chapter detection (falls back to size-based splitting)
- Per-part progress output so you always know it's working
- Chapters saved individually as WAVs during processing — listen while it renders
- Full run log saved to `~/audiobook-engine/logs/`
- Offline and private — nothing leaves your machine

---

## Requirements

| Tool | Purpose |
|------|---------|
| `piper` | Local neural text-to-speech engine |
| `ebook-convert` (Calibre) | Converts EPUB to plain text |
| `ffmpeg` | Concatenates WAV parts and encodes final MP3 |
| `bash` | Script runtime (bash 4+) |

---

## Installation

### 1. Install Calibre

Calibre provides the `ebook-convert` command.

**Fedora / Nobara:**
```bash
sudo dnf install calibre
```

**Ubuntu / Debian:**
```bash
sudo apt install calibre
```

**Or download directly:** https://calibre-ebook.com/download

Verify it works:
```bash
ebook-convert --version
```

---

### 2. Install ffmpeg

**Fedora / Nobara:**
```bash
sudo dnf install ffmpeg
```

**Ubuntu / Debian:**
```bash
sudo apt install ffmpeg
```

Verify:
```bash
ffmpeg -version
```

---

### 3. Install Piper TTS

Piper is a fast, local neural TTS engine.

```bash
# Create a directory for piper
mkdir -p ~/.local/bin
mkdir -p ~/piper

# Download the latest release for your platform from:
# https://github.com/rhasspy/piper/releases

# Example for Linux x86_64:
wget https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz
tar -xzf piper_linux_x86_64.tar.gz -C ~/piper

# Symlink the binary to your PATH
ln -s ~/piper/piper ~/.local/bin/piper

# Make sure ~/.local/bin is in your PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify:
```bash
piper --version
```

---

### 4. Download a Piper Voice Model

Piper needs a voice model (`.onnx` file) to generate speech.

```bash
# The script defaults to en_US-lessac-medium
# Download it from the Piper voices repo:
wget -P ~/piper \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx

wget -P ~/piper \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

Browse all available voices at: https://huggingface.co/rhasspy/piper-voices

---

### 5. Set Up the Script

```bash
# Clone or download this repo
git clone https://github.com/YOUR_USERNAME/audiobook-engine.git
cd audiobook-engine

# Make the script executable
chmod +x v5.sh

# Create the working directories
mkdir -p ~/audiobook-engine/{work,out,logs}
```

---

## Configuration

Open `v5.sh` and check these two lines at the top match your setup:

```bash
PIPER="/home/YOUR_USERNAME/.local/bin/piper"
MODEL="/home/YOUR_USERNAME/piper/en_US-lessac-medium.onnx"
```

Replace `YOUR_USERNAME` with your actual Linux username, or use `$HOME`:

```bash
PIPER="$HOME/.local/bin/piper"
MODEL="$HOME/piper/en_US-lessac-medium.onnx"
```

---

## Usage

```bash
./v5.sh "/path/to/your/book.epub"
```

### Example

```bash
./v5.sh "/media/books/Arthur C. Clarke/2061.epub"
```

Output will be saved to:
```
~/audiobook-engine/out/2061/2061.mp3
~/audiobook-engine/out/2061/chapter_001.wav
~/audiobook-engine/out/2061/chapter_002.wav
...
```

Log file:
```
~/audiobook-engine/logs/2061.log
```

To watch progress live in another terminal:
```bash
tail -f ~/audiobook-engine/logs/*.log
```

---

## How It Works

1. **EPUB → TXT** — Calibre's `ebook-convert` strips formatting and outputs plain text
2. **Chapter detection** — `grep` scans for headings like `Chapter`, `CHAPTER`, `Part`, or numeric patterns; falls back to 8KB size-based chunks if none are found
3. **TTS rendering** — Each chunk is split into 60-line sentence batches and fed to Piper, producing individual WAV files
4. **Concatenation** — `ffmpeg` joins the WAV parts per chapter, then merges all chapters into a final MP3

---

## Troubleshooting

**"No chapter headings found" — book treated as one giant chunk**
This is normal for some EPUBs. The script falls back to size-based splitting automatically. The audio will still be complete, just not split by chapter.

**Script appears to hang on a large chapter**
It's working — Piper processes text sequentially and a large chapter can take several minutes. Check the log for part-by-part progress:
```bash
tail -f ~/audiobook-engine/logs/*.log
```

**`ebook-convert` produces empty output**
Some DRM-protected EPUBs cannot be converted. Make sure your EPUB is DRM-free.

**`piper: command not found`**
Make sure `~/.local/bin` is in your `$PATH` and you've restarted your terminal or run `source ~/.bashrc`.

---

## Tested On

- Nobara Linux (Fedora-based)
- ffmpeg 7.x
- Piper 2023.11.14
- Calibre 7.x

---

## License

MIT — do whatever you want with it.
