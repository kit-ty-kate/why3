(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-                                                   *)
(*    Francois Bobot                                                      *)
(*    Jean-Christophe Filliatre                                           *)
(*    Johannes Kanig                                                      *)
(*    Andrei Paskevich                                                    *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Why

type loc = Loc.position

type ident = Ptree.ident

type qualid = Ptree.qualid

type constant = Term.constant

type assertion_kind = Aassert | Aassume | Acheck

type lexpr = Ptree.lexpr

type lazy_op = LazyAnd | LazyOr

type loop_annotation = {
  loop_invariant : lexpr option;
  loop_variant   : lexpr option;
}

type type_v =
  | Tpure of Ptree.pty
  (* | Tarrow of (ident * type_v) list * type_c *)

(*
and type_c =
  { pc_result_name : Ident.t;
    pc_result_type : ptype_v;
    pc_effect : peffect;
    pc_pre    : assertion list;
    pc_post   : postcondition option }
*)

type expr = {
  expr_desc : expr_desc;
  expr_loc  : loc;
}

and expr_desc =
  (* lambda-calculus *)
  | Econstant of constant
  | Eident of qualid
  | Eapply of expr * expr
  | Elet of ident * expr * expr
  (* control *)
  | Esequence of expr * expr
  | Eif of expr * expr * expr
  | Ewhile of expr * loop_annotation * expr
  | Elazy of lazy_op * expr * expr
  | Eskip 
  | Eabsurd
  (* annotations *)
  | Eassert of assertion_kind * lexpr
  | Eghost of expr
  | Elabel of ident * expr
  | Ecast of expr * Ptree.pty


  (* TODO: fun, rec, raise, try, absurd, any, post? *)

type decl =
  | Dcode  of ident * expr
  | Dlogic of Ptree.decl list

type file = decl list

