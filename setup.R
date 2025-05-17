install.packages(
  "pak",
  repos = sprintf(
    "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
    .Platform$pkgType,
    R.Version()$os,
    R.Version()$arch
  )
)
pak::pak("extendr/rextendr")

repos <- "https://cloud.r-project.org/"

install.packages("devtools", repos = repos)
install.packages("tidyverse", repos = repos)

# Some packages need particular versions

install.packages("remotes", repos = repos)
remotes::install_version(
  "roxygen2",
  version = "7.3.2",
  upgrade = "always",
  repos = repos
)
remotes::install_version(
  "pkgload",
  version = "1.4.0",
  upgrade = "always",
  repos = repos
)
