(* https://sar.informatik.hu-berlin.de/research/publications/SAR-PR-2006-05/SAR-PR-2006-05_.pdf *)
let magic_sequence = 0x2144df1cl
let gpt_sizeof = 92 (* Gpt.sizeof *)
let gpt_header_crc32_offset = 16
let tar_chksum_offset = 148
let tar_link_indicator_offset = 156
let gptar_link_indicator = 'G'

let marshal_protective_mbrtar buf t =
  (* We need to write 0x55, 0xAA at offsets 510-511.
     We must also write a partition at offset 446-461:
       446: 0x80
       447-449: CHS first, probably not important
       450: type 0xEE
       451-453: CHS last, also not important
       454: first LBA
       458: number of LBAs *)
  let num_lbas = Int64.(to_int32 (min (succ t.Gpt.last_usable_lba) 0xFFFFFFFFL)) in
  Cstruct.set_uint8 buf 446 0x80;
  Cstruct.set_uint8 buf 447 0x00;
  Cstruct.set_uint8 buf 448 0x02;
  Cstruct.set_uint8 buf 449 0x00;
  Cstruct.set_uint8 buf 450 0xEE;
  Cstruct.set_uint8 buf 451 0xFF;
  Cstruct.set_uint8 buf 452 0xFF;
  Cstruct.set_uint8 buf 453 0xFF;
  Cstruct.LE.set_uint32 buf 454 1l;
  Cstruct.LE.set_uint32 buf 458 num_lbas;
  Cstruct.set_uint8 buf 510 0x55;
  Cstruct.set_uint8 buf 511 0xAA


let marshal_header ~sector_size buf (t : Gpt.t) =
  if Cstruct.length buf < 2 * sector_size ||
     Cstruct.length buf < gpt_sizeof ||
     sector_size < Tar.Header.length ||
     t.partition_entry_lba <> 2L then
    invalid_arg "Gptar.marshal";
  let file_name =
    "GPTAR"
  in
  (* The "file" is the first LBA minus the tar header size plus the GPT header
     (LBA 1) plus the size of the partition table rounded up to [sector_size].
     XXX: we assume the partition table starts right after the GPT header. *)
  let file_size =
    let partition_table_size = 
      Int32.to_int t.num_partition_entries * Int32.to_int t.partition_size
    in
    sector_size - Tar.Header.length +
    sector_size +
    ((partition_table_size + pred sector_size) / sector_size) * sector_size
  in
  let header =
    Tar.Header.make file_name (Int64.of_int file_size)
  in
  (* First we write the protective MBR. Then we marshal the tar header and
     exploit that ocaml-tar doesn't zero out the unused parts of the tar
     header. ocaml-tar will include the MBR parts when computing the checksum.
  *)
  marshal_protective_mbrtar buf t;
  Tar.Header.marshal (Cstruct.sub buf 0 Tar.Header.length) header;
  (* Let's fix up the link indicator so tar utilities like GNU tar will skip
     the unknown type. The 'G' link indicator seems unused. We will need to
     update the tar checksum then. *)
  let old_link_indicator = Cstruct.get_uint8 buf tar_link_indicator_offset in
  let old_checksum =
    let s = Cstruct.to_string buf ~off:tar_chksum_offset ~len:8 in
    let s = String.(trim (map (function '\000' -> ' ' | x -> x) s)) in
    int_of_string ("0o"^s)
  in
  Cstruct.set_char buf tar_link_indicator_offset gptar_link_indicator;
  (* The checksum is just a sum of the byte values in the header *)
  let checksum = old_checksum - old_link_indicator + Char.code gptar_link_indicator in
  let checksum = Printf.sprintf "%07o\000" checksum in
  Cstruct.blit_from_string checksum 0 buf tar_chksum_offset 8;
  Gpt.marshal_header ~sector_size ~primary:true (Cstruct.shift buf sector_size) t
