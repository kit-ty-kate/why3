(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2014   --   INRIA - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

(* C program extraction *)

val extract_filename: ?fname:string -> Theory.theory -> string

val extract_theory:
  Mlw_driver.driver -> ?fname:string ->
  Format.formatter -> Theory.theory -> unit

val extract_module:
  Mlw_driver.driver -> ?fname:string ->
  Format.formatter -> Mlw_module.modul -> unit

val finalize : unit -> unit
