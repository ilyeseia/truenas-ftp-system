# ========================================
# scripts/batch-download.sh
# ========================================
#!/bin/sh
# Téléchargement en lot depuis une liste

FILE_LIST=${1:-/workspace/download-list.txt}

if [ ! -f "$FILE_LIST" ]; then
    echo "Fichier de liste introuvable: $FILE_LIST"
    echo "Créez un fichier avec un nom de fichier par ligne"
    exit 1
fi

echo "=== Téléchargement en lot ==="
echo "Liste: $FILE_LIST"

while IFS= read -r filename; do
    if [ -n "$filename" ] && [ "${filename#\#}" = "$filename" ]; then
        echo "Téléchargement: $filename"
        /scripts/download-to-truenas.sh "$filename"
        sleep 2
    fi
done < "$FILE_LIST"

echo "Téléchargement en lot terminé!"
