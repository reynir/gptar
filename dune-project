(lang dune 3.7)

(name gptar)

(generate_opam_files true)

(source
 (github reynir/gptar))

(authors "Reynir Björnsson <reynir@reynir.dk>")

(maintainers "Maintainer Name")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name gptar)
 (synopsis "GPT headers that are also valid tar headers")
 (description "\
              A longer description")
 (depends ocaml dune gpt tar checkseum)
 (tags
  (gpt tar)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
