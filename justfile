basic_build:
    docker build -t taxozack:latest .

basic_build_no_cache:
    docker build --no-cache -t taxozack:latest .

build_local:
    #!/usr/bin/env bash
    set -euxo pipefail

    docker buildx create --use

    docker buildx build \
        --platform linux/arm64 \
        -t taxozack:latest \
        --output=type=docker .

# push_image username:
#     #!/usr/bin/env bash
#     set -euxo pipefail

#     docker buildx create --use

#     docker buildx build \
#         --platform linux/amd64,linux/arm64 \
#         -t {{ username }}/taxozack:latest \
#         --push .

run_image args:
    #!/usr/bin/env bash
    set -euxo pipefail

    docker run --rm --platform=linux/arm64 taxozack {{ args }}

# docker_shell:
#     #!/usr/bin/env bash
#     set -euxo pipefail

#     docker run --rm -it -v $(pwd):$(pwd) taxozack:latest /bin/bash

docker_shell:
    #!/usr/bin/env bash
    set -euxo pipefail

    docker run --rm -it taxozack:latest /bin/bash
