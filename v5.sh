#!/bin/bash
set -euo pipefail

INPUT="$1"
BASE="$(basename "$INPUT" | sed 's/\.[^.]*$//')"
WORK="$HOME/audiobook-engine/work/$BASE"
OUT="$HOME/audiobook-engine/out/$BASE"
LOG="$HOME/audiobook-engine/logs/$BASE.log"

PIPER="/home/murloc/.local/bin/piper"
MODEL="/home/murloc/piper/en_US-lessac-medium.onnx"

rm -rf "$WORK"
mkdir -p "$WORK"/{chapters,audio}
mkdir -p "$OUT"
mkdir -p "$HOME/audiobook-engine/logs"

exec > >(tee -a "$LOG") 2>&1
echo "📚 V6 Processing: $INPUT — $(date)"

########################################
# 1. EPUB → TEXT
########################################
ebook-convert "$INPUT" "$WORK/book.txt"

if [ ! -s "$WORK/book.txt" ]; then
  echo "❌ Empty book.txt — aborting"
  exit 1
fi

echo "✅ book.txt: $(wc -c < "$WORK/book.txt") bytes, $(wc -l < "$WORK/book.txt") lines"

########################################
# 2. CHAPTER DETECTION
# Use grep+awk to split — avoids csplit regex portability issues
########################################

echo "🔍 Scanning for chapter headings..."

# Find line numbers of chapter headings
grep -n "^\(Chapter\|CHAPTER\|Part\|PART\) " "$WORK/book.txt" | cut -d: -f1 > "$WORK/chapter_lines.txt" || true

# Also catch numeric headings like "1." or "I." at line start
grep -n "^[0-9IVX]\{1,5\}\. " "$WORK/book.txt" | cut -d: -f1 >> "$WORK/chapter_lines.txt" || true

# Deduplicate and sort
sort -nu "$WORK/chapter_lines.txt" -o "$WORK/chapter_lines.txt"

# Count how many we found — use tr to strip any whitespace/newlines
COUNT=$(wc -l < "$WORK/chapter_lines.txt" | tr -d ' \n')
echo "📖 Chapter headings found: $COUNT"

TOTAL_LINES=$(wc -l < "$WORK/book.txt" | tr -d ' \n')

if [ "$COUNT" -gt 1 ]; then
  echo "✂ Splitting by chapter headings..."

  PREV=1
  IDX=0
  while IFS= read -r line_num; do
    if [ "$line_num" -gt "$PREV" ]; then
      IDX=$((IDX + 1))
      sed -n "${PREV},$((line_num - 1))p" "$WORK/book.txt" \
        > "$WORK/chapters/$(printf "%03d" $IDX).txt"
    fi
    PREV=$line_num
  done < "$WORK/chapter_lines.txt"

  # Last chunk to end of file
  IDX=$((IDX + 1))
  sed -n "${PREV},${TOTAL_LINES}p" "$WORK/book.txt" \
    > "$WORK/chapters/$(printf "%03d" $IDX).txt"

else
  echo "⚠ No chapter headings found — using 8000-byte size split"
  split -C 8000 "$WORK/book.txt" "$WORK/chapters/"
fi

CHAP_COUNT=$(ls "$WORK/chapters/" | wc -l | tr -d ' \n')
echo "📄 Total chunks to process: $CHAP_COUNT"

########################################
# 3. PROCESS EACH CHAPTER/CHUNK → WAV
########################################
INDEX=0

for chap in "$WORK/chapters/"*; do
  [ -s "$chap" ] || continue
  INDEX=$((INDEX + 1))
  CHAP_NAME="chapter_$(printf "%03d" $INDEX)"
  CH_AUDIO="$WORK/audio/${CHAP_NAME}.wav"

  echo ""
  echo "🎧 [$INDEX/$CHAP_COUNT] $(basename "$chap") → ${CHAP_NAME}.wav ($(wc -c < "$chap") bytes)"

  # Normalize: collapse lines into space-separated sentences
  tr '\n' ' ' < "$chap" | sed 's/\. /.\n/g' > "$WORK/tmp_sent.txt"

  SENT_COUNT=$(wc -l < "$WORK/tmp_sent.txt" | tr -d ' \n')
  echo "   Sentences: $SENT_COUNT"

  rm -f "$WORK/tmp_part_"* "$WORK/list.txt"
  split -l 60 "$WORK/tmp_sent.txt" "$WORK/tmp_part_"

  PART_TOTAL=$(ls "$WORK/tmp_part_"* 2>/dev/null | wc -l | tr -d ' \n')
  PART_NUM=0

  for part in "$WORK/tmp_part_"*; do
    [ -s "$part" ] || continue
    PART_NUM=$((PART_NUM + 1))
    WAV_OUT="${part}.wav"
    echo "   🔊 Part $PART_NUM/$PART_TOTAL"

    "$PIPER" \
      --model "$MODEL" \
      --output_file "$WAV_OUT" < "$part"

    echo "file '$WAV_OUT'" >> "$WORK/list.txt"
  done

  echo "   🔗 Concatenating → $CH_AUDIO"
  ffmpeg -y -f concat -safe 0 -i "$WORK/list.txt" -c copy "$CH_AUDIO" 2>/dev/null

  cp "$CH_AUDIO" "$OUT/${CHAP_NAME}.wav"
  echo "   ✅ Done: $OUT/${CHAP_NAME}.wav"

  rm -f "$WORK/tmp_part_"* "$WORK/tmp_sent.txt" "$WORK/list.txt"
done

########################################
# 4. MERGE ALL CHAPTER WAVS → MP3
########################################
echo ""
echo "🎬 Merging all chapters to MP3..."

FINAL_LIST="$WORK/final.txt"
rm -f "$FINAL_LIST"

for f in "$OUT"/*.wav; do
  [ -f "$f" ] || continue
  echo "file '$f'" >> "$FINAL_LIST"
done

if [ ! -f "$FINAL_LIST" ]; then
  echo "❌ No WAV files found in $OUT — nothing to merge"
  exit 1
fi

ffmpeg -y -f concat -safe 0 -i "$FINAL_LIST" \
  -codec:a libmp3lame -qscale:a 2 \
  "$OUT/$BASE.mp3"

echo ""
echo "✅ DONE: $OUT/$BASE.mp3 — $(date)"
