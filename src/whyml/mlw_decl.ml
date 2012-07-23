(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-2012                                               *)
(*    François Bobot                                                      *)
(*    Jean-Christophe Filliâtre                                           *)
(*    Claude Marché                                                       *)
(*    Guillaume Melquiond                                                 *)
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

open Why3
open Util
open Ident
open Ty
open Term
open Decl
open Mlw_ty
open Mlw_ty.T
open Mlw_expr

type constructor = plsymbol * plsymbol option list

type data_decl = itysymbol * constructor list

type pdecl = {
  pd_node : pdecl_node;
(*   pd_syms : Sid.t;         (* idents used in declaration *) *)
  pd_news : Sid.t;         (* idents introduced in declaration *)
  pd_tag  : int;           (* unique tag *)
}

and pdecl_node =
  | PDtype of itysymbol
  | PDdata of data_decl list
  | PDval  of let_sym
  | PDlet  of let_defn
  | PDrec  of rec_defn
  | PDexn  of xsymbol

let pd_equal : pdecl -> pdecl -> bool = (==)

let mk_decl =
  let r = ref 0 in
  fun node (*syms*) news ->
    incr r;
    { pd_node = node; (*pd_syms = syms;*) pd_news = news; pd_tag = !r; }

let news_id s id = Sid.add_new (Decl.ClashIdent id) id s

(*
let syms_ts s ts = Sid.add ts.ts_name s
let syms_ls s ls = Sid.add ls.ls_name s

let syms_ps s ps = Sid.add ps.ps_name s
let syms_xs s xs = Sid.add xs.xs_name s
let syms_pl s pl = Sid.add pl.pl_ls.ls_name s

let syms_its s its = Sid.add its.its_pure.ts_name s

let syms_ty s ty = ty_s_fold syms_ts s ty
let syms_term s t = t_s_fold syms_ty syms_ls s t

let syms_ity s ity = ity_s_fold syms_its syms_ts s ity

let syms_effect s eff =
  let add_raise xs s = syms_ity (syms_xs s xs) xs.xs_ity in
  let s = Sexn.fold add_raise eff.eff_raises s in
  let s = Sexn.fold add_raise eff.eff_ghostx s in
  s

let syms_post s q = syms_term s (term_of_post q)

let syms_xpost s xq =
  let add_xq xs q s = syms_post (syms_xs s xs) q in
  Mexn.fold add_xq xq s

let syms_varmap s m = Sid.union s (Mid.map (fun _ -> ()) m)

let rec syms_type_c s tyc =
  let s = syms_term s tyc.c_pre in
  let s = syms_post s tyc.c_post in
  let s = syms_xpost s tyc.c_xpost in
  let s = syms_effect s tyc.c_effect in
  syms_type_v s tyc.c_result

and syms_type_v s = function
  | SpecV vtv -> syms_ity s vtv.vtv_ity
  | SpecA (pvl,tyc) ->
      let add_pv s pv = syms_ity s pv.pv_vtv.vtv_ity in
      List.fold_left add_pv (syms_type_c s tyc) pvl

let rec syms_vta s a =
  let s = syms_ity s a.vta_arg.vtv_ity in
  let s = syms_effect s a.vta_effect in
  syms_vty s a.vta_result

and syms_vty s = function
  | VTvalue vtv -> syms_ity s vtv.vtv_ity
  | VTarrow vta -> syms_vta s vta

let syms_expr s _e = s (* TODO *)
*)

(** {2 Declaration constructors} *)

let create_ty_decl its =
(*   let syms = Util.option_fold syms_ity Sid.empty its.its_def in *)
  let news = Sid.singleton its.its_pure.ts_name in
  mk_decl (PDtype its) (*syms*) news

type pre_constructor = preid * (pvsymbol * bool) list

type pre_data_decl = itysymbol * pre_constructor list

let create_data_decl tdl =
(*   let syms = ref Sid.empty in *)
  let news = ref Sid.empty in
  let projections = Hid.create 17 in (* id -> plsymbol *)
  let build_constructor its (id,al) =
    (* check well-formedness *)
    let vtvs = List.map (fun (pv,_) -> pv.pv_vtv) al in
    let tvs = List.fold_right Stv.add its.its_args Stv.empty in
    let regs = List.fold_right Sreg.add its.its_regs Sreg.empty in
    let check_vars { vars_tv = atvs; vars_reg = aregs } =
      if not (Stv.subset atvs tvs) then
        raise (UnboundTypeVar (Stv.choose (Stv.diff atvs tvs)));
      if not (Sreg.subset aregs regs) then
        raise (UnboundRegion (Sreg.choose (Sreg.diff aregs regs))) in
    let check_arg vtv = match vtv.vtv_mut with
      | Some r -> if not (Sreg.mem r regs) then raise (UnboundRegion r)
      | None -> check_vars vtv.vtv_ity.ity_vars in
    List.iter check_arg vtvs;
    (* build the constructor ps *)
    let hidden = its.its_abst in
    let rdonly = its.its_priv in
    let tvl = List.map ity_var its.its_args in
    let res = vty_value (ity_app its tvl its.its_regs) in
    let pls = create_plsymbol ~hidden ~rdonly id vtvs res in
    news := news_id !news pls.pl_ls.ls_name;
    (* build the projections, if any *)
    let build_proj id vtv =
      try Hid.find projections id with Not_found ->
      let pls = create_plsymbol ~hidden (id_clone id) [res] vtv in
      news := news_id !news pls.pl_ls.ls_name;
      Hid.add projections id pls;
      pls
    in
    let build_proj (pv,pj) =
      let vtv = pv.pv_vtv in
