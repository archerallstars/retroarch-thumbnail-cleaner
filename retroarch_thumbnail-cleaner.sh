#!/bin/bash

############################
#    RetroArch Specific    #
############################

# RetroArch's main directory recieved from the user
dir="$1"

# Check if the user provided the required directory
if [ -z "$dir" ]; then
    echo "Error: No directory provided."
    echo "Usage: ./retroarch_thumbnail-cleaner.sh <retroarch's main directory>"
    exit 1

else

    # Change to the recieved directory
    cd "$dir" || exit 1

    # Set playlists directory
    playlist_dir="playlists"

    # Set thumbnails directory
    thumbnails_dir="thumbnails"

fi

# Forbiden special characters (RA specific for thumbnail's file naming: https://docs.libretro.com/guides/roms-playlists-thumbnails/#thumbnail-paths-and-filenames )
special_chars='[&*/:<>?\|]'

############################
#          Arrays          #
############################

# An array to store the playlists' lines that contain "label":
label_lines=()

# The same with the above, but in the short version, see: https://docs.libretro.com/guides/roms-playlists-thumbnails/#thumbnail-paths-and-filenames
label_lines_short=()

# An array to store the game ROM's filenames
rom_filenames=()

# An indexed array to store the thumbnails' filenames
declare -a thumbnail_filenames
# An indexed array to store the thumbnails' filenames with their extensions
declare -a thumbnail_filenames_with_ext

# An array to store all unused thumbnails as the indexes of thumbnail_filenames and thumbnail_filenames_with_ext indexed arrays
unused_thumbnails_indexes=()

############################
#         Remover          #
############################

# Function to delete all unused thumbnail files
unused_thumbnails_delete() {

    # Removal confirmation
    # Change the style of the following output to cyan color and bold text
    tput setaf 6 bold
    echo "The following thumbnail files (Boxarts, Snaps, Titles) from '${#unused_thumbnails_indexes[@]}' games will be deleted:"
    # End of the changed style
    tput sgr0

    echo "------------------------------------"

    # Scan the saved the unused thumbnail indexes, then use that to get the elements out of the full thumbnails list (deduplicated one) based on their indexes
    # This only lists the files that will be removed after the confirmation
    for element in "${unused_thumbnails_indexes[@]}"; do
        unsorted_print+=("${deduplicated_thumbnail_filenames_with_ext[$element]}")
    done

    # Print out the removal list
    printf "%s\n" "${unsorted_print[@]}" | sort
    echo "------------------------------------"

    # Bold text style
    tput bold
    read -p 'Are you sure you want to delete these files? (y/n): ' response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    # End bold text style
    tput sgr0

    # Recieve the user response, then act accordingly
    # The answer is yes, proceed
    if [[ "$response" == "y" ]]; then
        for element in "${unused_thumbnails_indexes[@]}"; do
            # Find the unused thumbnails (as listed) in the thumbnails directory, then remove them
            find "$thumbnails_dir" -type f -name "${deduplicated_thumbnail_filenames_with_ext["$element"]}" -print0 | xargs -0 rm -f
        done

    # The answer is no, abort
    elif [[ "$response" == "n" ]]; then
        echo "Canceled. No thumbnail file has been removed."
    fi

}

############################
#          Scaner          #
############################

# Iterate through each .lpl file
for file in "$playlist_dir"/*.lpl; do

    # Read the file line by line
    while IFS= read -r line; do

        # Check if the lines contain "label": (playlists' labels)
        if [[ $line =~ '"label":' ]]; then

            # Extract only the game label from the iterated lines
            game_label=$(echo "$line" | sed 's/"label": //g' | sed 's/^[[:space:]]*//' | sed 's/"//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/,$//' | sed 's/[[:space:]]*$//')

            # Check if the iterated lines contain special characters
            if [[ $game_label =~ $special_chars ]]; then

                # Replace special characters in the game label with _
                modified_game_label="${game_label//$special_chars/_}"

                # Add the processed line to the array
                label_lines+=("$modified_game_label")

            else
                # Add the line to the array
                label_lines+=("$game_label")
            fi

        # Check if the lines contain "path": (game ROM's filenames)
        elif [[ $line =~ '"path":' ]]; then

            # Extract only the ROM's filename from the iterated lines
            rom_name=$(echo "$line" | grep -oP '(?<=/)[^/]+(?=")' | sed 's/\.[^.]*$//')

            # Check if the iterated lines contain special characters
            if [[ $rom_name =~ $special_chars ]]; then

                # Replace special characters in the rom's filename with _
                modified_rom_name="${rom_name//$special_chars/_}"

                # Add the processed line to the array
                rom_filenames+=("$modified_rom_name")

            else
                # Add the line to the array
                rom_filenames+=("$rom_name")
            fi

        fi
    done <"$file"
