use ahash::{AHashMap, AHashSet};
use extendr_api::prelude::*;
use std::fmt::{self, Display};
use std::fs::File;
use std::io::BufWriter;
use std::io::Write;
use std::ops::ControlFlow;
use std::path::PathBuf;

const TAXONOMY_LEVELS: usize = 7;

#[derive(Debug, Clone, Copy)]
enum TaxonomyLevel {
    Domain = 0,
    Phylum = 1,
    Class = 2,
    Order = 3,
    Family = 4,
    Genus = 5,
    Species = 6,
}

impl Display for TaxonomyLevel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TaxonomyLevel::Domain => write!(f, "domain"),
            TaxonomyLevel::Phylum => write!(f, "phylum"),
            TaxonomyLevel::Class => write!(f, "class"),
            TaxonomyLevel::Order => write!(f, "order"),
            TaxonomyLevel::Family => write!(f, "family"),
            TaxonomyLevel::Genus => write!(f, "genus"),
            TaxonomyLevel::Species => write!(f, "species"),
        }
    }
}

#[derive(Debug)]
struct TaxonomyPath {
    accession: String,
    full_taxonomy: String,
    prefix_end_index: [u16; TAXONOMY_LEVELS],
    field_is_some: [bool; TAXONOMY_LEVELS],
}

impl TaxonomyPath {
    fn new(accession: &str, full_taxonomy: String) -> (String, Self) {
        let accession = accession.trim_matches('"');
        let full_taxonomy = full_taxonomy.trim_matches('"');

        let mut prefix_ends = [0u16; TAXONOMY_LEVELS];
        let mut field_is_some = [false; TAXONOMY_LEVELS];

        // Not collecting this into a Vec to assert the count first saves a significant amount of
        // time and allocations.
        let fields = full_taxonomy.split(';');
        let mut current_position = 0;

        // We need to manually track the count since we aren't converting to Vec before iterating
        let mut count = 0;

        for (i, field) in fields.enumerate() {
            count += 1;
            let is_na = matches!(field, "na" | "NA" | "nA" | "Na");
            field_is_some[i] = !field.is_empty() && !is_na;

            current_position += field.len();
            // TODO: probably need to fix these casts since they can technically fail
            prefix_ends[i] = current_position as u16;

            // Add semicolon length except for the last field
            if i < TAXONOMY_LEVELS - 1 {
                current_position += 1;
            }
        }

        // In the context of the current rCRUX, all taxonomy paths will have all seven levels
        assert_eq!(count, TAXONOMY_LEVELS);

        let taxonomy_path = TaxonomyPath {
            accession: accession.to_string(),
            full_taxonomy: full_taxonomy.to_owned(),
            prefix_end_index: prefix_ends,
            field_is_some,
        };

        (accession.to_string(), taxonomy_path)
    }

    fn accession(&self) -> &str {
        &self.accession
    }

    fn level(&self, taxonomy_level: TaxonomyLevel) -> Option<&str> {
        let i = taxonomy_level as usize;

        if !self.field_is_some[i] {
            return None;
        }

        Some(&self.full_taxonomy[0..self.prefix_end_index[i] as usize])
    }
}

#[derive(Debug)]
enum UniqueTaxon<'a> {
    NonUnique,
    UniqueNone,
    UniqueSome(&'a str),
}

fn unique_taxa<'a>(taxa: &[Option<&'a str>]) -> UniqueTaxon<'a> {
    let mut unique_taxa = AHashSet::with_capacity(taxa.len());

    for taxon in taxa {
        unique_taxa.insert(taxon);

        if unique_taxa.len() > 1 {
            return UniqueTaxon::NonUnique;
        }
    }

    let len = unique_taxa.len();

    assert!(len == 0 || len == 1);

    match unique_taxa.into_iter().next() {
        Some(Some(taxon)) => UniqueTaxon::UniqueSome(taxon),
        Some(None) => UniqueTaxon::UniqueNone,
        // taxa.len() should always be > 0,
        // so really this shouldn't ever hit.
        None => UniqueTaxon::UniqueNone,
    }
}

struct Lca<'a> {
    taxonomy_level: TaxonomyLevel,
    taxon: &'a str,
}

fn check_level<'a>(
    taxonomy_level: TaxonomyLevel,
    taxonomy_paths: &[&'a TaxonomyPath],
    previous_lca: Option<Lca<'a>>,
) -> ControlFlow<Option<Lca<'a>>, Option<Lca<'a>>> {
    // Check phylum
    let taxa: Vec<Option<&str>> = taxonomy_paths
        .iter()
        .map(|taxonomy_path| taxonomy_path.level(taxonomy_level))
        .collect();

    match unique_taxa(&taxa) {
        // Keep going we might have a non-null taxon below
        UniqueTaxon::UniqueNone => ControlFlow::Continue(previous_lca),
        UniqueTaxon::UniqueSome(taxon) => ControlFlow::Continue(Some(Lca {
            taxonomy_level,
            taxon,
        })),
        UniqueTaxon::NonUnique => ControlFlow::Break(previous_lca),
    }
}

