#!/bin/bash

# Check if .env file exists
if [ ! -f ".env" ]; then
  echo "Error: .env file not found"
  exit 1
fi

# Determine which Dockerfile to use.
# Pass "fs_install" as the first parameter to use Dockerfile_fs_install.
DOCKERFILE="Dockerfile"
if [ "$1" == "fs_install" ]; then
  DOCKERFILE="Dockerfile_fs_install"
  echo "Using Dockerfile_fs_install for the build."
else
  echo "Using default Dockerfile."
fi

# Read variables from .env file.
# It's assumed that each variable is defined as VAR=value.
CMAKE_VERSION=$(grep '^CMAKE_VERSION=' .env | awk -F '=' '{print $2}')
GRPC_VERSION=$(grep '^GRPC_VERSION=' .env | awk -F '=' '{print $2}')
LIBWEBSOCKETS_VERSION=$(grep '^LIBWEBSOCKETS_VERSION=' .env | awk -F '=' '{print $2}')
SPEECH_SDK_VERSION=$(grep '^SPEECH_SDK_VERSION=' .env | awk -F '=' '{print $2}')
SPANDSP_VERSION=$(grep '^SPANDSP_VERSION=' .env | awk -F '=' '{print $2}')
SOFIA_VERSION=$(grep '^SOFIA_VERSION=' .env | awk -F '=' '{print $2}')
AWS_SDK_CPP_VERSION=$(grep '^AWS_SDK_CPP_VERSION=' .env | awk -F '=' '{print $2}')
FREESWITCH_MODULES_VERSION=$(grep '^FREESWITCH_MODULES_VERSION=' .env | awk -F '=' '{print $2}')
FREESWITCH_VERSION=$(grep '^FREESWITCH_VERSION=' .env | awk -F '=' '{print $2}')

DOCKER_IMAGE_REPO=$(grep '^DOCKER_IMAGE_REPO=' .env | awk -F '=' '{print $2}')
DOCKER_IMAGE_VERSION=$(grep '^DOCKER_IMAGE_VERSION=' .env | awk -F '=' '{print $2}')

# Build the Docker image using the chosen Dockerfile and build arguments.
docker build --no-cache --progress=plain \
  -f "$DOCKERFILE" \
  --build-arg CMAKE_VERSION="${CMAKE_VERSION}" \
  --build-arg GRPC_VERSION="${GRPC_VERSION}" \
  --build-arg LIBWEBSOCKETS_VERSION="${LIBWEBSOCKETS_VERSION}" \
  --build-arg SPEECH_SDK_VERSION="${SPEECH_SDK_VERSION}" \
  --build-arg SPANDSP_VERSION="${SPANDSP_VERSION}" \
  --build-arg SOFIA_VERSION="${SOFIA_VERSION}" \
  --build-arg AWS_SDK_CPP_VERSION="${AWS_SDK_CPP_VERSION}" \
  --build-arg FREESWITCH_MODULES_VERSION="${FREESWITCH_MODULES_VERSION}" \
  --build-arg FREESWITCH_VERSION="${FREESWITCH_VERSION}" \
  . --tag "${DOCKER_IMAGE_REPO}:${DOCKER_IMAGE_VERSION}"
