#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset

# Utilized Enhanced `getopt`
! getopt --test > /dev/null
if [ ${PIPESTATUS[0]} -ne 4 ]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=o:
LONGOPTS=release-directory:

# -use ! and PIPESTATUS to get exit code with errexit set
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi

# Read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

# Set default(s)
RELEASE_DIRECTORY=""

# Parse parameter(s)
while true; do
    case "$1" in
        -o|--release-directory)
            RELEASE_DIRECTORY="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Encountered error while parsing arguments!"
            exit 3
            ;;
    esac
done

# Handle invalid arguments
if [ $# -ne 0 ]; then
    echo "$0: Unknown argument \"$1\" supplied!"
    exit 4
elif [ -z $RELEASE_DIRECTORY ]; then
    echo "--release-directory argument must be specified!"
    exit 5
fi

function valid_platform()
{
    # Parse parameter(s)
    platform=$1

    # Validate platform (result of expression returned to caller)
    [ "$platform" = "core" ] || [ "$platform" = "electron" ] || [ "$platform" = "p1" ] || [ "$platform" = "photon" ]
}

# Identify the absolute directory
cd $RELEASE_DIRECTORY
ABSOLUTE_RELEASE_DIRECTORY=$(pwd)

# Make a working directory
TEMPORARY_DIRECTORY=$ABSOLUTE_RELEASE_DIRECTORY/tmp
rm -rf $TEMPORARY_DIRECTORY
mkdir $TEMPORARY_DIRECTORY

# Parse the --release-directory hierarchy
for VERSION in *; do
    # The primary directory is the version number
    if [ -d "$VERSION" ]; then
        pushd $VERSION > /dev/null
        # Move through the platforms
        for PLATFORM in *; do
            if [ -d "$PLATFORM" ] && valid_platform $PLATFORM; then
                echo "$PLATFORM"
                pushd $PLATFORM > /dev/null
                # Find "release" directory
                for RELEASE in *; do
                    if [ -d "$RELEASE" ] && [ "$RELEASE" = "release" ]; then
                        pushd $RELEASE > /dev/null
                        zip $TEMPORARY_DIRECTORY/particle-$VERSION+$PLATFORM.zip . --recurse-paths --quiet
                        cp *.bin $TEMPORARY_DIRECTORY
                        popd > /dev/null
                    fi
                done
                popd > /dev/null
                zip $TEMPORARY_DIRECTORY/particle-platform-$VERSION+$PLATFORM.zip $PLATFORM --recurse-paths --quiet
            fi
        done
        popd > /dev/null
        zip $TEMPORARY_DIRECTORY/particle-release-$VERSION.zip $VERSION --recurse-paths --quiet
        PUBLISH_DIRECTORY=$VERSION/publish
        rm -rf $PUBLISH_DIRECTORY
        mv $TEMPORARY_DIRECTORY $PUBLISH_DIRECTORY
    fi
done