fn lca<'a>(taxonomy_paths: &[&'a TaxonomyPath]) -> Option<Lca<'a>> {
    // All taxonomy levels in order
    let taxonomy_levels = [
        TaxonomyLevel::Domain,
        TaxonomyLevel::Phylum,
        TaxonomyLevel::Class,
        TaxonomyLevel::Order,
        TaxonomyLevel::Family,
        TaxonomyLevel::Genus,
        TaxonomyLevel::Species,
    ];

    match taxonomy_levels
        .into_iter()
        .try_fold(None, |previous_lca, taxonomy_level| {
            check_level(taxonomy_level, taxonomy_paths, previous_lca)
        }) {
        ControlFlow::Continue(result) => result,
        ControlFlow::Break(result) => result,
    }

    // TODO: do we need to check if they were all none?
}

fn read_clusters(clusters_file: &PathBuf) -> AHashMap<String, Vec<String>> {
    let mut cluster_members = AHashMap::new();

    let file = File::open(clusters_file).expect("failed to open clusters_file");
    let reader = std::io::BufReader::new(file);
    let lines = std::io::BufRead::lines(reader);

    for line in lines {
        let line = line.expect("failed to read line");
        let parts: Vec<&str> = line.split('\t').map(str::trim).collect();

        if parts.len() < 2 {
            continue;
        }

        let accession = parts[0].to_string();
        let cluster = parts[1].to_string();

        cluster_members
            .entry(cluster)
            .or_insert_with(Vec::new)
            .push(accession);
    }

    cluster_members
}

fn read_taxonomy_paths(taxonomy_paths_file: &PathBuf) -> AHashMap<String, TaxonomyPath> {
    let mut accessions = AHashMap::new();
    let file = File::open(taxonomy_paths_file).expect("failed to open clusters_file");
    let reader = std::io::BufReader::new(file);
    let lines = std::io::BufRead::lines(reader);

    for line in lines {
        let line = line.expect("failed to read line");
        let parts: Vec<&str> = line.split('\t').map(str::trim).collect();
        let accession = parts[0];
        let taxonomy = parts[1].to_lowercase();

        // This is the cleaned accession
        let (accession, taxonomy_path) = TaxonomyPath::new(accession, taxonomy);
        accessions.insert(accession, taxonomy_path);
    }

    accessions
}

#[derive(Debug)]
struct Config {
    taxonomy_paths_file: PathBuf,
    clusters_file: PathBuf,
    output_file: PathBuf,
}

impl Config {
    fn new(args: &[String]) -> Self {
        if args.len() != 4 {
            eprintln!(
                "Usage: {} taxonomy_paths_file clusters_file output_file",
                args[0]
            );
            std::process::exit(1);
        }

        let taxonomy_paths_file = PathBuf::from(&args[1]);
        let clusters_file = PathBuf::from(&args[2]);
        let output_file = PathBuf::from(&args[3]);

        Config {
            taxonomy_paths_file,
            clusters_file,
            output_file,
        }
    }
}

pub fn run(args: Vec<String>) {
    let config = Config::new(&args);

    let output = File::create(&config.output_file).expect("failed to create output file");
    let mut writer = BufWriter::new(output);

    let accession_taxonomy_paths = read_taxonomy_paths(&config.taxonomy_paths_file);
    let cluster_members = read_clusters(&config.clusters_file);

    for (cluster, accessions) in cluster_members.iter() {
        // println!("YO");
        // panic!("yo");
        let mut taxonomy_paths = Vec::new();

        for accession in accessions.iter() {
            match accession_taxonomy_paths.get(accession) {
                Some(x) => taxonomy_paths.push(x),
                None => {
                    eprintln!(
                        "Accession {} was present in the clusters file but not in the taxonomy file. Skipping.",
                        accession
                    );
                }
            };
        }

        match lca(&taxonomy_paths) {
            None => writeln!(writer, "{cluster}\tna\tna").expect("failed to write output line"),
            Some(lca) => {
                for taxonomy_path in taxonomy_paths {
                    let accession = taxonomy_path.accession();
                    let taxon = lca.taxon;
                    let level = lca.taxonomy_level;
                    writeln!(writer, "{cluster}\t{level}\t{taxon}\t{accession}")
                        .expect("failed to write output line");
                }
            }
        }
    }
}

// TODO: This is a bit weird, since the functions were originally written to handle CLI input.
#[extendr]
fn lca_wrapper(accessions: Strings, taxonomy_strings: Strings) -> Robj {
    assert_eq!(accessions.len(), taxonomy_strings.len());

    let taxonomy_paths: Vec<TaxonomyPath> = accessions
        .iter()
        .zip(taxonomy_strings.iter())
        .map(|(accession, taxonomy_string)| {
            let (_, taxonomy_path) =
                TaxonomyPath::new(accession, taxonomy_string.as_str().to_string());
            taxonomy_path
        })
        .collect();

    let taxonomy_path_refs: Vec<&TaxonomyPath> = taxonomy_paths.iter().collect();

    match lca(&taxonomy_path_refs) {
        None => {
            r!(vec!["NONE", "NONE"])
        }
        Some(lca) => {
            r!(vec![lca.taxon.to_string(), lca.taxonomy_level.to_string()])
        }
    }
}

extendr_module! {
    mod taxozack;
    fn lca_wrapper;
}
