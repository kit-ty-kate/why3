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

(**
   Implementation details:
    * All values are boxed where « typename void* value; »
    * Exceptions handled with a monadic method: all functions which can return
      an exception will have a last parameter « struct Exn *exn » where Exn is
      « struct Exn {
          const *name;
          value args[];
        };
      »
    * Variants are encoded like:
      « struct Variant {
          int key;
          value args[];
        };
      »
    * Records can be encoded with C structs
    * We'll use the Boehm GC
*)

open Format
open Pp

open Stdlib
open Number
open Ident
open Ty
open Term
open Decl
open Theory
open Printer

module Module = Mlw_c_module

(* TODO: Remove this hack *)
let hack_fmt = ref None

let clean_fname fname =
  let fname = Filename.basename fname in
  (try Filename.chop_extension fname with _ -> fname)

let modulename ?(separator="__") ?fname path t =
  let fname = match fname, path with
    | Some fname, _ -> clean_fname fname
    | None, [] -> "why3"
    | None, _ -> String.concat separator path
  in
  fname ^ separator ^ t

let extract_filename ?fname th =
  (modulename ?fname th.th_path th.th_name.Ident.id_string) ^ ".c"

type info = {
  info_syn: syntax_map;
  converters: syntax_map;
  current_theory: Theory.theory;
  current_module: Mlw_module.modul option;
  th_known_map: Decl.known_map;
  mo_known_map: Mlw_decl.known_map;
  fname: string option;
}

type value =
  | Value of Module.value
  | ValueRec of (Module.value * int)
  | Env of int

let get_qident ?(separator="__") info id =
  try
    let lp, t, p =
      try Mlw_module.restore_path id
      with Not_found -> Theory.restore_path id in
    let s = String.concat separator p in
    let s = Ident.sanitizer char_to_alpha char_to_alnumus s in
    let fname = if lp = [] then info.fname else None in
    let m = modulename ~separator ?fname lp t in
    Module.value_of_string (sprintf "%s%s%s" m separator s)
  with Not_found ->
    assert false (* TODO: Know what to do *)

let get_ls info ls = get_qident info ls.ls_name

let protect_on x s = if x then "(" ^^ s ^^ ")" else s

let has_syntax info id = Mid.mem id info.info_syn

let has_syntax_or_nothing info id =
  if not (has_syntax info id) then
    assert false

let print_const = function
  | ConstInt c ->
      (* Use GMP:
         let f () =
           let x = 1 in
           x
         <=>
         void *M_f(void *, void * ) {
           mpz_t *__fresh_var; (* WHAT ABOUT THE GC *)
           mpz_init(__fresh_var);
           mpz_set_si(__fresh_var, 1);
           void *x = (void* )&__fresh_var; (* PROBLEM *)
           return x;
         }
      *)
      assert false
  | ConstReal _ ->
      assert false

let print_if f builder (e,t1,t2) =
  let e = f e builder in
  let res = Module.create_value "NULL" builder in
  Module.append_block
    (sprintf "if(%s == __True)" (Module.string_of_value e))
    (fun builder ->
       let v = f t1 builder in
       Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value v)) builder
    )
    builder;
  Module.append_block
    "else"
    (fun builder ->
       let v = f t2 builder in
       Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value v)) builder
    )
    builder;
  res

let get_value id gamma builder =
  match Mid.find_opt id gamma with
  | None ->
      Module.value_of_string id.id_string
  | Some v ->
      begin match v with
      | Value v ->
          v
      | Env i ->
          Module.create_value (sprintf "Env__[%d]" i) builder
      | ValueRec (value, i) ->
          Module.create_value (sprintf "%s[%d]" (Module.string_of_value value) i) builder
      end

let bool_not b =
  Module.create_value (sprintf "((variant *)(%s)->key) ? __False : __True" (Module.string_of_value b))

