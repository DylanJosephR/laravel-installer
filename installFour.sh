#!/bin/bash

## This is your playground

BASH_DIR=`which bash`
BIN_DIR=`dirname $BASH_DIR`
GIT_APP=git
CURL_APP=curl
PHP_APP=php
SUDO_APP=sudo
COMPOSER_APP=composer
DIRECTORIES=( /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin )
INSTALL_DIR=$1
PHPUNIT_APP=phpunit
PHPUNIT_DIR=/etc/phpunit
PHP_APP=php

#################################################################### 

function main() {
    checkSudo
    checkPHP
    checkWebserver
    checkParameters $INSTALL_DIR
    checkApp $GIT_APP
    checkApp $CURL_APP
    checkComposer $INSTALL_DIR
    checkPHPUnit
    downloadSkeleton $INSTALL_DIR
    downloadL4 $INSTALL_DIR
}

function downloadL4() {
    cd $1
    $COMPOSER_APP install
}

function checkPHP() {
    php=`$PHP_APP -v` &> /dev/null
    if [ $? -gt 0 ]; then
        echo "PHP is not installed. Aborted."
        exit 1
    fi

    echo "PHP is installed."
}

function checkPHPUnit() {
    phpunit=`which $PHPUNIT_APP`
    if [ "$phpunit" == "" ]; then
        installPHPUnit
    fi
}

function installPHP() {
    sudo apt-get --yes intall php5 
}

function checkWebserver() {
    WEBSERVER=
    webserver=`ps -eaf |grep apache2 |grep -v grep |wc -l` && [ "$webserver" -gt "0" ] && WEBSERVER=apache2
    webserver=`ps -eaf |grep nginx |grep -v grep |wc -l` && [ "$webserver" -gt "0" ] && WEBSERVER=nginx
    webserver=`ps -eaf |grep lighthttpd |grep -v grep |wc -l` && [ "$webserver" -gt "0" ] && WEBSERVER=lighttpd

    if [ "$WEBSERVER" == "" ]; then
        echo "Looks like there is no webserver software intalled or runnig. Aborted."
        exit 1
    fi

    echo "Webserver ($WEBSERVER) is installed."
}

function installPHPUnit() {
    if [ "$CAN_I_RUN_SUDO" == "YES" ]; then
        $SUDO_APP mkdir -p $PHPUNIT_DIR
        $SUDO_APP chmod 777 $PHPUNIT_DIR
        echo '{' > $PHPUNIT_DIR/composer.json
        echo '    "name": "phpunit",' >> $PHPUNIT_DIR/composer.json
        echo '    "description": "PHPUnit",' >> $PHPUNIT_DIR/composer.json
        echo '    "require": {' >> $PHPUNIT_DIR/composer.json
        echo '        "phpunit/phpunit": "3.7.*"' >> $PHPUNIT_DIR/composer.json
        echo '    },' >> $PHPUNIT_DIR/composer.json
        echo '    "config": {' >> $PHPUNIT_DIR/composer.json
        echo '        "bin-dir": "$PHPUNIT_DIR"' >> $PHPUNIT_DIR/composer.json
        echo '    }' >> $PHPUNIT_DIR/composer.json
        echo '}' >> $PHPUNIT_DIR/composer.json
        cd $PHPUNIT_DIR
        $COMPOSER_APP install
        $SUDO_APP chmod +x $PHPUNIT_DIR/vendor/phpunit/phpunit/composer/bin/phpunit
        $SUDO_APP ln -s $PHPUNIT_DIR/vendor/phpunit/phpunit/composer/bin/phpunit $BIN_DIR/$PHPUNIT_APP
    fi 
}

