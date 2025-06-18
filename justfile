default:
    just -l

basic_build:
    docker build -t taxozack:latest .

basic_build_no_cache:
    docker build --no-cache -t taxozack:latest .

docker_build_and_push username:
    #!/usr/bin/env bash
    set -euxo pipefail

    R_PACKAGE_VERSION=$(awk -F': ' '/^Version/ { print $2 }' DESCRIPTION)
    SHORT_GIT_SHA=$(git describe --always --dirty --abbrev=7)

    TAG="${R_PACKAGE_VERSION}-${SHORT_GIT_SHA}"

    docker buildx create --use

    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t "{{ username }}/taxozack:$TAG" \
        --push \
        .

run_image args:
    #!/usr/bin/env bash
    set -euxo pipefail

    docker run --rm --platform=linux/arm64 taxozack {{ args }}

docker_shell:
    #!/usr/bin/env bash
    set -euxo pipefail

    docker run --rm -it -v $(pwd):$(pwd) taxozack:latest /bin/bash
