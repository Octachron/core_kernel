(** This module extends {!Base.Maybe_bound} with bin_io and with compare functions in the
    form of [As_lower_bound] and [As_upper_bound] modules. *)

type 'a t = 'a Base.Maybe_bound.t = Incl of 'a | Excl of 'a | Unbounded
[@@deriving bin_io]

include module type of struct include Base.Maybe_bound end
  with type 'a t := 'a t (** @open *)

(** Compares [t] values as lower bounds, where [Unbounded] is lowest, [Incl x < Excl x],
    and other cases of [Incl] and/or [Excl] are compared based on ['a].  If
    [As_lower_bound.compare compare t1 t2 <= 0] and [is_lower_bound t2 ~of_:a ~compare],
    then [is_lower_bound t1 ~of_:a ~compare].  For example, for [int As_lower_bound.t]:

    {[
      Unbounded < ... < Incl 13 < Excl 13 < Incl 14 < Excl 14 < ...
    ]} *)
module As_lower_bound : sig
  type nonrec 'a t = 'a t [@@deriving compare]
end

(** Compares [t] values as upper bounds, where [Unbounded] is highest, [Incl x > Excl x],
    and other cases of [Incl] and/or [Excl] are compared based on ['a].  If
    [As_upper_bound.compare compare_a t1 t2 <= 0] and [is_upper_bound t1 ~of_:a ~compare],
    then [is_upper_bound t2 ~of_:a ~compare].  For example, for [int As_upper_bound.t]:

    {[
      ... < Excl 13 < Incl 13 < Excl 14 < Incl 14 < ... < Unbounded
    ]} *)
module As_upper_bound : sig
  type nonrec 'a t = 'a t [@@deriving compare]
end

module Stable : sig
  module V1 : Stable_module_types.S1 with type 'a t = 'a t
end
