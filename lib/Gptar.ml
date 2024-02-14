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
  (* Replace the header crc32 with the magic sequence. This is (most likely)
     not the correct crc32 checksum for that header, but we will fix that
     later. *)
  let t = { t with Gpt.header_crc32 = magic_sequence } in
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
     includes the non-reserved part of our GPT header. *)
  Tar.Header.marshal buf header;
  (* Let's fix up the link indicator so tar utilities like GNU tar will skip
     the unknown type. The 'G' link indicator seems unused. *)
  Cstruct.set_char buf tar_link_indicator_offset 'G';
  (* Next, we compute the crc32 of the sector except for the last 4 bytes *)
  let crc32 =
    Checkseum.Crc32.digest_bigstring
      buf.buffer buf.off (buf.len - 4)
      Checkseum.Crc32.default
  in
  (* Since the tar header's checksum covers the GPT header's checksum we can't
     modify that. However, setting [crc32] at the end of the sector the crc32
     checksum of the buffer will be [magic_sequence]! This will ensure the the
     GPT header's checksum also works. *)
  Cstruct.LE.set_uint32 buf (sector_size - 4) (Optint.to_int32 crc32)
