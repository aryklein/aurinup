#!/usr/bin/bash

function install_pkgs {
    TMP=`mktemp -d`
    CUR_DIR=`pwd`
    for PACKAGE in $*; do
        curl -s -L -o $TMP/$PACKAGE.tar.gz https://aur.archlinux.org/cgit/aur.git/snapshot/$PACKAGE.tar.gz
        tar xvzf $TMP/$PACKAGE.tar.gz -C $TMP
        cd $TMP/$PACKAGE
        makepkg -s
        sudo pacman --noconfirm -U $PACKAGE*.pkg.tar.xz
    done
    cd "$CUR_DIR"
    rm -rf $TMP
}

function install {
    COUNT=0
    for PACKAGE in $*; do
        AUR_VER=`curl -s https://aur.archlinux.org/packages/$PACKAGE/|grep Package\ Details:| gawk '{print $4}'`
        AUR_VER=${AUR_VER%</h2>}
        if [[ -z $AUR_VER ]]; then
            echo -e "error target not found: $PACKAGE"
            continue
        fi
        PKG_TO_INSTALL[COUNT]=$PACKAGE
        PKG_VER[COUNT]=$AUR_VER
        (( COUNT++ ))
    done

    if [[ -z $PKG_TO_INSTALL ]]; then
       exit 1
    fi 

    printf "Packages (${#PKG_TO_INSTALL[@]}): "
    for ((i = 0 ; i < $COUNT ; i++)); do
        printf "%s%c%s  " "${PKG_TO_INSTALL[i]}-${PKG_VER[i]}"
    done
    
    echo -e "\n"
    read -r -p ":: Proceed with installation? [Y/n] " RESPONSE
    if [[ $RESPONSE =~ ^(y|Y|yes|)$ ]]; then
        install_pkgs ${PKG_TO_INSTALL[*]}
    else
        echo No change was made. Bye!
    fi
}

function upgrade {
    COUNT=0
    
    for PACKAGE in `pacman -Qm | gawk '{print $1}'`; do

        # get the installed package version
        INSTALLED_VER=`pacman -Qm | grep "^$PACKAGE\s" |gawk '{print $2}'`

        # get the current version of the package in the AUR
        AUR_VER=`curl -s https://aur.archlinux.org/packages/$PACKAGE/|grep Package\ Details:| gawk '{print $4}'`
        AUR_VER=${AUR_VER%</h2>}

        if [[ -z $AUR_VER ]]; then    # This package is not in the AUR
            continue                  # continue with the next package
        fi

        # generate a list of packages to upgrade
        if [[ "$INSTALLED_VER" < "$AUR_VER" ]]; then
            PKG_TO_UPGRADE[COUNT]=$PACKAGE
            PKG_VER[COUNT]=$AUR_VER
            (( COUNT++ ))
        fi    
    done

    if [[ -z $PKG_TO_UPGRADE ]]; then
        echo -e "All package are up to date. Nothing to do\n"
        exit 1
    fi

    printf "Packages (${#PKG_TO_UPGRADE[@]}): "
    for ((i = 0 ; i < $COUNT ; i++)); do
        printf "%s%c%s  " "${PKG_TO_UPGRADE[i]}-${PKG_VER[i]}"
    done
    
    echo -e "\n"
    read -r -p ":: Proceed with installation? [Y/n] " RESPONSE
    if [[ $RESPONSE =~ ^(y|yes|)$ ]]; then
        install_pkgs ${PKG_TO_UPGRADE[*]}
    else
        echo No change was made. Bye!
  fi
}

if [ "$(id -u)" == "0" ]; then
    echo "This script shouldn't be run as root" 1>&2
    exit 1
else
    if [[ -z $1 ]]; then
        upgrade
    else
        install $*
    fi
fi
