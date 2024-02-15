(* I just made this one up... *)
let tar_guid = Uuidm.of_string "53cd6812-46cc-474e-a141-30b3aed85f53" |> Option.get

let () =
  let oc = open_out_bin "disk.img" in
  let sector_size = Tar.Header.length in
  let disk_sectors = 1024L in
  (* We create an empty partition table to figure out what would be the
     first usable LBA. *)
  let empty =
    Gpt.make ~sector_size ~disk_sectors []
    |> Result.get_ok
  in
  (* Partition names are utf16le encoded *)
  let name =
    let ascii_name = "Real tar archive" in
    let buf = Bytes.make 72 '\000' in
    String.iteri
      (fun i c ->
         ignore (Bytes.set_utf_16le_uchar buf (2*i) (Uchar.of_char c)))
      ascii_name;
    Bytes.unsafe_to_string buf
  in
  let partition =
    (* a 4 sector partition right after the partition table *)
    Gpt.Partition.make
      ~name
      ~type_guid:tar_guid
      ~attributes:1L
      empty.first_usable_lba
      Int64.(pred (add empty.first_usable_lba 4L))
    |> Result.get_ok
  in
  let gpt =
    Gpt.make ~sector_size ~disk_sectors [ partition ]
    |> Result.get_ok
  in
  let buf = Cstruct.create (sector_size * Int64.to_int disk_sectors) in
  (* We marshal the GPT+TAR header *)
  Gptar.marshal_header ~sector_size buf gpt;
  (* Then the GPT partition table *)
  Gpt.marshal_partition_table ~sector_size 
    (Cstruct.shift buf (Int64.to_int gpt.partition_entry_lba * sector_size))
    gpt;
  (* Then we populate the partition with one "test.txt" file *)
  let content = "Hello, World!\n" in
  let tar_hdr = Tar.Header.make "test.txt" (Int64.of_int (String.length content)) in
  let partition_buf = Cstruct.shift buf (sector_size * Int64.(to_int partition.starting_lba)) in
  (* XXX: there seems to be a bug in checksum computation in marshal *)
  Tar.Header.marshal (Cstruct.sub partition_buf 0 Tar.Header.length) tar_hdr;
  Cstruct.blit_from_string content 0 partition_buf Tar.Header.length (String.length content);
  (* Finally we copy the GPT+TAR header to the backup location (end of disk) *)
  Gpt.marshal_header ~sector_size ~primary:false
    (Cstruct.sub buf (Cstruct.length buf - sector_size) sector_size)
    gpt;
  output_string oc (Cstruct.to_string buf);
  close_out oc
