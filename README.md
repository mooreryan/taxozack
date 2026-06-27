# taxozack

  <!-- badges: start -->

[![R-CMD-check](https://github.com/mooreryan/taxozack/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mooreryan/taxozack/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/mooreryan/taxozack/graph/badge.svg)](https://app.codecov.io/gh/mooreryan/TaxoZack)

  <!-- badges: end -->

## Installation

The quickest way to get started is to use `pak`. You don't need to worry about downloading the source code, manually installing dependencies, or anything like that. `pak` is nice like that.

The taxozack package only depends on Rcpp, so it should be quick to install!

First install `pak` if you don't already have it:

```R
# Install pak to manage the package install
install.packages("pak")
```

Next, decide whether you want to install from a tagged version or from the main branch. It's generally a good idea to install from a tagged version.

```R
pak::pak("mooreryan/taxozack@1.0.0")
```

If you want to install from the latest commit on the main branch, do this:

```R
pak::pak("mooreryan/taxozack")
```

## Example

Here is a brief example:

```R
# A tiny example of what the input data might look like
df <- tibble::tibble(
  Accession = c("AY956920.1", "AY956941.1", "AY957583.1", "AY957603.1"),
  Cluster = c("1", "1", "2", "2"),
  Taxonomy = c(
    "Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus;Bacillus sp. HPC 639",
    "Bacteria;Firmicutes;Bacilli;Bacillales;Staphylococcaceae;Staphylococcus;Staphylococcus sp. HPC 904",
    "Eukaryota;Chordata;Mammalia;Primates;Hominidae;Homo;Homo sapiens",
    "Bacteria;Firmicutes;Clostridia;Eubacteriales;Clostridiaceae;Clostridium;Clostridium sp. pandaD"
  ),
)

# Get the LCA for each cluster.
within_cluster_lca <- df |>
  dplyr::group_by(Cluster) |>
  dplyr::reframe(Value = taxozack::lca(Accession, Taxonomy)) |>
  dplyr::mutate(Variable = rep(
    c("TaxonomyPath", "TaxonomyLevel"),
    times = dplyr::n() / 2
  )) |>
  tidyr::pivot_wider(names_from = "Variable", values_from = "Value")

# within_cluster_lca would look like this
#
# Cluster TaxonomyPath                           TaxonomyLevel
# <chr>   <chr>                                  <chr>
# 1       Bacteria;Firmicutes;Bacilli;Bacillales order
# 2       NONE                                   NONE
```

## Case Insensitive Matching

Taxonomy field comparisons are case-insensitive: `"Bacteria"` and `"bacteria"` are treated as the same value. However, the original casing from the input is preserved in the returned taxonomy path.
