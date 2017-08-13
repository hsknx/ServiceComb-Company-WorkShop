#!/bin/bash
# huawei service stage website :  https://servicestage.hwclouds.com/
# How to use(Linux):
# 1. Uncomment the variables and set their values
# 2. Execute: bash publish_images_to_huaweicloud.sh

# config example
# TARGET_VERSION=0.0.1                                                  # ---------huawei cloud images repository target version.
# TENANT_NAME=xxxxxxxxxxx                                               # ---------huawei cloud tenant name.
# REPO_ADDRESS=registry.cn-north-1.hwclouds.com                         # ---------huawei cloud images repository address.
# USER_NAME=xxxxx                                                       # ---------username: login huawei cloud images repository.
# PW=xxxxxxx                                                            # ---------password: login huawei cloud images repository.
WORKER_NAME=worker                                                      # ---------worker name, created by maven docker plugin.
BEEKEEPER_NAME=beekeeper                                                # ---------beekeeper name, created by maven docker plugin.
DOORMAN_NAME=doorman                                                    # ---------doorman name, created by maven docker plugin.
MANAGER_NAME=manager                                                    # ---------manager name, created by maven docker plugin.


which docker
if [ $? -ne 0 ]; then
    echo "no docker, please install docker 1.11.2."
    exit 1
fi

which mvn
if [ $? -ne 0 ]; then
    echo "no maven, please install maven."
    exit 1
fi

function isPropertySet () {
    if [ -z $2 ]; then
        echo "$1 is empty, please set it first"
        exit 1
    fi
}

properties=(TARGET_VERSION TENANT_NAME REPO_ADDRESS USER_NAME PW
            WORKER_NAME BEEKEEPER_NAME DOORMAN_NAME MANAGER_NAME)
for property in ${properties[@]}; do
    isPropertySet $property ${!property}
done

ROOT_PATH=$(cd "$(dirname $0)/.."; pwd)
cd $ROOT_PATH
ORIGIN_VERSION=$(mvn help:evaluate -Dexpression=project.version | grep Building | awk '{print $4}')

modules=($WORKER_NAME $BEEKEEPER_NAME $DOORMAN_NAME $MANAGER_NAME)
echo "Removing old docker images"
for module in ${modules[@]}; do
    image_id=$(docker images| grep $module| grep $ORIGIN_VERSION| awk '{print $3}')
    if [ ! -z $image_id ]; then
       docker rmi -f $image_id
    fi
done

echo "Generating new docker images"
mvn clean package -DskipTests -DskipITs -Phuaweicloud -Pdocker

echo "Tagging image versions"
for module in ${modules[@]}; do
    docker tag $module:$ORIGIN_VERSION ${REPO_ADDRESS}/${TENANT_NAME}/workshop-$module:$TARGET_VERSION
done

zipkin_exists=$(docker images| grep "${REPO_ADDRESS}/${TENANT_NAME}/zipkin"| awk '{print $2}'| grep 1)
if [ -z $zipkin_exists ]; then
    docker pull openzipkin/zipkin:1
    docker tag openzipkin/zipkin:1 ${REPO_ADDRESS}/${TENANT_NAME}/zipkin:1
fi

docker login -u ${USER_NAME} -p ${PW} ${REPO_ADDRESS}

echo "Pushing images to huawei docker repository"
for module in ${modules[@]}; do
    docker push ${REPO_ADDRESS}/${TENANT_NAME}/workshop-$module:$TARGET_VERSION
done
docker push ${REPO_ADDRESS}/${TENANT_NAME}/zipkin:1

echo "Done"