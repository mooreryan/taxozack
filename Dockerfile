FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libgit2-dev \
    libharfbuzz-dev \
    libicu-dev \
    libjpeg-dev \
    libpng-dev \
    libssl-dev \
    libtiff-dev \
    libxml2-dev \
    r-base \
    r-base-dev \
    r-cran-rcpp \
    r-cran-systemfonts \
    r-cran-textshaping \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash taxozack
USER taxozack
WORKDIR /home/taxozack

COPY --chown=taxozack:taxozack ./setup.R /home/taxozack/setup.R
RUN Rscript --vanilla /home/taxozack/setup.R && rm /home/taxozack/setup.R

COPY --chown=taxozack:taxozack . /home/taxozack/taxozack
WORKDIR /home/taxozack/taxozack

RUN Rscript --vanilla -e 'devtools::install(pkg = ".", build = TRUE)'
