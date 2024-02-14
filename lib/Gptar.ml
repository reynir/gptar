(* https://sar.informatik.hu-berlin.de/research/publications/SAR-PR-2006-05/SAR-PR-2006-05_.pdf *)
let magic_sequence = 0x2144df1cl
let gpt_sizeof = 92 (* Gpt.sizeof *)
let gpt_header_crc32_offset = 16
let tar_link_indicator_offset = 156

let marshal_header ~sector_size buf t =
  if Cstruct.length buf < sector_size ||
     Cstruct.length buf < gpt_sizeof ||
     sector_size < Tar.Header.length + 4 then
    invalid_arg "Gptar.marshal";
  let file_name =
    (* sector_size in [Gpt.marshal_header] is only used to figure out how much
       of the reserved space to zero out. We use [buf] even if Tar will
       overwrite the first 512 bytes. The 'reserved' part of the GPT header
       will be zeroed out. *)
    Gpt.marshal_header ~sector_size buf t;
    Cstruct.to_string buf ~len:gpt_sizeof
  in
  (* The "file" is the first LBA minus the tar header size plus the size of the
     partition table rounded up to [sector_size]. *)
  let file_size =
    let partition_table_size = 
      Int32.to_int t.num_partition_entries * Int32.to_int t.partition_size
    in
    sector_size - Tar.Header.length +
    ((partition_table_size + pred sector_size) / sector_size) * sector_size
  in
  let header =
    Tar.Header.make file_name (Int64.of_int file_size)
  in
  (* Now we marshal the tar header which will start with the GPT header (as the
     tar file name). The remainder of the tar fields are at least eight bytes
     into the reserved space of the GPT header (which should be all zero, but
     who's checking?). Tar itself has a checksum of its own header which
     includes the non-reserved part of our GPT header. The GPT header's
     checksum only covers the first 92 bytes so no need to try to reverse CRC32
     checksums. *)
  Tar.Header.marshal buf header;
  (* Let's fix up the link indicator so tar utilities like GNU tar will skip
     the unknown type. The 'G' link indicator seems unused. *)
  Cstruct.set_char buf tar_link_indicator_offset 'G'