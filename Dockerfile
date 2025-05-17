FROM debian:bookworm

RUN mkdir -p /etc/sudoers.d
RUN useradd -m -s /bin/bash taxozack
RUN echo "taxozack ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/taxozack
RUN chmod 0440 /etc/sudoers.d/taxozack

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
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
    r-cran-systemfonts \
    r-cran-textshaping \
    sudo && \
    sudo rm -rf /var/lib/apt/lists/*

USER taxozack
WORKDIR /home/taxozack

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/home/taxozack/.cargo/bin:${PATH}"
RUN echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/taxozack/.bashrc

RUN mkdir -p /home/taxozack/R/aarch64-unknown-linux-gnu-library/4.2
ENV R_LIBS_USER=/home/taxozack/R/aarch64-unknown-linux-gnu-library/4.2
RUN echo 'R_LIBS_USER="/home/taxozack/R/aarch64-unknown-linux-gnu-library/4.2"' >> /home/taxozack/.Renviron
RUN echo 'export R_LIBS_USER="/home/taxozack/R/aarch64-unknown-linux-gnu-library/4.2"' >> /home/taxozack/.bashrc

COPY --chown=taxozack:taxozack ./setup.R /home/taxozack/setup.R

RUN Rscript --vanilla /home/taxozack/setup.R && rm /home/taxozack/setup.R

COPY --chown=taxozack:taxozack . /home/taxozack/taxozack
WORKDIR /home/taxozack/taxozack

RUN Rscript --vanilla -e 'devtools::install(pkg = ".", build = TRUE)'
