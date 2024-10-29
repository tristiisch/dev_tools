#!/bin/sh
set -eu

if [ $# -ne 2 ]; then
    echo "Usage: $0 <commit_id> <name_mep>"
    exit 1
fi

# Check if zip is installed
if ! command -v zip > /dev/null; then
	echo "zip is not installed. Please install it to proceed."
	exit 1
fi

commit_id=$1
name_mep=$2

project_name=$(basename "$PWD")
temp_dir="/tmp/mep/$name_mep/$project_name"
full_name_mep="$project_name-$name_mep"

mkdir -p "$temp_dir"
echo "Folder created: $temp_dir"

# Check if the commit ID is valid
if ! git rev-parse --quiet --verify "$commit_id" > /dev/null; then
    echo "Invalid commit ID: $commit_id"
    exit 1
fi

# Create a temporary file for storing ignored files
tmp_file=$(mktemp)
sed -e '/^#/d' -e '/^$/d' -e 's/\!//g' .dockerignore > "$tmp_file"
echo ".dockerignore" >> "$tmp_file"

# Get the list of new files
new_files=$(git log --name-only --diff-filter=A --pretty=format: $commit_id..HEAD | awk 'NF' | grep -v -f "$tmp_file" || true)
# echo "DEBUG new_files $new_files"

# Get the list of modified files
modified_files=$(git log --name-only --diff-filter=M --pretty=format: $commit_id..HEAD | awk 'NF' | grep -v -f "$tmp_file" || true)
# echo "DEBUG modified_files $modified_files"

# Get the list of deleted files
deleted_files=$(git log --name-only --diff-filter=D --pretty=format: $commit_id..HEAD | awk 'NF' | grep -v -f "$tmp_file" || true)
# echo "DEBUG deleted_files $deleted_files"

# Get the list of renamed files
renamed_files=$(git log --name-status --diff-filter=R --pretty=format: $commit_id..HEAD | awk 'NF' | grep -v -f "$tmp_file" || true)
echo "$renamed_files" > $tmp_file
# echo "DEBUG renamed_files $renamed_files"

old_paths=""
new_paths=""
while IFS= read -r line; do
    old=$(echo "$line" | awk '{print $2}')
    new=$(echo "$line" | awk '{print $3}')

    # Append values to respective variables
    old_paths="$old_paths\n$old"
    new_paths="$new_paths\n$new"
done < "$tmp_file"
# echo "DEBUG old_paths $old_paths"
# echo "DEBUG new_paths $new_paths"
deleted_files=$(echo "$deleted_files\n$old_paths" | awk 'NF')
new_files=$(echo "$new_files\n$new_paths" | awk 'NF')

# Clean up temporary files
rm "$tmp_file"

# Generate instructions for deleting non-existing files
file_to_delete_instruction=""
if [ "$deleted_files" != "" ]; then
    file_to_delete=$(echo "$deleted_files" | xargs)
    file_to_delete_instruction="\n\n# Supprimez les fichiers qui ne sont plus utilisés :
rm $file_to_delete"
fi

# Generate instructions for removing new files in the event of using backups
file_to_delete_new_instruction=""
if [ "$new_files" != "" ]; then
    file_to_delete=$(echo "$new_files" | xargs)
    file_to_delete_new_instruction="\n\n# Supprimez les fichiers qui ont été créés par la MEP :
rm $file_to_delete"
fi

read -rp "Do we need to modify the configuration file? [y/N] " response
case "${response}" in
  [yY]|[yY][eE][sS]) edit_config="1" ;;
  *) edit_config="0" ;;
esac

config_instruction=""
if [ "$edit_config" = "1" ]; then
    config_instruction="\n\n# Editez le fichier de configuration :
vi application/configs/application.ini
# Aller aux lignes dédié l'environnement de production, c'est à dire après \"[production : ********]\"

# Editez les lignes suivantes :
assets.css.version = "1.0"
assets.js.version = "1.0"
# 1.0 étant un exemple, ce sera une valeur supérieur
# Incrémentez la partie décimale (après la virgule)

# Ajoutez les lignes suivantes :
****
****

# Sauvegardez."
fi

# Get commit messages
commit_messages=$(git log --pretty=format:"- %s" "$commit_id...HEAD")
echo "Commit messages between HEAD and $commit_id:"
echo "$commit_messages\n"

# Display the list of changed files
changes=$(
{
    if [ "$deleted_files" != "" ]; then
        echo "$deleted_files" | sed 's/^/D /'
    fi
    if [ "$modified_files" != "" ]; then
        echo "$modified_files" | sed 's/^/M /'
    fi
    if [ "$new_files" != "" ]; then
        echo "$new_files" | sed 's/^/A /'
    fi
})
echo "Files changed between HEAD and $commit_id :"
echo "$changes"

EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)

# Write the list of backup files
files_backup="$full_name_mep.files_to_backup.txt"
{
    if [ "$deleted_files" != "" ]; then
        echo "$deleted_files"
    fi
    if [ "$modified_files" != "" ]; then
        echo "$modified_files"
    fi
    if [ "$edit_config" = "1" ]; then
        echo "application/configs/application.ini"
    fi
} > "$temp_dir/$files_backup"

# New Files
# --ignore-failed-read
archive_with_update="$full_name_mep.files.tar.gz"
{
    echo "$new_files"
    echo "$modified_files"
} | tar cfz "$temp_dir/$archive_with_update" -T -

zip_name="$full_name_mep.zip"
echo "\nCreate final ZIP ..."
zip -FS -j "$temp_dir/$zip_name" "$temp_dir/$archive_with_update" "$temp_dir/$files_backup"

# Write the instructions to a file
instruction_file="$temp_dir/$full_name_mep.instruction.md"
echo "### Explications tâches MEP :
# - Vous trouverez une archive ZIP par site CORPO en pièce jointe du CR.
# - Chaque archive ZIP contient :
#     - Une liste des fichiers à sauvegarder (chemin des fichiers supprimés ou modifiés).
#     - Une archive TAR.GZ qui contient les fichiers de la mise à jour.
#       Chaque fichier est placé à son chemin relatif par rapport à la racine du projet.
#       En d'autres termes, la décompression placera les fichiers à leur bon emplacement directement,
#       en remplaçant les fichiers s'ils existent déjà.
# - En suivant la procédure, vous allez créer une archive ***.revert_files.tar.gz.
#   Elle nous servira en cas d'annulation de la MEP pour revenir à l'état d'origine.

### Résumé des changements
$changes

### Tâche de la MEP - $full_name_mep

# Téléchargez l'archive ZIP depuis les pièces jointes du CR.
# Elle s'appelle $zip_name

# Décompressez l'archive sur votre poste.

# Téléversez ces fichiers sur le serveur à la racine de l'application :
# - $archive_with_update
# - $files_backup
​​​​​​​cd /var/www/autosecurite.com/autosecurite.git
cd /var/www/securitest.fr/securitest.git
cd /var/www/verifautos.fr/verifautos.git


# Sauvegardez les fichiers qui vont être modifiés :
tar cvfz \"$full_name_mep.revert_files.tar.gz\" -T \"$files_backup\"$config_instruction

# Remplacez les fichiers :
tar xzvf \"$archive_with_update\"$file_to_delete_instruction


### Revert MEP - $full_name_mep

# Revenez en arrière en utilisant la sauvegarde en cas de problèmes :
tar xzvf \"$full_name_mep.revert_files.tar.gz\"$file_to_delete_new_instruction" > "$instruction_file"

echo "\nInstructions generated: $instruction_file"
