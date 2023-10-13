TOOL=$1
cd ~/Projects/ci-tools

echo Building linux binary of ${TOOL}
GOOS=linux go build -v -o ~/bin/linux/${TOOL} ./cmd/${TOOL}
echo Building docker image quay.io/sgoeddel/${TOOL}:latest
docker build -f images/${TOOL}/Dockerfile ~/bin/linux -t quay.io/sgoeddel/${TOOL}:latest
echo Pushing docker image quay.io/sgoeddel/${TOOL}:latest
docker push quay.io/sgoeddel/${TOOL}:latest

cd -