let rec print_term info gamma t builder = match t.t_node with
  | Tvar v ->
      assert false
  | Tconst c ->
      print_const c
  | Tapp (fs, []) ->
      get_value fs.ls_name gamma builder
  | Tapp (fs, tl) ->
      assert false
  | Tif (e, t1, t2) ->
      print_if (print_term info gamma) builder (e, t1, t2)
  | Tlet (t1,tb) ->
      assert false
  | Tcase (t1,bl) ->
      assert false
  | Teps _
  | Tquant _ ->
      assert false
  | Ttrue ->
      Module.create_value "__True" builder
  | Tfalse ->
      Module.create_value "__False" builder
  | Tbinop (Timplies,f1,f2) ->
      let f1 = print_term info gamma f1 builder in
      let res = bool_not f1 builder in
      Module.append_block
        (sprintf "if(%s == __True)" (Module.string_of_value f1))
        (fun builder ->
           let v = print_term info gamma f2 builder in
           Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value v)) builder
        )
        builder;
      res
  | Tbinop (Tand,f1,f2) ->
      let f1 = print_term info gamma f1 builder in
      let res = Module.create_value (Module.string_of_value f1) builder in
      Module.append_block
        (sprintf "if(%s == __True)" (Module.string_of_value f1))
        (fun builder ->
           let v = print_term info gamma f2 builder in
           Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value v)) builder
        )
        builder;
      res
  | Tbinop (Tor,f1,f2) ->
      let f1 = print_term info gamma f1 builder in
      let res = Module.create_value (Module.string_of_value f1) builder in
      Module.append_block
        (sprintf "if(%s == __False)" (Module.string_of_value f1))
        (fun builder ->
           let v = print_term info gamma f2 builder in
           Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value v)) builder
        )
        builder;
      res
  | Tbinop (Tiff,f1,f2) ->
      let f1 = print_term info gamma f1 builder in
      let f2 = print_term info gamma f2 builder in
      Module.create_value (sprintf "%s == %s" (Module.string_of_value f1) (Module.string_of_value f2)) builder
  | Tnot f ->
      let v = print_term info gamma f builder in
      bool_not v builder

(*let print_logic_decl info (ls, ld) =*)

(** Logic Declarations *)

let logic_decl info builder d = match d.d_node with
  | Dtype _
  | Ddata _ ->
      () (* Types are useless for C *)
  | Decl.Dparam ls ->
(*      print_qident info fmt ls.ls_name;*)
      () (* Why is it a non_executable code ? *)
  | Dlogic ll ->
      () (* TODO *)
  | Dind (s, il) ->
      assert false
  | Dprop (_pk, _pr, _) ->
      assert false

let logic_decl info builder td = match td.td_node with
  | Decl d ->
      begin match Mlw_extract.get_exec_decl info.info_syn d with
      | Some d ->
          let union = Sid.union d.d_syms d.d_news in
          let inter = Mid.set_inter union info.mo_known_map in
          if Sid.is_empty inter then logic_decl info builder d
      | None ->
          ()
      end
  | Use _ | Clone _ | Meta _ ->
      ()

(** Theories *)

let extract_theory drv ?old ?fname fmt th =
  hack_fmt := Some fmt;
  ignore (old); ignore (fname);
  let info = {
    info_syn = drv.Mlw_driver.drv_syntax;
    converters = drv.Mlw_driver.drv_converter;
    current_theory = th;
    current_module = None;
    th_known_map = th.th_known;
    mo_known_map = Mid.empty;
    fname = Opt.map clean_fname fname; } in
  let builder = Module.init_builder in
  List.iter (logic_decl info builder) th.th_decls

(** Programs *)

open Mlw_ty
open Mlw_ty.T
open Mlw_expr
open Mlw_decl
open Mlw_module

let get_pv info pv =
  if pv.pv_ghost then
    Module.unit_value
  else
    get_qident info pv.pv_vs.vs_name
