#!/bin/bash
DOCKER_VERSION=1.0.0

docker-machine create --driver virtualbox default
status=$(docker-machine status default)
if [ "$status" != "Running" ]; then
	docker-machine start default
fi
docker-machine env default
eval "$(docker-machine env default)"

#This line gets the latest commit hash to use as the cachebust, when it changes the 
#it will break the cache on the line just before we pull the code. So that it won't use
#the cache and instead will pull the latest and repackage
export CACHEBUST=`git ls-remote https://github.com/maproulette/maproulette2.git | grep HEAD | cut -f 1`
docker build -t $DOCKER_USER/maproulette2:$DOCKER_VERSION --build-arg CACHEBUST=$CACHEBUST .

# Run it locally. Optional
docker rm -f `docker ps --no-trunc -aq`

docker run --name mr2-postgis \
	-e POSTGRES_DB=mr2_prod \
	-e POSTGRES_USER=mr2dbuser \
	-e POSTGRES_PASSWORD=mr2dbpassword \
	-d mdillon/postgis

sleep 10

docker run -t --privileged -d -p 8080:8080 \
	--name maproulette2 \
	--link mr2-postgis:db \
	$DOCKER_USER/maproulette2:$DOCKER_VERSION

docker ps

echo "IP: $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' maproulette2)"
echo "If running on OS X, with boot2docker, make sure to create a nat rule to be able to connect through the virtual box VM"
echo "VBoxManage controlvm boot2docker-vm natpf1 \"maproulette2,tcp,127.0.0.1,8080,,8080\""