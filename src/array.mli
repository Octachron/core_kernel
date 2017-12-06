(** This module extends {!Base.Array}. *)

open Import
open Perms.Export

(** {2 The [Array] type} *)

type 'a t = 'a Base.Array.t [@@deriving bin_io, typerep]

(** {2 The signature included from [Base.Array]} *)

include module type of struct include Base.Array end
  with type 'a t := 'a t (** @open *)

(** {2 Extensions}

    We add extensions for [Int] and [Float] arrays to make them bin-able, comparable,
    sexpable, and blit-able (via [Blit.S]). [Permissioned] provides fine-grained access
    control for arrays.
*)

module Int : sig
  type nonrec t = int t [@@deriving bin_io, compare, sexp]

  include Blit.S with type t := t

  external unsafe_blit
    : src:t -> src_pos:int -> dst:t -> dst_pos:int -> len:int -> unit
    = "core_array_unsafe_int_blit" [@@noalloc]
end

module Float : sig
  type nonrec t = float t [@@deriving bin_io, compare, sexp]

  include Blit.S with type t := t

  external unsafe_blit
    : src:t -> src_pos:int -> dst:t -> dst_pos:int -> len:int -> unit
    = "core_array_unsafe_float_blit" [@@noalloc]
end

(** The [Permissioned] module gives the ability to restrict permissions on an array, so
    you can give a function read-only access to an array, create an immutable array, etc.
*)
module Permissioned : sig
  (** The meaning of the ['perms] parameter is as usual (see the [Perms] module for more
      details) with the non-obvious difference that you don't need any permissions to
      extract the length of an array.  This was done for simplicity because some
      information about the length of an array can leak out even if you only have write
      permissions since you can catch out-of-bounds errors.
  *)
  type ('a, -'perms) t [@@deriving bin_io, compare, sexp]

  module Int : sig
    type nonrec -'perms t = (int, 'perms) t [@@deriving bin_io, compare, sexp]

    include Blit.S_permissions with type 'perms t := 'perms t

    external unsafe_blit
      : src:[> read] t -> src_pos:int -> dst:[> write] t -> dst_pos:int -> len:int -> unit
      = "core_array_unsafe_int_blit" [@@noalloc]
  end

  module Float : sig
    type nonrec -'perms t = (float, 'perms) t [@@deriving bin_io, compare, sexp]

    include Blit.S_permissions with type 'perms t := 'perms t

    external unsafe_blit
      : src:[> read] t -> src_pos:int -> dst:[> write] t -> dst_pos:int -> len:int -> unit
      = "core_array_unsafe_float_blit" [@@noalloc]
  end

  (** [of_array_id] and [to_array_id] return the same underlying array.  On the other
      hand, [to_array] (inherited from [Container.S1_permissions] below) makes a copy.

      To create a new (possibly immutable) copy of an array [a], use [copy (of_array_id
      a)].  More generally, any function that takes a (possibly mutable) [t] can be called
      on an array by calling [of_array_id] on it first.

      There is a conceptual type equality between ['a Array.t] and
      [('a, read_write) Array.Permissioned.t].  The reason for not exposing this as an
      actual type equality is that we also want:

      {ul
      {- The type equality ['a Array.t = 'a array] for interoperability with code which
      does not use Core.}
      {- The type [('a, 'perms) Array.Permissioned.t] to be abstract, so that the
      permission phantom type will have an effect.}
      }

      Since we don't control the definition of ['a array], this would require a type
      [('a, 'perms) Array.Permissioned.t] which is abstract, except that
      [('a, read_write) Array.Permissioned.t] is concrete, which is not possible.
  *)
  val of_array_id : 'a array -> ('a, [< read_write]) t
  val to_array_id : ('a, [> read_write]) t -> 'a array

  (** [to_sequence_immutable t] converts [t] to a sequence. Unlike [to_sequence],
      [to_sequence_immutable] does not need to copy [t] since it is immutable. *)
  val to_sequence_immutable : ('a, [> immutable]) t -> 'a Sequence.t

  include Container.         S1_permissions with type ('a, 'perms) t := ('a, 'perms) t
  include Blit.              S1_permissions with type ('a, 'perms) t := ('a, 'perms) t
  include Binary_searchable. S1_permissions with type ('a, 'perms) t := ('a, 'perms) t

  (** These functions are in [Container.S1_permissions], but they are re-exposed here so
      that their types can be changed to make them more permissive (see comment above). *)

  val length   : (_, _) t -> int
  val is_empty : (_, _) t -> bool

  (** counterparts of regular array functions above *)

  external get        : ('a, [> read] ) t -> int -> 'a         = "%array_safe_get"
  external set        : ('a, [> write]) t -> int -> 'a -> unit = "%array_safe_set"
  external unsafe_get : ('a, [> read] ) t -> int -> 'a         = "%array_unsafe_get"
  external unsafe_set : ('a, [> write]) t -> int -> 'a -> unit = "%array_unsafe_set"

  val create : len:int -> 'a -> ('a, [< _ perms]) t
  val init : int -> f:(int -> 'a) -> ('a, [< _ perms]) t
  val make_matrix
    :  dimx:int
    -> dimy:int
    -> 'a
    -> (('a, [< _ perms]) t, [< _ perms]) t
  val append : ('a, [> read]) t -> ('a, [> read]) t -> ('a, [< _ perms]) t
  val concat : ('a, [> read]) t list -> ('a, [< _ perms]) t
  val copy : ('a, [> read]) t -> ('a, [< _ perms]) t
  val fill : ('a, [> write]) t -> pos:int -> len:int -> 'a -> unit
  val of_list : 'a list -> ('a, [< _ perms]) t
  val map  : ('a, [> read]) t -> f:(       'a -> 'b) -> ('b, [< _ perms]) t
  val mapi : ('a, [> read]) t -> f:(int -> 'a -> 'b) -> ('b, [< _ perms]) t
  val folding_map
    :  ('a, [> read]) t
    -> init:'b
    -> f:('b -> 'a -> 'b * 'c)
    -> ('c, [< _ perms]) t
  val iteri : ('a, [> read]) t -> f:(int -> 'a -> unit) -> unit
  val foldi : ('a, [> read]) t -> init:'b -> f:(int -> 'b -> 'a -> 'b) -> 'b
  val folding_mapi
    :  ('a, [> read]) t
    -> init:'b
    -> f:(int -> 'b -> 'a -> 'b * 'c)
    -> ('c, [< _ perms]) t
  val fold_right : ('a, [> read]) t -> f:('a -> 'b -> 'b) -> init:'b -> 'b
  val sort
    :  ?pos:int
    -> ?len:int
    -> ('a, [> read_write]) t
    -> cmp:('a -> 'a -> int)
    -> unit
  val stable_sort        : ('a, [> read_write]) t -> cmp:('a -> 'a -> int) -> unit
  val is_sorted          : ('a, [> read]      ) t -> cmp:('a -> 'a -> int) -> bool
  val is_sorted_strictly : ('a, [> read]      ) t -> cmp:('a -> 'a -> int) -> bool
  val concat_map
    :  ('a, [> read]) t
    -> f:('a -> ('b, [> read]) t)
    -> ('b, [< _ perms]) t
  val concat_mapi
    :  ('a, [> read]) t
    -> f:(int -> 'a -> ('b, [> read]) t)
    -> ('b, [< _ perms]) t
  val partition_tf
    :  ('a, [> read]) t
    -> f:('a -> bool)
    -> ('a, [< _ perms]) t * ('a, [< _ perms]) t
  val partitioni_tf
    :  ('a, [> read]) t
    -> f:(int -> 'a -> bool)
    -> ('a, [< _ perms]) t * ('a, [< _ perms]) t
  val cartesian_product : ('a, [> read]) t -> ('b, [> read]) t -> ('a * 'b, [< _ perms]) t
  val transpose     : (('a, [> read]) t, [> read]) t -> (('a, [< _ perms]) t, [< _ perms]) t option
  val transpose_exn : (('a, [> read]) t, [> read]) t -> (('a, [< _ perms]) t, [< _ perms]) t
  val normalize : (_, _) t -> int -> int
  val slice : ('a, [> read]) t -> int -> int -> ('a, [< _ perms]) t
  val nget : ('a, [> read] ) t -> int -> 'a
  val nset : ('a, [> write]) t -> int -> 'a -> unit
  val filter_opt  : ('a option, [> read]) t -> ('a, [< _ perms]) t
  val filter_map  : ('a, [> read]) t -> f:(       'a -> 'b option) -> ('b, [< _ perms]) t
  val filter_mapi : ('a, [> read]) t -> f:(int -> 'a -> 'b option) -> ('b, [< _ perms]) t

  val for_alli : ('a, [> read]) t -> f:(int -> 'a -> bool) -> bool
  val existsi  : ('a, [> read]) t -> f:(int -> 'a -> bool) -> bool
  val counti   : ('a, [> read]) t -> f:(int -> 'a -> bool) -> int

  val iter2_exn : ('a, [> read]) t -> ('b, [> read]) t -> f:('a -> 'b -> unit) -> unit
  val map2_exn
    :  ('a, [> read]) t
    -> ('b, [> read]) t
    -> f:('a -> 'b -> 'c)
    -> ('c, [< _ perms]) t
  val fold2_exn
    :  ('a, [> read]) t
    -> ('b, [> read]) t
    -> init:'c
    -> f:('c -> 'a -> 'b -> 'c)
    -> 'c
  val for_all2_exn
    :  ('a, [> read]) t
    -> ('b, [> read]) t
    -> f:('a -> 'b -> bool)
    -> bool
  val exists2_exn
    :  ('a, [> read]) t
    -> ('b, [> read]) t
    -> f:('a -> 'b -> bool)
    -> bool
  val filter  : ('a, [> read]) t -> f:(       'a -> bool) -> ('a, [< _ perms]) t
  val filteri : ('a, [> read]) t -> f:(int -> 'a -> bool) -> ('a, [< _ perms]) t
  val swap : ('a, [> read_write]) t -> int -> int -> unit
  val rev_inplace : ('a, [> read_write]) t -> unit
  val of_list_rev     : 'a list -> ('a, [< _ perms]) t
  val of_list_map     : 'a list -> f:('a -> 'b) -> ('b, [< _ perms]) t
  val of_list_rev_map : 'a list -> f:('a -> 'b) -> ('b, [< _ perms]) t
  val replace     : ('a, [> read_write]) t -> int -> f:('a -> 'a) -> unit
  val replace_all : ('a, [> read_write]) t        -> f:('a -> 'a) -> unit
  val find_exn     : ('a, [> read]) t -> f:('a -> bool) -> 'a
  val find_map_exn : ('a, [> read]) t -> f:('a -> 'b option) -> 'b
  val findi     : ('a, [> read]) t -> f:(int -> 'a -> bool) -> (int * 'a) option
  val findi_exn : ('a, [> read]) t -> f:(int -> 'a -> bool) -> int * 'a
  val find_mapi     : ('a, [> read]) t -> f:(int -> 'a -> 'b option) -> 'b option
  val find_mapi_exn : ('a, [> read]) t -> f:(int -> 'a -> 'b option) -> 'b
  val find_consecutive_duplicate
    :  ('a, [> read]) t
    -> equal:('a -> 'a -> bool)
    -> ('a * 'a) option
  val reduce     : ('a, [> read]) t -> f:('a -> 'a -> 'a) -> 'a option
  val reduce_exn : ('a, [> read]) t -> f:('a -> 'a -> 'a) -> 'a
  val permute : ?random_state:Random.State.t -> ('a, [> read_write]) t -> unit
  val zip     : ('a, [> read]) t -> ('b, [> read]) t -> ('a * 'b, [< _ perms]) t option
  val zip_exn : ('a, [> read]) t -> ('b, [> read]) t -> ('a * 'b, [< _ perms]) t
  val unzip : ('a * 'b, [> read]) t -> ('a, [< _ perms]) t * ('b, [< _ perms]) t
  val sorted_copy : ('a, [> read]) t -> cmp:('a -> 'a -> int) -> ('a, [< _ perms]) t
  val last : ('a, [> read]) t -> 'a
  val empty : unit -> ('a, [< _ perms]) t
  [@@deprecated "[since 2017-05] Use [ [||] ]"]
  val equal : ('a, [> read]) t -> ('a, [> read]) t -> equal:('a -> 'a -> bool) -> bool
  val unsafe_truncate : (_, [> write]) t -> len:int -> unit

  val to_sequence         : ('a, [> read]) t -> 'a Sequence.t
  val to_sequence_mutable : ('a, [> read]) t -> 'a Sequence.t
end
