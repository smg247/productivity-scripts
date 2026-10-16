TOOL=$1
cd ~/Projects/ci-tools

echo Building linux binary of ${TOOL}
GOOS=linux go build -v -o ~/bin/linux/${TOOL} ./cmd/${TOOL}

CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
echo Building image quay.io/sgoeddel/${TOOL}:latest
$CONTAINER_ENGINE build -f images/${TOOL}/Dockerfile ~/bin/linux -t quay.io/sgoeddel/${TOOL}:latest
echo Pushing image quay.io/sgoeddel/${TOOL}:latest
$CONTAINER_ENGINE push quay.io/sgoeddel/${TOOL}:latest

cd -