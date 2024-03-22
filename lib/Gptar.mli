(** [marshal_header ~sector_size buf gpt] marshals into [buf] a hybrid
    protective MBR + tar header followed by the GPT header in the next sector
    according to [sector_size]. The partition table and the backup GPT header are not serialized, and the caller must call the respective functions in [Gpt].

    @raise Invalid_argument when [buf] or [sector_size] is too small. *)
val marshal_header : sector_size: int -> Cstruct.t -> Gpt.t -> unit
