#!/bin/bash

FILE=$1

if [ ! -f "$FILE" ]; then
  echo "❌ Instruction file not found"
  exit 1
fi

echo "🚀 Executing instructions from $FILE"

CURRENT_COMMAND=""
CURRENT_FILE=""
BUFFER=""

while IFS= read -r line || [ -n "$line" ]; do

  # Ignore comments
  [[ "$line" =~ ^#.*$ ]] && continue

  # =========================
  # COMMAND PARSING
  # =========================

  if [[ "$line" == MKDIR* ]]; then
    DIR=$(echo $line | cut -d' ' -f2)
    mkdir -p "$DIR"
    echo "📁 Created directory: $DIR"

  elif [[ "$line" == CREATE* ]]; then
    FILEPATH=$(echo $line | cut -d' ' -f2)
    mkdir -p "$(dirname "$FILEPATH")"
    touch "$FILEPATH"
    echo "📄 Created file: $FILEPATH"

  elif [[ "$line" == DELETE* ]]; then
    FILEPATH=$(echo $line | cut -d' ' -f2)
    rm -f "$FILEPATH"
    echo "🗑 Deleted file: $FILEPATH"

  elif [[ "$line" == RMDIR* ]]; then
    DIR=$(echo $line | cut -d' ' -f2)
    rm -rf "$DIR"
    echo "🗑 Deleted directory: $DIR"

  elif [[ "$line" == WRITE* ]]; then
    CURRENT_COMMAND="WRITE"
    CURRENT_FILE=$(echo $line | cut -d' ' -f2)
    BUFFER=""

  elif [[ "$line" == APPEND* ]]; then
    CURRENT_COMMAND="APPEND"
    CURRENT_FILE=$(echo $line | cut -d' ' -f2)
    BUFFER=""

  elif [[ "$line" == REPLACE* ]]; then
    FILEPATH=$(echo $line | cut -d' ' -f2)
    OLD=$(echo $line | cut -d' ' -f3)
    NEW=$(echo $line | cut -d' ' -f4)

    sed -i '' "s/$OLD/$NEW/g" "$FILEPATH" 2>/dev/null || sed -i "s/$OLD/$NEW/g" "$FILEPATH"
    echo "🔁 Replaced in $FILEPATH: $OLD → $NEW"

  elif [[ "$line" == EXEC* ]]; then
    CMD=$(echo $line | cut -d' ' -f2-)
    echo "⚡ Running: $CMD"
    eval "$CMD"
  
  elif [[ "$line" == JSONINSERT* ]]; then
    # Format: JSONINSERT file key value
    FILE=$(echo $line | cut -d' ' -f2)
    KEY=$(echo $line | cut -d' ' -f3)
    VALUE=$(echo $line | cut -d' ' -f4-)
    
    jq --arg val "$VALUE" ".scripts.$KEY=\$val" "$FILE" > tmp.json && mv tmp.json "$FILE"
    echo "🔧 Inserted $KEY in $FILE"
  
  elif [[ "$line" == END ]]; then
    if [ "$CURRENT_COMMAND" == "WRITE" ]; then
      echo "$BUFFER" > "$CURRENT_FILE"
      echo "✍️ Wrote file: $CURRENT_FILE"

    elif [ "$CURRENT_COMMAND" == "APPEND" ]; then
      echo "$BUFFER" >> "$CURRENT_FILE"
      echo "➕ Appended file: $CURRENT_FILE"
    fi

    CURRENT_COMMAND=""
    CURRENT_FILE=""
    BUFFER=""

  else
    # Capture multiline content
    if [ ! -z "$CURRENT_COMMAND" ]; then
      BUFFER+="$line"$'\n'
    fi
  fi

done < "$FILE"

echo "✅ Done executing instructions!"