let get_ps info ps =
  if ps.ps_ghost then
    Module.unit_value
  else
    get_qident info ps.ps_name
let get_lv info = function
  | LetV pv -> get_pv info pv
  | LetA ps -> get_ps info ps

let get_xs ?separator info xs = get_qident ?separator info xs.xs_name

let rec print_expr info ~raise_expr gamma e builder =
  if e.e_ghost then
    Module.unit_value
  else match e.e_node with
  | Elogic t ->
      print_term info gamma t builder
  | Evalue v ->
      get_pv info v
  | Earrow a ->
      assert false
  | Eapp (e,v,_) ->
      assert false
  | Elet ({ let_expr = e1 }, e2) when e1.e_ghost ->
      assert false
  | Elet ({ let_sym = lv ; let_expr = e1 }, e2) ->
      assert false
  | Eif (e0, e1, { e_node = Elogic { t_node = Tapp (ls, []) }})
    when ls_equal ls fs_void ->
      assert false
  | Eif (e0,e1,e2) ->
      print_if (print_expr info ~raise_expr gamma) builder (e0, e1, e2)
  | Eassign (pl,e,_,pv) ->
      assert false
  | Eloop (_,_,e) ->
      let exn = Module.create_exn builder in
      Module.append_block
        "while(true)"
        (fun builder ->
           let new_raise_expr value builder =
             Module.append_expr
               (sprintf "%s = %s" (Module.string_of_value exn) (Module.string_of_value value))
               builder;
             Module.append_expr "break" builder;
           in
           ignore (print_expr info ~raise_expr:new_raise_expr gamma e builder)
        )
        builder;
      Module.append_block
        (sprintf "if(%s != NULL)" (Module.string_of_value exn))
        (fun builder -> raise_expr exn builder)
        builder;
      Module.unit_value
  | Efor (pv,(pvfrom,dir,pvto),_,e) ->
      assert false
  | Eraise (xs,e) ->
      let e = print_expr info ~raise_expr gamma e builder in
      let value = Module.malloc_exn builder in
      Module.append_expr (sprintf "%s->key = tag_%s" (Module.string_of_value value) (Module.string_of_value (get_xs info xs))) builder;
      Module.append_expr (sprintf "%s->val = %s" (Module.string_of_value value) (Module.string_of_value e)) builder;
      raise_expr value builder;
      Module.null_value
  | Etry (e,bl) ->
      let exn = Module.create_exn builder in
      let res = Module.create_value "NULL" builder in
      Module.append_block
        "do"
        (fun builder ->
           let new_raise_expr value builder =
             Module.append_expr
               (sprintf "%s = %s" (Module.string_of_value exn) (Module.string_of_value value))
               builder;
             Module.append_expr "break" builder;
           in
           let value = print_expr info ~raise_expr:new_raise_expr gamma e builder in
           Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value value)) builder;
        )
        builder;
      Module.append_expr "while(false)" builder;
      Module.append_block
        (sprintf "if(%s != NULL)" (Module.string_of_value exn))
        (fun builder ->
           List.iteri
             (fun i x ->
                print_xbranch info ~first:(i = 0) gamma ~raise_expr ~exn ~res x builder;
                Module.append_block "else" (raise_expr exn) builder;
             )
             bl
        )
        builder;
      Module.unit_value
  | Eabstr (e,_) ->
      print_expr info ~raise_expr gamma e builder
  | Eabsurd ->
      Module.append_expr "abort()" builder;
      Module.null_value
  | Eassert _ ->
      Module.unit_value
  | Eghost _ ->
      assert false
  | Eany _ ->
      assert false
  | Ecase (e1, [_,e2]) when e1.e_ghost ->
      print_expr info ~raise_expr gamma e2 builder
  | Ecase (e1, bl) ->
      assert false
  | Erec (fdl, e) ->
      let aux index fd =
        let local_arr = Module.create_array (List.length fdl) builder in
        let store = Module.value_of_string (sprintf "%s[%d]" (Module.string_of_value local_arr) index) in
        if not fd.fun_ps.ps_ghost then begin
          let v = print_rec info ~env:Module.null_value builder gamma fd in
          Module.append_expr (sprintf "%s = %s" (Module.string_of_value store) (Module.string_of_value v)) builder;
        end
      in
      Lists.iteri aux fdl;
      print_expr info ~raise_expr gamma e builder

