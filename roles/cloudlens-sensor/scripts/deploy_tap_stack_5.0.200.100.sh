#!/bin/bash
#environment variable
#download the docker-compose.yml
#run it in the host where we want to tap
#older version for compose
#docker-compose --version
#docker-compose up
DRIVERLESS_MODE=0
VERSION=5.0.200.100

function usage() {
    echo "./deploy_tap_stack.sh --install DOCKER_LOCAL_REGISTRY REGISTRATION_URL"
    echo "./deploy_tap_stack.sh --uninstall"
    echo "./deploy_tap_stack.sh --upgrade DOCKER_LOCAL_REGISTRY REGISTRATION_URL"
}
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

function do_install() {
    if [ $# -lt 2 ]; then
        usage
        exit 1
    fi
    DOCKER_LOCAL_REGISTRY=$1
    REGISTRATION_URL=$2
    errors=""
    if [ -r /etc/docker/daemon.json ]; then
        r=`cat /etc/docker/daemon.json | grep $DOCKER_LOCAL_REGISTRY:5000`
        if [ "x$r" = "x" ]; then
            echo "$DOCKER_LOCAL_REGISTRY:5000 is not added into /etc/docker/daemon.json as insecure registry."
            exit 1
        fi
    else
        echo "Can't check if $DOCKER_LOCAL_REGISTRY:5000 is added into /etc/docker/daemon.json as insecure registry."
    fi

    echo "Checking if docker repository $DOCKER_LOCAL_REGISTRY is up ..."
    wget -q --tries=1 https://$DOCKER_LOCAL_REGISTRY:5000/v2/_catalog --no-check-certificate
    if [ "$?" != "0" ]; then
        errors="$errors\nCatalog not available on https://$DOCKER_LOCAL_REGISTRY:5000/v2/_catalog. Please make sure docker registry is correctly set up."
    else
        rm _catalog
        echo "Checking if version $VERSION exists on docker registry $DOCKER_LOCAL_REGISTRY"
        wget -q --tries=1 https://$DOCKER_LOCAL_REGISTRY:5000/v2/sensor/tags/list --no-check-certificate
        ver_ok=`cat list | grep $VERSION`
        if [ "x$ver_ok" = "x" ]; then
            errors="$errors\nVersion $VERSION does not exists on registry."
            rm list
        else
            rm list
        fi
    fi

    which nc > /dev/null
    if [ "$?" = "0" ]; then
        echo "Checking if registration IP $REGISTRATION_URL listens on tcp port 5000"
        nc -z -w3 $REGISTRATION_URL 5000
        if [ "$?" != "0" ]; then
            errors="$errors\nIP $REGISTRATION_URL doesn't have port tcp port 5000 opened."
        fi
    else
        echo "Cannot check if registration IP $REGISTRATION_URL listens on tcp port 5000. netcat package is not installed"
    fi

    if [ "x$errors" != "x" ]; then
        echo -e "\nErrors found:$errors"
        exit 1
    fi

    sensor_id=`docker ps -q -f name=sensor`
    if [ "x$sensor_id" != "x" ]; then
        echo "sensor container already exists. Removing ..."
        docker stop sensor
        docker rm sensor
    fi

    docker login --username=ixia --password=ixia123 ${DOCKER_LOCAL_REGISTRY}:5000
    docker pull ${DOCKER_LOCAL_REGISTRY}:5000/sensor:${VERSION}
#docker stack deploy -c docker-compose.yml ixia-tap --with-registry-auth
#set the registry settings
#docker stop sensor
#docker rm sensor
    if [ ! -f /var/cloudtap/sensor_pan_cfg.yml ]; then
        echo "/var/cloudtap/sensor_pan_cfg.yml file does not exists. Copying it..."
        sudo mkdir -p /var/cloudtap
        sudo cp sensor_pan_cfg.yml /var/cloudtap
    fi
    docker run --name 'sensor' --restart on-failure -d --net=host --device=/dev/mem --cap-add=SYS_RAWIO --cap-add=SYS_RESOURCE --cap-add=SYS_ADMIN --cap-add=NET_ADMIN --cap-add=NET_RAW -e REGISTRATION_URL=${REGISTRATION_URL} -e DRIVERLESS_MODE=${DRIVERLESS_MODE} -v /var/cloudtap:/var/cloudtap ${DOCKER_LOCAL_REGISTRY}:5000/sensor:${VERSION}
}

function do_uninstall() {
    sensor_id=`docker ps -q -f name=sensor`
    if [ "x$sensor_id" != "x" ]; then
        echo "Removing sensor container"
        docker stop sensor
        docker rm sensor
    fi
    sensor_img=`docker images | grep sensor  | awk '{print $3}'`
    docker rmi $sensor_img
    #removed the shared location data
    sudo rm -rf /var/cloudtap
}

function do_upgrade() {
    if [ $# -lt 2 ]; then
        usage
        exit 1
    fi
    DOCKER_LOCAL_REGISTRY=$1
    REGISTRATION_URL=$2
    errors=""
    echo "Checking if docker repository $DOCKER_LOCAL_REGISTRY is up ..."
    wget -q --tries=1 https://$DOCKER_LOCAL_REGISTRY:5000/v2/_catalog --no-check-certificate
    if [ "$?" != "0" ]; then
        errors="$errors\nCatalog not available on https://$DOCKER_LOCAL_REGISTRY:5000/v2/_catalog. Please make sure docker registry is correctly set up."
    else
        rm _catalog
        echo "Checking if version $VERSION exists on docker registry $DOCKER_LOCAL_REGISTRY"
        wget -q --tries=1 https://$DOCKER_LOCAL_REGISTRY:5000/v2/sensor/tags/list --no-check-certificate
        ver_ok=`cat list | grep $VERSION`
        if [ "x$ver_ok" = "x" ]; then
            errors="$errors\nVersion $VERSION does not exists on registry."
        else
            rm list
        fi
    fi

    which nc > /dev/null
    if [ "$?" = "0" ]; then
        echo "Checking if registration IP $REGISTRATION_URL listens on tcp port 5000"
        nc -z -w3 $REGISTRATION_URL 5000
        if [ "$?" != "0" ]; then
            errors="$errors\nIP $REGISTRATION_URL doesn't have port tcp port 5000 opened."
        fi
    else
        echo "Cannot check if registration IP $REGISTRATION_URL listens on tcp port 5000. netcat package is not installed"
    fi
    if [ "x$errors" != "x" ]; then
        echo -e "\nErrors found:$errors"
        exit 1
    fi

    do_uninstall
    do_install $1 $2
}

case $1 in
    --install) do_install ${@:2}
    ;;
    --uninstall) do_uninstall
    ;;
    --upgrade) do_upgrade ${@:2}
    ;;
    *) usage
        exit 1
    ;;
esac