function installComposer() {
    echo "Trying to install composer..."
    cd $INSTALL_DIR
    perl -pi -e "s/;suhosin.executor.include.whitelist =$/suhosin.executor.include.whitelist = phar/g" /etc/php5/cli/conf.d/suhosin.ini
    curl -s http://getcomposer.org/installer | $PHP_APP
    if [ $? -gt 0 ]; then
        echo "Composer installation failed. Aborted."
        exit 1
    fi   
    COMPOSER_APP=$BIN_DIR/composer
    $SUDO_APP mv composer.phar $COMPOSER_APP
    $SUDO_APP chmod +x $COMPOSER_APP
}

function checkComposer() {
    checkComposerInstalled
    if [ "$RETURN_VALUE" != "TRUE" ]; then
        installComposer
        checkComposerInstalled
        if [ "$RETURN_VALUE" != "TRUE" ]; then
            echo "composer is not installed and I was not able to install it"
        fi
    fi

    if [ "$RETURN_VALUE" == "TRUE" ]; then
        echo "Found composer at $COMPOSER_PATH."
    fi
}

function checkComposerInstalled() {
    [[ -f $COMPOSER_APP ]] && COMPOSER_PATH=$COMPOSER_APP

    [[ -z "$COMPOSER_PATH" ]] && COMPOSER_PATH=`which $COMPOSER_APP`
    [[ -z "$COMPOSER_PATH" ]] && COMPOSER_PATH=`which $COMPOSER_APP.phar`

    for element in $INSTALL_DIR $BIN_DIR /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin
    do
        [[ -z "$COMPOSER_PATH" ]] && [ -f $element/$COMPOSER_APP ] && COMPOSER_PATH="$element/$COMPOSER_APP"
        [[ -z "$COMPOSER_PATH" ]] && [ -f $element/$COMPOSER_APP ] && COMPOSER_PATH="$element/$COMPOSER_APP.phar"
    done
    
    if [[ -z "$COMPOSER_PATH" ]]; then
        RETURN_VALUE=FALSE
    else 
        RETURN_VALUE=TRUE
    fi
}

function downloadSkeleton() {
    git clone https://github.com/niallobrien/laravel4-template.git $1
}

function installApp() {
    if [ "CAN_I_RUN_SUDO" == "YES"]; then
        $SUDO_APP apt-get --yes install $1 &> /dev/null
        $SUDO_APP yum --assumeyes install $1 &> /dev/null
    else 
        #try to install anyway
        apt-get --yes install $1 &> /dev/null
        yum --assumeyes install $1 &> /dev/null
    fi
}

function checkApp() {
    if ! type -p $1 > /dev/null; then
        echo -n "Trying to install $1..."
        installApp $1 &> /dev/null
        if ! type -p $1 > /dev/null; then
            echo ""
            echo ""
            echo "Looks like $1 is not installed or not available for this application."
            exit 0
        fi
        echo " done."
    else 
        echo "$1 is installed and available."
    fi
}

function checkErrors() {
    if [ $? -gt 0 ]; then
        echo $1
        exit 1
    fi
}

function checkParameters() {
    if [ ! $1 ]; then
       echo "You need to provide installation directory."
       exit 1
    fi

    if [ -f $1 ]; then
       echo "You provided a regular file name, not a directory, please specify a directory."
       exit 1
    fi

    if [ -d $1 ]; then
        if [ "$(ls -A $1)" ]; then
           echo "Directory $1 is not empty."
           exit 1
        fi
    else 
        mkdir $1
        checkErrors "Error creating directory $1"
    fi
}

function checkSudo {
    if [[ $EUID -ne 0 ]]; then
        echo "Your sudo password is required for some commands."
        sudo -k
        sudo echo -n 
        CAN_I_RUN_SUDO=$(sudo -n uptime 2>&1|grep "load"|wc -l)
        [ ${CAN_I_RUN_SUDO} -gt 0 ] && CAN_I_RUN_SUDO="YES" || CAN_I_RUN_SUDO="NO"
    else 
        # user is root, no need to run sudo
        CAN_I_RUN_SUDO=YES
        SUDO_APP=
    fi
}

clear
main $1