and print_rec info ~env builder gamma { fun_ps = ps ; fun_lambda = lam } =
  let lambda =
    Module.create_lambda
      ~raises:(not (Sexn.is_empty ps.ps_aty.aty_spec.c_effect.eff_raises))
      (fun ~raise_expr ->
         let gamma = Mid.add ps.ps_name (Value (Module.value_of_string "Param__0")) gamma in
         print_expr info ~raise_expr gamma lam.l_expr
      )
  in
  Module.create_closure ~lambda ~env builder

and print_xbranch info ~first gamma ~raise_expr ~exn ~res (xs, pv, e) builder =
  if ity_equal xs.xs_ity ity_unit then
    Module.append_block
      (sprintf "%sif(%s->key == tag_%s)" (if first then "" else "else ") (Module.string_of_value exn) (Module.string_of_value (get_xs info xs)))
      (fun builder ->
         let value = print_expr info ~raise_expr gamma e builder in
         Module.append_expr (sprintf "%s = %s" (Module.string_of_value res) (Module.string_of_value value)) builder;
      )
      builder
  else
    (* TODO: Handle params *)
    assert false

and print_rec_decl info gamma builder fdl =
  let aux fd =
    let store = get_ps info fd.fun_ps in
    Module.define_global store;
    if not fd.fun_ps.ps_ghost then begin
      let v = print_rec info ~env:Module.null_value builder gamma fd in
      Module.append_expr (sprintf "%s = %s" (Module.string_of_value store) (Module.string_of_value v)) builder;
    end
  in
  List.iter aux fdl
  (*forget_tvs ()*)

let is_ghost_lv = function
  | LetV pv -> pv.pv_ghost
  | LetA ps -> ps.ps_ghost

(* TODO: Handle driver *)
let print_exn_decl info xs =
  Module.append_global
    (sprintf "exn_tag tag_%s" (Module.string_of_value (get_xs info xs)))
    (sprintf "\"%s\"" (Module.string_of_value (get_xs ~separator:"." info xs)))

let rec pdecl info gamma builder = function
  | pd::decls ->
      Mlw_extract.check_exec_pdecl info.info_syn pd;
      begin match pd.pd_node with
      | PDtype ts ->
          (* TODO *)
          pdecl info gamma builder decls
      | PDdata tl ->
          (* TODO *)
          pdecl info gamma builder decls
      | PDval lv ->
          (* TODO *)
          pdecl info gamma builder decls
      | PDlet ld ->
          (* TODO *)
          pdecl info gamma builder decls
      | PDrec fdl ->
          print_rec_decl info gamma builder fdl;
          pdecl info gamma builder decls
      | PDexn xs ->
          print_exn_decl info xs;
          pdecl info gamma builder decls
      end
  | [] ->
      ()

(** Modules *)

let extract_module drv ?old ?fname fmt m =
  hack_fmt := Some fmt;
  ignore (old); ignore (fname);
  let th = m.mod_theory in
  let info = {
    info_syn = drv.Mlw_driver.drv_syntax;
    converters = drv.Mlw_driver.drv_converter;
    current_theory = th;
    current_module = Some m;
    th_known_map = th.th_known;
    mo_known_map = m.mod_known;
    fname = Opt.map clean_fname fname; } in
  let builder = Module.init_builder in
  pdecl info Mid.empty builder m.mod_decls

let finalize () =
  match !hack_fmt with
  | None ->
      ()
  | Some fmt ->
      fprintf fmt "%s" (Module.to_string ())