(*       syms := ity_s_fold syms_its syms_ts !syms vtv.vtv_ity; *)
      if pj then Some (build_proj pv.pv_vs.vs_name vtv) else None
    in
    pls, List.map build_proj al
  in
  let build_type (its,cl) =
    Hid.clear projections;
    news := news_id !news its.its_pure.ts_name;
    its, List.map (build_constructor its) cl
  in
  let tdl = List.map build_type tdl in
  mk_decl (PDdata tdl) (*!syms*) !news

let check_vars vars =
  if not (Stv.is_empty vars.vars_tv) then
    raise (UnboundTypeVar (Stv.choose vars.vars_tv))

let letvar_news = function
  | LetV pv -> check_vars pv.pv_vars; Sid.singleton pv.pv_vs.vs_name
  | LetA ps -> check_vars ps.ps_vars; Sid.singleton ps.ps_name

let new_regs old_vars news vars =
  let on_reg r acc = Sreg.union r.reg_ity.ity_vars.vars_reg acc in
  let old_regs = reg_fold on_reg old_vars old_vars.vars_reg in
  let regs = reg_fold on_reg vars vars.vars_reg in
  let regs = Sreg.diff regs old_regs in
  Sreg.fold (fun r s -> news_id s r.reg_name) regs news

let create_let_decl ld =
  let vars = vars_merge ld.let_expr.e_varm vars_empty in
  let news = letvar_news ld.let_sym in
  let news = match ld.let_sym with
    | LetA ps -> new_regs vars news ps.ps_vars
    | LetV pv -> new_regs vars news pv.pv_vars in
(*
  let syms = syms_varmap Sid.empty ld.let_expr.e_vars in
  let syms = syms_effect syms ld.let_expr.e_effect in
  let syms = syms_vty syms ld.let_expr.e_vty in
  let syms = syms_expr syms ld.let_expr in
*)
  mk_decl (PDlet ld) (*syms*) news

let create_rec_decl ({ rec_defn = rdl } as d) =
  let add_rd s { fun_ps = p } =
    check_vars p.ps_vars; news_id s p.ps_name in
  let news = List.fold_left add_rd Sid.empty rdl in
(*
  let add_rd syms { rec_ps = ps; rec_lambda = l; rec_vars = vm } =
    let syms = syms_varmap syms vm in
    let syms = syms_vta syms ps.ps_vta in
    let syms = syms_term syms l.l_pre in
    let syms = syms_post syms l.l_post in
    let syms = syms_xpost syms l.l_xpost in
    let addv s { v_term = t; v_rel = ls } =
      Util.option_fold syms_ls (syms_term s t) ls in
    let syms = List.fold_left addv syms l.l_variant in
    syms_expr syms l.l_expr in
  let syms = List.fold_left add_rd Sid.empty rdl in
*)
  mk_decl (PDrec d) (*syms*) news

let create_val_decl lv =
  let news = letvar_news lv in
  let news = match lv with
    | LetV { pv_vtv = { vtv_mut = Some _ }} ->
        Loc.errorm "abstract parameters cannot be mutable"
    | LetV pv -> new_regs vars_empty news pv.pv_vars
    | LetA _ -> news in
(*
  let syms = syms_type_v Sid.empty vd.val_spec in
  let syms = syms_varmap syms vd.val_vars in
*)
  mk_decl (PDval lv) (*syms*) news

let create_exn_decl xs =
  let news = Sid.singleton xs.xs_name in
(*
  let syms = syms_ity Sid.empty xs.xs_ity in
*)
  mk_decl (PDexn xs) (*syms*) news

(** {2 Cloning} *)

let clone_data_decl sm pd = match pd.pd_node with
  | PDdata tdl ->
      let news = ref Sid.empty in
      let add_pl pl =
        let pl = Mls.find pl.pl_ls sm.sm_pls in
        news := news_id !news pl.pl_ls.ls_name;
        pl in
      let add_cs (cs,pjl) =
        add_pl cs, List.map (Util.option_map add_pl) pjl in
      let add_td (its,csl) =
        let its = Mits.find its sm.sm_its in
        news := news_id !news its.its_pure.ts_name;
        its, List.map add_cs csl in
      let tdl = List.map add_td tdl in
      mk_decl (PDdata tdl) (*!syms*) !news
  | _ -> invalid_arg "Mlw_decl.clone_data_decl"

(** {2 Known identifiers} *)

type known_map = pdecl Mid.t

let known_id kn id =
  if not (Mid.mem id kn) then raise (UnknownIdent id)

let merge_known kn1 kn2 =
  let check_known id decl1 decl2 =
    if pd_equal decl1 decl2 then Some decl1
    else raise (RedeclaredIdent id)
  in
  Mid.union check_known kn1 kn2

let known_add_decl _lkn0 kn0 decl =
  let kn = Mid.map (const decl) decl.pd_news in
  let check id decl0 _ =
    if pd_equal decl0 decl
    then raise (KnownIdent id)
    else raise (RedeclaredIdent id)
  in
  let kn = Mid.union check kn0 kn in
(*
  let unk = Mid.set_diff decl.pd_syms kn in
  let unk = Mid.set_diff unk lkn0 in
  if Sid.is_empty unk then kn
  else raise (UnknownIdent (Sid.choose unk))
*)
  kn

(* TODO: known_add_decl must check pattern matches for exhaustiveness *)

let find_constructors kn its =
  match (Mid.find its.its_pure.ts_name kn).pd_node with
  | PDtype _ -> []
  | PDdata dl -> List.assq its dl
  | PDval _ | PDlet _ | PDrec _ | PDexn _ -> assert false
