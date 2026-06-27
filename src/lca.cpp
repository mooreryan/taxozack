#include <Rcpp.h>
#include <string>
#include <vector>

using namespace Rcpp;

static const int N_LEVELS = 7;

static const char *LEVEL_NAMES[N_LEVELS] = {
    "domain", "phylum", "class", "order", "family", "genus", "species"};

// Returns true when the field content should be treated as a missing value.
static bool is_na_field(const std::string &field) {
  return field.empty() || field == "na" || field == "NA" || field == "nA" ||
         field == "Na";
}

// Represents a parsed taxonomy path.
//
// Stores the original (unmodified) taxonomy string together with the character
// position at which each level's field ends, and whether each field is
// considered present (non-NA).  The prefix returned for level i is
// full_taxonomy[0..prefix_end[i]], which includes every level from domain
// through i joined by semicolons.
struct TaxonomyPath {
  std::string full_taxonomy;
  // one-past-end index for each level's field
  int prefix_end[N_LEVELS];
  // false when the field is empty or an NA variant
  // is_some kinda a weird term, but it's to match the old rust impl
  bool field_is_some[N_LEVELS];

  explicit TaxonomyPath(const std::string &raw) {
    // Trim surrounding double-quotes (matches original behavior...not sure if
    // we still need it though)
    std::string s = raw;
    if (!s.empty() && s.front() == '"')
      s.erase(0, 1);
    if (!s.empty() && s.back() == '"')
      s.pop_back();
    full_taxonomy = s;

    int n = static_cast<int>(s.size());
    int field_start = 0;
    int level = 0;

    for (int i = 0; i <= n; ++i) {
      // Process a field when we hit a semicolon or the end of the string.
      if (i < n && s[i] != ';') {
        continue;
      }

      if (level >= N_LEVELS) {
        stop("taxonomy string has more than 7 semicolon-separated levels");
      }

      std::string field = s.substr(field_start, i - field_start);
      field_is_some[level] = !is_na_field(field);
      prefix_end[level] = i;

      field_start = i + 1;
      level++;
    }

    if (level != N_LEVELS) {
      stop("taxonomy string must have exactly 7 semicolon-separated levels "
           "(got %d)",
           level);
    }
  }

  // Returns the taxonomy prefix from domain through `level` inclusive,
  // or an empty string when the field at `level` is NA/missing.
  std::string get_prefix(int level) const {
    assert(level >= 0 && level < N_LEVELS);

    if (!field_is_some[level]) {
      return "";
    }

    return full_taxonomy.substr(0, prefix_end[level]);
  }
};

//' @useDynLib taxozack, .registration = TRUE
//' @importFrom Rcpp sourceCpp
// [[Rcpp::export]]
CharacterVector lca_wrapper(CharacterVector accessions,
                            CharacterVector taxonomy_strings) {
  int n = accessions.size();
  if (n != static_cast<int>(taxonomy_strings.size())) {
    stop("accessions and taxonomy_strings must have the same length");
  }

  // Parse all taxonomy paths up front.
  std::vector<TaxonomyPath> paths;
  paths.reserve(n);
  for (int i = 0; i < n; ++i) {
    paths.emplace_back(as<std::string>(taxonomy_strings[i]));
  }

  // Walk from domain to species, tracking the deepest level at which every
  // path agrees on the same non-NA value.
  //
  // Three outcomes per level:
  //   ALL_NA      - every path has a missing value here; keep current best
  //                 and continue to the next level.
  //   UNIQUE_SOME - every path has the same non-NA prefix; update best and
  //                 continue.
  //   NON_UNIQUE  - paths disagree (incl. Some vs. None); stop immediately
  //                 and return the current best.
  std::string best_taxon = "";
  int best_level = -1;

  for (int level = 0; level < N_LEVELS; ++level) {
    bool first_set = false;
    bool first_is_some = false;
    std::string first_prefix;
    bool non_unique = false;

    for (const auto &path : paths) {
      bool is_some = path.field_is_some[level];
      std::string prefix = is_some ? path.get_prefix(level) : "";

      if (!first_set) {
        first_is_some = is_some;
        first_prefix = prefix;
        first_set = true;
      } else if (is_some != first_is_some || prefix != first_prefix) {
        non_unique = true;
        break;
      }
    }

    if (non_unique) {
      break;
    }

    if (first_set && first_is_some) {
      best_taxon = first_prefix;
      best_level = level;
    }
    // If all paths are NA at this level: continue without updating best.
  }

  if (best_level < 0) {
    return CharacterVector::create("NONE", "NONE");
  }

  return CharacterVector::create(best_taxon, LEVEL_NAMES[best_level]);
}
