(* I just made this one up... *)
let tar_guid = Uuidm.of_string "53cd6812-46cc-474e-a141-30b3aed85f53" |> Option.get

let () =
  let oc = open_out_bin "disk.img" in
  let sector_size = Tar.Header.length in
  let disk_sectors = 1024L in
  let empty =
    Gpt.make ~sector_size ~disk_sectors []
    |> Result.get_ok
  in
  let name =
    let ascii_name = "Real tar archive" in
    let buf = Bytes.create 72 in
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
      (Int64.add empty.first_usable_lba 3L)
    |> Result.get_ok
  in
  let gpt = { empty with Gpt.partitions = [ partition ] } in
  let buf = Cstruct.create (sector_size * Int64.to_int disk_sectors) in
  Gptar.marshal_header ~sector_size buf gpt;
  Gpt.marshal_partition_table ~sector_size 
    (Cstruct.shift buf sector_size) gpt;
  let content = "Hello, World!\n" in
  let tar_hdr = Tar.Header.make "test.txt" (Int64.of_int (String.length content)) in
  let partition_buf = Cstruct.shift buf (sector_size * Int64.to_int gpt.first_usable_lba) in
  Tar.Header.marshal partition_buf tar_hdr;
  Cstruct.blit_from_string content 0 partition_buf Tar.Header.length (String.length content);
  output_string oc (Cstruct.to_string buf);
  close_out oc