done

# Loop through each element in array label_lines to create a short version of it in an array label_lines_short (playlists' labels - short version)
for element in "${label_lines[@]}"; do
    # Extract the part before the first round bracket, excluding the last space before the first round bracket (if there's any)
    tmp="${element%%(*)}"
    label_lines_short+=("${tmp%"${tmp##*[![:space:]]}"}")
done

# Find all files in the thumbnails directory and its subdirectories
while IFS= read -r file; do
    # Extract each filename with and without its extension, and save to the corresponding arrays
    thumbnail_filenames_with_ext+=("$(basename "$file")")
    thumbnail_filenames+=("$(basename "$file" | sed 's/\.[^.]*$//')")
done < <(find "$thumbnails_dir" -type f -name "*.*")

# Initialize hash tables for deduplications
declare -A hash1
declare -A hash2
declare -A hash3
declare -A hash4
declare -A hash5

# Deduplicate all arrays (labels - full, labels - short, ROM's filenames, thumbnail's filenames - with and without the extensions)

for element in "${label_lines[@]}"; do
    if [[ ! -v hash1[$element] ]]; then
        hash1[$element]=1
        deduplicated_label_lines+=("$element")
    fi
done

for element in "${label_lines_short[@]}"; do
    if [[ ! -v hash2[$element] ]]; then
        hash2[$element]=1
        deduplicated_label_lines_short+=("$element")
    fi
done

for element in "${rom_filenames[@]}"; do
    if [[ ! -v hash3[$element] ]]; then
        hash3[$element]=1
        deduplicated_rom_filenames+=("$element")
    fi
done

for element in "${thumbnail_filenames_with_ext[@]}"; do
    if [[ ! -v hash4[$element] ]]; then
        hash4[$element]=1
        deduplicated_thumbnail_filenames_with_ext+=("$element")
    fi
done

for element in "${thumbnail_filenames[@]}"; do
    if [[ ! -v hash5[$element] ]]; then
        hash5[$element]=1
        deduplicated_thumbnail_filenames+=("$element")
    fi
done

# Combine labels - full, labels - short, ROM's filenames in a temporary array for the comparison with thumbnail's filenames
temp_array=("${deduplicated_label_lines[@]}")
temp_array+=("${deduplicated_label_lines_short[@]}")
temp_array+=("${deduplicated_rom_filenames[@]}")

# Comparing all the playlist types with the available thumbnails
# Only the indexes of unused thumbnails from thumbnail_filenames are saved
for i in "${!deduplicated_thumbnail_filenames[@]}"; do
    if ! printf '%s\n' "${temp_array[@]}" | grep -Fxq "${deduplicated_thumbnail_filenames[$i]}"; then
        unused_thumbnails_indexes+=("$i")
    fi
done

# Check if the playlists exist
if [[ "${#deduplicated_label_lines[@]}" -eq 0 ]] && [[ "${#deduplicated_rom_filenames[@]}" -eq 0 ]]; then
    echo "Error: Your playlist is empty. Check your playlist and try again."

# Check if the thumbnails exist
elif [[ "${#deduplicated_thumbnail_filenames[@]}" -eq 0 ]]; then
    echo "Error: There's no thumbnail files. Nothing to be removed."

# Check if there are unused thumbnails to be removed
elif [[ "${#unused_thumbnails_indexes[@]}" -eq 0 ]]; then
    echo "All thumbnails are used. There's no unused thumbnail."

# Call a remover function to remove all unused thumbnails
else
    unused_thumbnails_delete
fi
