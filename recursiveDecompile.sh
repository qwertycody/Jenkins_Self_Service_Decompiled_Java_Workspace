doMagic()
{
    FILE_NAME=$(basename -- "$1")
    FILE_EXTENSION="${FILE_NAME##*.}"
    FILE_NAME="${FILE_NAME%.*}"

    ARCHIVE_DIRECTORY=$(dirname "$1")
    ARCHIVE_OUTPUT_DIRECTORY="$ARCHIVE_DIRECTORY/$FILE_NAME"

    FILE_TYPE_MATCH="FALSE"

    JAVA_CLASS_TYPES=( "class" )
    for fileType in "${JAVA_CLASS_TYPES[@]}"
    do
        if [[ $1 =~ \.$fileType ]]; then
            echo JAVA_CLASS "$1"
            java -jar jd-cli.jar -dm -rn -n -od "$ARCHIVE_OUTPUT_DIRECTORY" "$1"
            echo "Decompiled $1 to $ARCHIVE_OUTPUT_DIRECTORY"
            return
        fi
    done

    JAVA_ARCHIVE_TYPES=( "war" "jar" )
    for fileType in "${JAVA_ARCHIVE_TYPES[@]}"
    do
        if [[ $1 =~ \.$fileType ]]; then
            echo JAVA_ARCHIVE "$1"
            java -jar jd-cli.jar -dm -rn -n -od "$ARCHIVE_OUTPUT_DIRECTORY" "$1"
            echo "Decompiled $1 to $ARCHIVE_OUTPUT_DIRECTORY"
            
            searchDirectory "$ARCHIVE_OUTPUT_DIRECTORY"
            return 
        fi
    done

    COMPRESSED_ARCHIVE_TYPES=( "zip" "gz" )
    for fileType in "${COMPRESSED_ARCHIVE_TYPES[@]}"
    do
        if [[ $1 =~ \.$fileType ]]; then
            echo COMPRESSED_ARCHIVE "$1"
            unzip -o -q "$1" -d "$ARCHIVE_OUTPUT_DIRECTORY"
            echo "Decompiled $1 to $ARCHIVE_OUTPUT_DIRECTORY"
            
            searchDirectory "$ARCHIVE_OUTPUT_DIRECTORY"
            return 
        fi
    done

}

searchDirectory()
{
    FILE_EXTENSIONS=( "zip" "gz" "war" "jar" "class" )
    for fileType in "${FILE_EXTENSIONS[@]}"
    do
        find "$1" -name "*.$fileType" -print -type f -exec bash -c 'doMagic "$0"' {} \;
    done
}

export -f doMagic
export -f searchDirectory

searchDirectory "$1"