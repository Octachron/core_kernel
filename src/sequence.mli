(** This module extends {{!Base.Sequence}[Base.Sequence]} with bin_io. *)

type 'a t = 'a Base.Sequence.t [@@deriving bin_io]

module Step : sig
  type ('a, 's) t = ('a, 's) Base.Sequence.Step.t =
    | Done
    | Skip of 's
    | Yield of 'a * 's
  [@@deriving bin_io]

  include module type of struct include Base.Sequence.Step end
  with type ('a, 's) t := ('a, 's) t
end

module Merge_with_duplicates_element : sig
  type ('a, 'b) t = ('a, 'b) Base.Sequence.Merge_with_duplicates_element.t =
    | Left of 'a
    | Right of 'b
    | Both of 'a * 'b
  [@@deriving bin_io]

  include module type of struct include Base.Sequence.Merge_with_duplicates_element end
  with type ('a, 'b) t := ('a, 'b) t
end

include module type of struct include Base.Sequence end
  with type 'a t := 'a Base.Sequence.t
   and module Step := Base.Sequence.Step
   and module Merge_with_duplicates_element := Base.Sequence.Merge_with_duplicates_element (** @open *)

(** Merges elements from sequences that are assumed to be sorted by [compare] to produce a
    sequence also sorted by [compare]. If any of the inputs are not sorted, the order of
    the output is not guaranteed to be sorted.

    This includes duplicate elements in the output (whether they occur within
    one input sequence, or across different input sequences).
*)
val merge_all : 'a t list -> compare:('a -> 'a -> int) -> 'a t
