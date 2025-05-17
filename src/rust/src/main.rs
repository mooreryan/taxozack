use std::env;
use taxozack::run;

fn main() {
    let args: Vec<String> = env::args().collect();

    run(args)
}
