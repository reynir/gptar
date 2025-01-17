(lang dune 3.7)

(name gptar)

(generate_opam_files true)

(source
 (github reynir/gptar))

(authors "Reynir Björnsson <reynir@reynir.dk>")

(maintainers "Reynir Björnsson <reynir@reynir.dk>")

(license BSD-2-Clause)

(package
 (name gptar)
 (synopsis "GPT headers that are also valid tar headers")
 (description "\
Marshaling GPT headers such that they are a valid tar archive.
The archive will contain a dummy file named `GPTAR` whose content
is (at least) the GPT header and the partition table entries.
Put a tar-partition at the first available space, and you can
inspect the tar archive using regular tar utilities on the disk
image with the caveat of the added `GPTAR` dummy file.")
 (depends ocaml dune gpt (tar (>= 3.0.0)) checkseum)
 (tags (gpt tar mirage)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
