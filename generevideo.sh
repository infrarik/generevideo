#!/bin/sh

# 1. Configuration du nom de sortie
printf "Nom de la vidéo (par défaut 'video.mp4') : "
read input_name
if [ -z "$input_name" ]; then
    OUTPUT="video.mp4"
else
    case "$input_name" in
        *.mp4) OUTPUT="$input_name" ;;
        *)     OUTPUT="$input_name.mp4" ;;
    esac
fi

TEMP_LIST="list_clips.txt"
DUR=3
printf "" > "$TEMP_LIST"

# 2. Recherche et choix du fichier audio
echo "Recherche de fichiers audio..."
i=1
# Utilisation de find pour mieux gérer les noms de fichiers complexes
AUDIO_FILES=$(find . -maxdepth 1 -iname "*.mp3" -printf "%f\n")

if [ -z "$AUDIO_FILES" ]; then
    echo "Aucun fichier .mp3 trouvé."
    AUDIO_INPUT=""
else
    echo "Choisissez la musique (tapez le numéro ou Entrée pour aucune) :"
    IFS=$'\n'
    for f in $AUDIO_FILES; do
        echo "$i) $f"
        i=$((i + 1))
    done

    printf "Votre choix : "
    read choix

    if [ -n "$choix" ]; then
        AUDIO_INPUT=$(echo "$AUDIO_FILES" | sed -n "${choix}p")
    fi
    unset IFS
fi

# 3. Découverte des images et création du fichier de liste
# On scanne les formats demandés
IMAGES=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -printf "%f\n" | sort -V)

if [ -z "$IMAGES" ]; then
    echo "Erreur : Aucune image trouvée."
    exit 1
fi

echo "Génération de la liste des clips..."
IFS=$'\n'
for f in $IMAGES; do
    # On échappe les apostrophes simples dans les noms de fichiers pour FFmpeg
    # On écrit le nom de fichier entre guillemets simples
    CLEAN_NAME=$(echo "$f" | sed "s/'/'\\\\''/g")
    echo "file '$CLEAN_NAME'" >> "$TEMP_LIST"
    echo "duration $DUR" >> "$TEMP_LIST"
done

# Répéter la dernière image (indispensable pour le format concat)
LAST_IMAGE=$(echo "$IMAGES" | tail -n 1 | sed "s/'/'\\\\''/g")
if [ -n "$LAST_IMAGE" ]; then
    echo "file '$LAST_IMAGE'" >> "$TEMP_LIST"
fi
unset IFS

# 4. Assemblage final
echo "Fusion finale vers $OUTPUT..."

# Filtre pour forcer le 1080p et éviter les erreurs de taille
FILTER="scale=w=1920:h=1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p"

if [ -n "$AUDIO_INPUT" ] && [ -f "$AUDIO_INPUT" ]; then
    ffmpeg -y -f concat -safe 0 -i "$TEMP_LIST" -i "$AUDIO_INPUT" \
        -vf "$FILTER" \
        -c:v libx264 -pix_fmt yuv420p -r 25 -c:a aac -shortest "$OUTPUT"
else
    ffmpeg -y -f concat -safe 0 -i "$TEMP_LIST" \
        -vf "$FILTER" \
        -c:v libx264 -pix_fmt yuv420p -r 25 "$OUTPUT"
fi

# 5. Vérification et Nettoyage
if [ -f "$OUTPUT" ]; then
    echo "------------------------------"
    echo "Succès ! Vidéo générée : $OUTPUT"
    rm -f "$TEMP_LIST"
else
    echo "------------------------------"
    echo "ERREUR : FFmpeg n'a pas pu créer le fichier."
    echo "Le fichier $TEMP_LIST a été conservé pour inspection."
fi
