#!/bin/sh

# 1. Configuration du nom de sortie
printf "Nom de la vidéo (par défaut 'video.mp4') : "
read input_name
if [ -z "$input_name" ]; then
    OUTPUT="video.mp4"
else
    # On ajoute .mp4 si l'utilisateur l'a oublié
    case "$input_name" in
        *.mp4) OUTPUT="$input_name" ;;
        *)     OUTPUT="$input_name.mp4" ;;
    esac
fi

TEMP_LIST="list_clips.txt"
DUR=3
printf "" > "$TEMP_LIST"

# 2. Découverte et choix du fichier audio
echo "Recherche de fichiers audio..."
i=1
AUDIO_FILES=$(ls *.mp3 2>/dev/null)

if [ -z "$AUDIO_FILES" ]; then
    echo "Aucun fichier .mp3 trouvé dans le dossier."
    AUDIO_INPUT=""
else
    echo "Choisissez la musique (tapez le numéro ou Entrée pour aucune) :"
    for f in $AUDIO_FILES; do
        echo "$i) $f"
        i=$((i + 1))
    done

    printf "Votre choix : "
    read choix

    if [ -n "$choix" ]; then
        AUDIO_INPUT=$(echo "$AUDIO_FILES" | sed -n "${choix}p")
    fi
fi

if [ -n "$AUDIO_INPUT" ]; then
    echo "Musique sélectionnée : $AUDIO_INPUT"
else
    echo "Aucune musique sélectionnée."
fi

# 3. Création de clips individuels (respect total de la taille d'origine)
images=$(ls tmm* 2>/dev/null | sort -V)

for f in $images; do
    if ffmpeg -v error -i "$f" -f null - 2>/dev/null; then
        echo "Traitement de $f..."
        # On force l'arrondi à 2px (parité obligatoire) sans changer la taille réelle
        ffmpeg -y -loop 1 -i "$f" -t "$DUR" \
            -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2:(ow-iw)/2:(oh-ih)/2:black,format=yuv420p" \
            -c:v libx264 -pix_fmt yuv420p -r 25 "part_$f.ts"
        
        echo "file 'part_$f.ts'" >> "$TEMP_LIST"
    fi
done

# 4. Assemblage final
if [ -s "$TEMP_LIST" ]; then
    echo "Fusion finale vers $OUTPUT..."
    if [ -n "$AUDIO_INPUT" ] && [ -f "$AUDIO_INPUT" ]; then
        ffmpeg -y -f concat -safe 0 -i "$TEMP_LIST" -i "$AUDIO_INPUT" \
            -c copy -c:a aac -shortest "$OUTPUT"
    else
        ffmpeg -y -f concat -safe 0 -i "$TEMP_LIST" -c copy "$OUTPUT"
    fi
else
    echo "Erreur : Aucun fichier valide n'a été traité."
    exit 1
fi

# 5. Nettoyage et rapport
rm -f part_tmm* "$TEMP_LIST"
echo "------------------------------"
echo "Fichiers images utilisés :"
echo "$images"
echo "------------------------------"
if [ -n "$AUDIO_INPUT" ]; then
    echo "Audio utilisé : $AUDIO_INPUT"
fi
echo "Vidéo générée : $OUTPUT"
echo "vidéo terminée"
