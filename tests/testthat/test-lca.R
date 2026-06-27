# -- Fixtures -----------------------------------------------------------------
# Realistic 7-level taxonomy strings drawn from the package documentation and
# demo files.  They are used across many test blocks below.

# nolint start
BACILLUS <- "Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus;Bacillus sp. HPC 639" # no lint
STAPH <- "Bacteria;Firmicutes;Bacilli;Bacillales;Staphylococcaceae;Staphylococcus;Staphylococcus sp. HPC 904"
HOMO <- "Eukaryota;Chordata;Mammalia;Primates;Hominidae;Homo;Homo sapiens"
CLOST <- "Bacteria;Firmicutes;Clostridia;Eubacteriales;Clostridiaceae;Clostridium;Clostridium sp. pandaD"
# nolint end

# Helper: build a 7-level taxonomy string from named parts.
tax <- function(domain, phylum, class, order, family, genus, species) {
  paste(domain, phylum, class, order, family, genus, species, sep = ";")
}


describe("lca()", {
  describe("return value structure", {
    it("returns a character vector", {
      result <- lca(c("A"), c(BACILLUS))
      expect_type(result, "character")
    })

    it("always returns a vector of length 2", {
      expect_length(lca(c("A"), c(BACILLUS)), 2)
      expect_length(lca(c("A", "B"), c(BACILLUS, STAPH)), 2)
      expect_length(lca(c("A", "B"), c(HOMO, BACILLUS)), 2)
    })

    it("returns the taxonomy path as element 1 and the level name as element 2", {
      result <- lca(c("A"), c(BACILLUS))
      # Element 1 is the full (or partial) taxonomy path string
      expect_equal(result[[1]], BACILLUS)
      # Element 2 is a level name
      expect_equal(result[[2]], "species")
    })

    it("returns level names in lowercase", {
      valid_levels <- c(
        "domain",
        "phylum",
        "class",
        "order",
        "family",
        "genus",
        "species",
        "NONE"
      )
      result <- lca(c("A", "B"), c(BACILLUS, STAPH))

      # Verify every possible level name is lowercase
      expect_true(result[[2]] %in% valid_levels)
    })
  })

  describe("single-sequence input", {
    it("resolves to species level when given one complete taxonomy string", {
      result <- lca(c("A"), c(BACILLUS))
      expect_equal(result[[2]], "species")
    })

    it("returns the full taxonomy path as-is when there is only one sequence", {
      result <- lca(c("A"), c(BACILLUS))
      expect_equal(result[[1]], BACILLUS)
    })

    it("works the same regardless of which single taxonomy string is supplied", {
      result_clost <- lca(c("A"), c(CLOST))
      expect_equal(result_clost[[2]], "species")
      expect_equal(result_clost[[1]], CLOST)

      result_homo <- lca(c("A"), c(HOMO))
      expect_equal(result_homo[[2]], "species")
      expect_equal(result_homo[[1]], HOMO)
    })
  })

  describe("identical sequences", {
    it("resolves to species when two sequences are identical", {
      result <- lca(c("A", "B"), c(BACILLUS, BACILLUS))
      expect_equal(result[[1]], BACILLUS)
      expect_equal(result[[2]], "species")
    })

    it("resolves to species when three sequences are identical", {
      result <- lca(c("A", "B", "C"), c(BACILLUS, BACILLUS, BACILLUS))
      expect_equal(result[[1]], BACILLUS)
      expect_equal(result[[2]], "species")
    })

    it("resolves to species when five sequences are identical", {
      accs <- c("A", "B", "C", "D", "E")
      taxes <- rep(HOMO, 5)
      result <- lca(accs, taxes)
      expect_equal(result[[1]], HOMO)
      expect_equal(result[[2]], "species")
    })
  })

  describe("LCA at each taxonomy level", {
    it("returns 'species' and the full path when all sequences share the same species", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "species")
      expect_equal(result[[1]], a)
    })

    it("returns 'genus' and the 6-level prefix when sequences share genus but differ at species", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus subtilis"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "genus")
      expect_equal(
        result[[1]],
        "Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus"
      )
    })

    it("returns 'family' and the 5-level prefix when sequences share family but differ at genus", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Paenibacillus",
        "Paenibacillus larvae"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "family")
      expect_equal(
        result[[1]],
        "Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae"
      )
    })

    it("returns 'order' and the 4-level prefix when sequences share order but differ at family (documented example)", {
      # BACILLUS and STAPH diverge at family (Bacillaceae vs Staphylococcaceae)
      result <- lca(c("A", "B"), c(BACILLUS, STAPH))
      expect_equal(result[[2]], "order")
      expect_equal(result[[1]], "Bacteria;Firmicutes;Bacilli;Bacillales")
    })

    it("returns 'class' and the 3-level prefix when sequences share class but differ at order", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Lactobacillales",
        "Lactobacillaceae",
        "Lactobacillus",
        "Lactobacillus acidophilus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "class")
      expect_equal(result[[1]], "Bacteria;Firmicutes;Bacilli")
    })

    it("returns 'phylum' and the 2-level prefix when sequences share phylum but differ at class", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Clostridia",
        "Eubacteriales",
        "Clostridiaceae",
        "Clostridium",
        "Clostridium perfringens"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "phylum")
      expect_equal(result[[1]], "Bacteria;Firmicutes")
    })

    it("returns 'domain' and just the domain name when sequences share domain but differ at phylum", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Proteobacteria",
        "Gammaproteobacteria",
        "Pseudomonadales",
        "Pseudomonadaceae",
        "Pseudomonas",
        "Pseudomonas aeruginosa"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "domain")
      expect_equal(result[[1]], "Bacteria")
    })
  })

  describe("NONE result", {
    it("returns c('NONE', 'NONE') when sequences have different domains", {
      result <- lca(c("A", "B"), c(HOMO, BACILLUS))
      expect_equal(result, c("NONE", "NONE"))
    })

    it("returns NONE for the documented cluster-2 example (Homo sapiens + Clostridium)", {
      result <- lca(c("AY957583.1", "AY957603.1"), c(HOMO, CLOST))
      expect_equal(result, c("NONE", "NONE"))
    })

    it("returns NONE for three sequences when any two domains disagree", {
      result <- lca(c("A", "B", "C"), c(BACILLUS, STAPH, HOMO))
      expect_equal(result, c("NONE", "NONE"))
    })
  })

  describe("NA / missing value handling", {
    it("treats 'NA' (uppercase) at species as missing, falling back to genus", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "NA"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      # One is None, other is Some -> NonUnique at species -> fall back to genus
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "genus")
      expect_equal(
        result[[1]],
        "Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus"
      )
    })

    it("treats 'na' (lowercase) as missing", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "na"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "genus")
    })

    it("treats 'nA' as missing", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "nA"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "genus")
    })

    it("treats 'Na' as missing", {
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Na"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "genus")
    })

    it("resolves to genus when both sequences have NA at species but agree at genus", {
      # Both species NA -> UniqueNone at species -> continue with genus as LCA
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "NA"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "NA"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "genus")
      expect_equal(
        result[[1]],
        "Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus"
      )
    })

    it("skips an all-NA level and continues walking deeper levels", {
      # Domain agrees, phylum agrees, class is all NA (skipped), order disagrees.
      # Expected: algorithm skips class (UniqueNone -> keep phylum candidate)
      #           then hits order disagreement -> stops -> returns phylum.
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "NA",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Firmicutes",
        "NA",
        "Clostridiales",
        "Clostridiaceae",
        "Clostridium",
        "Clostridium perfringens"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "phylum")
      expect_equal(result[[1]], "Bacteria;Firmicutes")
    })

    it("skips multiple consecutive all-NA levels and stops at the first disagreement", {
      # Domain agrees; phylum, class, order all NA; family disagrees.
      # Expected: LCA = domain (the last level that had a real agreement).
      a <- tax(
        "Bacteria",
        "NA",
        "NA",
        "NA",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "NA",
        "NA",
        "NA",
        "Clostridiaceae",
        "Clostridium",
        "Clostridium perfringens"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "domain")
      expect_equal(result[[1]], "Bacteria")
    })

    it("returns NONE when every level is NA for all sequences", {
      a <- tax("NA", "NA", "NA", "NA", "NA", "NA", "NA")
      b <- tax("NA", "NA", "NA", "NA", "NA", "NA", "NA")
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result, c("NONE", "NONE"))
    })
  })

  describe("NCBI taxonomy bubble behavior", {
    it("stops at the first divergent level even when deeper levels reconverge", {
      # Example NCBI bubble: A -> B1 -> C and A -> B2 -> C.
      # Sequences share domain (A) and everything from class downward,
      # but have different phyla (B1 vs B2).
      # The algorithm halts at phylum divergence and returns domain.
      # It does NOT continue to find the reconvergence at class.
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Bacteria",
        "Proteobacteria",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result[[2]], "domain")
      expect_equal(result[[1]], "Bacteria")
    })

    it("stops at domain divergence even when class through species are identical", {
      # Sequences share everything except domain and phylum.
      a <- tax(
        "Bacteria",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "Eukaryota",
        "Firmicutes",
        "Bacilli",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      result <- lca(c("A", "B"), c(a, b))
      expect_equal(result, c("NONE", "NONE"))
    })
  })

  describe("accession handling", {
    it("produces the same LCA regardless of what accession identifiers are supplied", {
      result1 <- lca(c("ACC1", "ACC2"), c(BACILLUS, STAPH))
      result2 <- lca(
        c("TOTALLY_DIFFERENT_1", "TOTALLY_DIFFERENT_2"),
        c(BACILLUS, STAPH)
      )
      expect_equal(result1, result2)
    })

    it("accepts accessions surrounded by double-quote characters", {
      # My original implementation handled this, so it's now enshrined in a
      # test.
      result_plain <- lca(c("ACC1"), c(BACILLUS))
      result_quoted <- lca(c('"ACC1"'), c(BACILLUS))
      expect_equal(result_plain, result_quoted)
    })
  })

  describe("taxonomy path format", {
    it("returns the path without a trailing semicolon", {
      result <- lca(c("A", "B"), c(BACILLUS, STAPH))
      expect_false(endsWith(result[[1]], ";"))
    })

    it("preserves the original case of the taxonomy string in the returned path", {
      # The R-level wrapper does NOT lowercase input (only the CLI does).
      a <- tax(
        "BACTERIA",
        "FIRMICUTES",
        "BACILLI",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus cereus"
      )
      b <- tax(
        "BACTERIA",
        "FIRMICUTES",
        "BACILLI",
        "Bacillales",
        "Bacillaceae",
        "Bacillus",
        "Bacillus subtilis"
      )
      result <- lca(c("A", "B"), c(a, b))
      # LCA is at genus; path should preserve the mixed-case input
      expect_equal(
        result[[1]],
        "BACTERIA;FIRMICUTES;BACILLI;Bacillales;Bacillaceae;Bacillus"
      )
    })

    it("uses semicolons as separators between levels in the returned path", {
      result <- lca(c("A", "B"), c(BACILLUS, STAPH)) # order-level LCA
      parts <- strsplit(result[[1]], ";")[[1]]
      expect_length(parts, 4) # domain;phylum;class;order
    })
  })

  describe("integration with dplyr grouping workflow", {
    it("produces the correct output for the documented two-cluster example", {
      df <- tibble::tibble(
        Accession = c("AY956920.1", "AY956941.1", "AY957583.1", "AY957603.1"),
        Cluster = c("1", "1", "2", "2"),
        Taxonomy = c(BACILLUS, STAPH, HOMO, CLOST)
      )

      result <- df |>
        dplyr::group_by(Cluster) |>
        dplyr::reframe(Value = lca(Accession, Taxonomy)) |>
        dplyr::mutate(
          Variable = rep(
            c("TaxonomyPath", "TaxonomyLevel"),
            times = dplyr::n() / 2
          )
        ) |>
        tidyr::pivot_wider(names_from = "Variable", values_from = "Value")

      expect_equal(nrow(result), 2)

      cluster1 <- result[result$Cluster == "1", ]
      expect_equal(
        cluster1$TaxonomyPath,
        "Bacteria;Firmicutes;Bacilli;Bacillales"
      )
      expect_equal(cluster1$TaxonomyLevel, "order")

      cluster2 <- result[result$Cluster == "2", ]
      expect_equal(cluster2$TaxonomyPath, "NONE")
      expect_equal(cluster2$TaxonomyLevel, "NONE")
    })

    it("handles a single-member cluster within a grouped workflow", {
      df <- tibble::tibble(
        Accession = c("A", "B", "C"),
        Cluster = c("1", "1", "2"),
        Taxonomy = c(BACILLUS, STAPH, HOMO)
      )

      result <- df |>
        dplyr::group_by(Cluster) |>
        dplyr::reframe(Value = lca(Accession, Taxonomy)) |>
        dplyr::mutate(
          Variable = rep(
            c("TaxonomyPath", "TaxonomyLevel"),
            times = dplyr::n() / 2
          )
        ) |>
        tidyr::pivot_wider(names_from = "Variable", values_from = "Value")

      # Cluster "2" has only Homo sapiens -> full species-level LCA
      cluster2 <- result[result$Cluster == "2", ]
      expect_equal(cluster2$TaxonomyLevel, "species")
      expect_equal(cluster2$TaxonomyPath, HOMO)
    })

    it("handles three clusters with different LCA levels in a single pipeline", {
      df <- tibble::tibble(
        Accession = c("A", "B", "C", "D", "E", "F"),
        Cluster = c("1", "1", "2", "2", "3", "3"),
        Taxonomy = c(
          # Cluster 1: order-level LCA
          BACILLUS,
          STAPH,
          # Cluster 2: NONE
          HOMO,
          CLOST,
          # Cluster 3: genus-level LCA
          tax(
            "Bacteria",
            "Firmicutes",
            "Bacilli",
            "Bacillales",
            "Bacillaceae",
            "Bacillus",
            "Bacillus cereus"
          ),
          tax(
            "Bacteria",
            "Firmicutes",
            "Bacilli",
            "Bacillales",
            "Bacillaceae",
            "Bacillus",
            "Bacillus subtilis"
          )
        )
      )

      result <- df |>
        dplyr::group_by(Cluster) |>
        dplyr::reframe(Value = lca(Accession, Taxonomy)) |>
        dplyr::mutate(
          Variable = rep(
            c("TaxonomyPath", "TaxonomyLevel"),
            times = dplyr::n() / 2
          )
        ) |>
        tidyr::pivot_wider(names_from = "Variable", values_from = "Value")

      expect_equal(nrow(result), 3)
      expect_equal(result$TaxonomyLevel[result$Cluster == "1"], "order")
      expect_equal(result$TaxonomyLevel[result$Cluster == "2"], "NONE")
      expect_equal(result$TaxonomyLevel[result$Cluster == "3"], "genus")
    })
  })

  describe("error handling", {
    it("errors when accessions and taxonomy_strings have different lengths", {
      expect_error(lca(c("A", "B"), c(BACILLUS)))
      expect_error(lca(c("A"), c(BACILLUS, STAPH)))
    })

    it("errors when a taxonomy string has fewer than 7 semicolon-separated levels", {
      expect_error(lca(c("A"), c("Bacteria;Firmicutes;Bacilli")))
      expect_error(lca(
        c("A"),
        c("Bacteria;Firmicutes;Bacilli;Bacillales;Bacillaceae;Bacillus")
      ))
    })

    it("errors when a taxonomy string has more than 7 semicolon-separated levels", {
      too_many <- paste0(BACILLUS, ";extra_level")
      expect_error(lca(c("A"), c(too_many)))
    })
  })
})
