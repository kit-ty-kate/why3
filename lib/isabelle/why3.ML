signature WHY3 =
sig
  val setup: theory -> theory
end

structure Why3: WHY3 =
struct

(**** XML utilities ****)

fun get_opt_att s atts = AList.lookup (op =) atts s;

fun get_att s atts = (case get_opt_att s atts of
    SOME x => x
  | NONE => error ("Missing attribute " ^ s));

fun get_att_default x s atts = (case get_opt_att s atts of
    SOME y => y
  | NONE => x);

fun get_name atts = get_att "name" atts;

fun get_name'' atts =
  case (get_opt_att "path" atts, get_opt_att "altname" atts) of
    (SOME s, SOME s') => SOME (s, s')
  | _ => NONE;

fun get_name' atts = (get_name atts, get_name'' atts);

fun variant fs (XML.Elem ((s, atts), ts)) =
      (case AList.lookup (op =) fs s of
         SOME f => (f atts ts handle General.Match =>
           error ("Failed to parse element " ^ s))
       | NONE => error ("Bad element: " ^ s))
  | variant _ _ = error "Element expected";

fun elem s f (XML.Elem ((s', atts), ts)) =
      if s = s' then f atts ts
      else error ("Element " ^ s ^ " expected")
  | elem _ _ _ = error "Element expected";

fun optional _ x [] = x
  | optional f _ [x] = f x;

fun option _ [] = NONE
  | option f [x] = SOME (f x);

fun get_bool s atts = (case get_att_default "false" s atts of
    "false" => false
  | "true" => true
  | _ => error "Bad value for boolean attribute");

fun strip_whspc (XML.Elem (p, ts)) =
      SOME (XML.Elem (p, map_filter strip_whspc ts))
  | strip_whspc (txt as XML.Text s) =
      if forall Symbol.is_blank (raw_explode s)
      then NONE else SOME txt;

fun parse_xml s =
  (case strip_whspc (XML.parse s) of
     SOME x => x
   | NONE => error "Bad input");


(**** terms and types ****)

(* replace occurrences of dummy_pattern by distinct variables *)
fun replace_dummies (Const (@{const_name dummy_pattern}, T)) used =
      let val (x, used') = Name.variant "x" used
      in (Free (x, T), used') end
  | replace_dummies (t $ u) used =
      let
        val (t', used') = replace_dummies t used;
        val (u', used'') = replace_dummies u used';
      in (t' $ u', used'') end
  | replace_dummies t used = (t, used);

fun make_case t ps =
  Syntax.const @{const_name case_guard} $ @{term True} $ t $
  fold_rev (fn (l, r) => fn u =>
      let val (l', _) = replace_dummies l
        (Name.context |>
         Term.declare_term_frees l |>
         Term.declare_term_frees r)
      in
        Syntax.const @{const_name case_cons} $
        fold (fn p => fn b =>
            Syntax.const @{const_name case_abs} $
            Term.absfree p b)
          (Term.add_frees l' [])
          (Syntax.const @{const_name case_elem} $ l' $ r) $ u
      end)
    ps (Syntax.const @{const_name case_nil});

val get_tvar = prefix "'" o get_name;

fun typ f = variant
  [("type", fn atts => fn Ts => Type (f atts, map (typ f) Ts)),
   ("tvar", fn atts => fn [] => TFree (get_tvar atts, dummyS)),
   ("fun", fn _ => fn Ts as _ :: _ => op ---> (split_last (map (typ f) Ts))),
   ("pred", fn _ => fn Ts => map (typ f) Ts ---> @{typ bool}),
   ("prodt", K
      (fn [] => HOLogic.unitT
        | Ts => foldr1 HOLogic.mk_prodT (map (typ f) Ts)))];

fun term f g = variant
  [("const", fn atts => fn Ts =>
      Const (f atts, optional (typ g) dummyT Ts)),
   ("var", fn atts => fn Ts =>
      Free (get_name atts, optional (typ g) dummyT Ts)),
   ("abs", fn atts => fn [T, t] =>
      Term.absfree (get_name atts, typ g T) (term f g t)),
   ("app", fn _ => fn t :: ts => list_comb (term f g t, map (term f g) ts)),
   ("num", fn atts => fn Ts => HOLogic.mk_number
      (optional (typ g) dummyT Ts)
      (case Int.fromString (get_att "val" atts) of SOME i => i)),
   ("case", fn _ => fn t :: ps => make_case (term f g t)
      (map (elem "pat" (K (fn [l, r] => (term f g l, term f g r)))) ps)),
   ("prod", K
      (fn [] => HOLogic.unit
        | ts => foldr1 (fn (t, u) => Syntax.const @{const_name Pair} $ t $ u)
            (map (term f g) ts)))];


(**** declarations ****)

type name' = (string * string) option
type name = string * name'

datatype decl =
    Lemma of name * term list * term list
  | Axiom of name * term list
  | Typedecl of name * string list * typ option
  | Param of name * typ
  | Definition of name' * term
  | Datatype of (name * string list * (name * typ list) list) list
  | Inductive of bool * (name * typ * (name * term) list) list
  | Function of (name' * term list) list

fun err_unfinished () = error "An unfinished Why3 environment is still open.";
fun err_no_env () = error "No Why3 environment is currently open.";

type tables =
  {consts: string Symtab.table,
   types: string Symtab.table,
   thms: thm list Symtab.table,
   defs: thm list Symtab.table}

val empty_tables =
  {consts = Symtab.empty,
   types = Symtab.empty,
   thms = Symtab.empty,
   defs = Symtab.empty};

fun map_consts f {consts, types, thms, defs} =
  {consts = f consts, types = types, thms = thms, defs = defs};

fun map_types f {consts, types, thms, defs} =
  {consts = consts, types = f types, thms = thms, defs = defs};

fun map_thms f {consts, types, thms, defs} =
  {consts = consts, types = types, thms = f thms, defs = defs};

fun map_defs f {consts, types, thms, defs} =
  {consts = consts, types = types, thms = thms, defs = f defs};

fun merge_tables
  ({consts = consts1, types = types1, thms = thms1, defs = defs1},
   {consts = consts2, types = types2, thms = thms2, defs = defs2}) =
  {consts = Symtab.merge (op =) (consts1, consts2),
   types = Symtab.merge (op =) (types1, types2),
   thms = Symtab.merge (eq_list Thm.eq_thm_strict) (thms1, thms2),
   defs = Symtab.merge (eq_list Thm.eq_thm_strict) (defs1, defs2)};

structure Why3_Data = Theory_Data
(
  type T =
    {theories: tables Symtab.table,
     env:
       {thyname: string,
        decls: decl list,
        vcs: (thm list option * term list * term list) Symtab.table} option}
  val empty : T = {theories = Symtab.empty, env = NONE}
  val extend = I
  fun merge ({theories = theories1, env = NONE},
        {theories = theories2, env = NONE}) =
        {theories = Symtab.join (K merge_tables) (theories1, theories2),
         env = NONE}
    | merge _ = err_unfinished ()
)

fun lookup_vc thy name =
  (case Why3_Data.get thy of
     {env = SOME {vcs, ...}, ...} => Symtab.lookup vcs name
   | _ => NONE);

val is_closed = is_none o #env o Why3_Data.get;

fun mk_vc name_concl prems concls =
  (Element.Assumes (map_index (fn (i, t) =>
     ((Binding.name ("H" ^ string_of_int (i + 1)), []), [(t, [])])) prems),
   Element.Shows (map_index (fn (i, t) =>
     (if name_concl then (Binding.name ("C" ^ string_of_int (i + 1)), [])
      else Attrib.empty_binding,
      [(t, [HOLogic.mk_Trueprop
          (Var (("C", i + 1), HOLogic.boolT))])])) concls));

fun get_vc thy vc_name =
  (case lookup_vc thy vc_name of
    SOME (proved, prems, concls) =>
      if is_some proved then
        error ("The verification condition " ^
          quote vc_name ^ " has already been proved.")
      else mk_vc false prems concls
  | NONE => error ("There is no verification condition " ^
      quote vc_name ^ "."));

fun pp_vcs msg vcs = Pretty.big_list msg (map (Pretty.str o fst) vcs);

fun pp_open_vcs [] = Pretty.str "All verification conditions have been proved."
  | pp_open_vcs vcs = pp_vcs
      "The following verification conditions remain to be proved:" vcs;

fun partition_vcs vcs = Symtab.fold_rev
  (fn (name, (SOME thms, ps, cs)) =>
        apfst (cons (name, (thms, ps, cs)))
    | (name, (NONE, ps, cs)) =>
        apsnd (cons (name, (ps, cs))))
  vcs ([], []);

fun insert_break prt = Pretty.blk (0, [Pretty.fbrk, prt]);

fun print_open_vcs f vcs =
  (Pretty.writeln (f (pp_open_vcs (snd (partition_vcs vcs)))); vcs);

fun mark_proved name thms = Why3_Data.map (fn
    {theories,
     env = SOME {thyname, decls, vcs}} =>
      {theories = theories,
       env = SOME {thyname = thyname, decls = decls,
         vcs = print_open_vcs insert_break (Symtab.map_entry name
           (fn (_, ps, cs) => (SOME thms, ps, cs)) vcs)}}
  | x => x);

fun add_name kind sel th (p as (x, _)) tab =
  Symtab.map_default (th, empty_tables) (sel (Symtab.update_new p)) tab
  handle Symtab.DUP _ =>
    error ("The " ^ kind ^ " " ^ x ^ " is already defined.");

fun add_item add opt_thyname p = Why3_Data.map
  (fn {theories, env} =>
     {theories = add
        (case (env, opt_thyname) of
           (SOME {thyname, ...}, NONE) => thyname
         | (NONE, SOME thyname) => thyname
         | (NONE, NONE) => err_no_env ()
         | (SOME _, SOME _) => err_unfinished ())
        p theories,
      env = env});

fun add_item_intern add intrn s thy = add_item add NONE (s, intrn thy s) thy;

val add_const = add_item_intern (add_name "constant" map_consts) Sign.intern_const;
val add_type = add_item_intern (add_name "type" map_types) Sign.intern_type;

val add_const_raw = add_item (add_name "constant" map_consts);
val add_type_raw = add_item (add_name "type" map_types);
val add_thm_raw = add_item (add_name "theorem" map_thms);
val add_def_raw = add_item (add_name "definition" map_defs);

fun add_qualified add prep (s, x) thy =
  (Long_Name.is_qualified s orelse
   error ("Qualified name expected, but " ^ s ^ " was found");
   add (SOME (Long_Name.qualifier s))
     (Long_Name.base_name s, prep (Proof_Context.init_global thy) x) thy);

val add_why3_const = add_qualified add_const_raw (fn ctxt => fn cname =>
  fst (dest_Const (Proof_Context.read_const_proper ctxt false cname)));

val add_why3_type = add_qualified add_type_raw (fn ctxt => fn tyname =>
  fst (dest_Type (Proof_Context.read_type_name_proper ctxt false tyname)));

val add_why3_thm = add_qualified add_thm_raw Attrib.eval_thms;

val add_why3_def = add_qualified add_def_raw Attrib.eval_thms;

fun lookup_name kind sel tab s s' = (case Symtab.lookup tab s of
    NONE => error ("The theory " ^ s ^ " was not found")
  | SOME tab' => (case Symtab.lookup (sel tab') s' of
        NONE => error ("The " ^ kind ^ " " ^ s' ^
          " was not found in theory " ^ s)
      | SOME name => name));

fun lookup_const tab = lookup_name "constant" #consts tab;
fun lookup_type tab = lookup_name "type" #types tab;

fun lookup_name' sel thy (SOME (s, s')) =
      (case Symtab.lookup (#theories (Why3_Data.get thy)) s of
         NONE => NONE
       | SOME tab' => (case Symtab.lookup (sel tab') s' of
             NONE => NONE
           | SOME name => SOME name))
  | lookup_name' _ _ NONE = NONE;

fun lookup_const' thy = lookup_name' #consts thy;
fun lookup_type' thy = lookup_name' #types thy;
fun lookup_thm thy = lookup_name' #thms thy;
fun lookup_def thy = lookup_name' #defs thy;

fun prep_name lookup ctxt atts =
  (case Why3_Data.get (Proof_Context.theory_of ctxt) of
     {theories, env = SOME {thyname, ...}} =>
       let val name = get_name atts
       in case (get_bool "local" atts, get_opt_att "path" atts) of
           (false, NONE) => name
         | (true, _) => lookup theories thyname name
         | (_, SOME thyname') => lookup theories thyname' name
       end
   | _ => err_no_env ());

fun read_type ctxt x = Syntax.check_typ ctxt
  (typ (prep_name lookup_type ctxt) x);

fun read_term ctxt x = Syntax.check_term ctxt
  (term (prep_name lookup_const ctxt) (prep_name lookup_type ctxt) x);

fun read_prop ctxt x = HOLogic.mk_Trueprop (read_term ctxt x);

fun prep_datatypes ctxt dts =
  let val ctxt' = fold (fn ((s, _), args, _) =>
    Typedecl.basic_typedecl (Binding.name s, length args, NoSyn) #>
    snd #> Local_Theory.background_theory (add_type s)) dts ctxt
  in map (fn (b, args, constrs) =>
    (b, args, map (apsnd (map (read_type ctxt'))) constrs)) dts
  end;

fun read_statement ctxt f atts [prems, concls] = f
  (get_name' atts,
   elem "prems" (K (map (read_prop ctxt))) prems,
   elem "concls" (K (map (read_prop ctxt))) concls);

val read_ty_params = elem "params" (K (map (elem "param" (K o get_tvar))));

val gen_head_of_eqn =
  HOLogic.dest_Trueprop #> HOLogic.dest_eq #> fst #> head_of;

val head_of_eqn = gen_head_of_eqn #> dest_Free;
val head_of_eqn' = gen_head_of_eqn #> dest_Const;

fun globalize f thy =
  Local_Theory.exit_global (f (Named_Target.theory_init thy));

(* split up term containing case combinators into several terms *)
fun expand_cases ctxt t =
  let
    fun rename fmap = Term.map_aterms
      (fn Free (s, T) => Free (the_default s (AList.lookup (op =) fmap s), T)
        | t => t);

    fun rename_case used (l, r) =
      let val (fmap, _) = fold_map
        (fn s => apfst (pair s) o Name.variant s)
        (Term.add_free_names l []) used
      in (rename fmap l, rename fmap r) end;

    fun strip_case used t =
      if null (loose_bnos t)
      then (case Case_Translation.strip_case ctxt false t of
          SOME (u as Free _, ps) => SOME (u, map (rename_case used) ps)
        | _ => NONE)
      else NONE;

    fun mk_ctxt f = Option.map (fn (x, ps) => (x, map (apsnd f) ps));

    fun strip_case' used t = (case strip_case used t of
        NONE => (case t of
            t1 $ t2 => (case strip_case' used t1 of
                NONE => mk_ctxt (fn u => t1 $ u) (strip_case' used t2)
              | p => mk_ctxt (fn u => u $ t2) p)
          | Abs (s, T, r) => mk_ctxt (fn u => Abs (s, T, u))
              (strip_case' used r)
          | _ => NONE)
      | p => p);

    fun expand t =
      (case strip_case' (Term.declare_term_frees t Name.context) t of
         NONE => [t]
       | SOME (x, ps) => maps (fn (l, r) =>
           expand (Term.subst_atomic [(x, l)] r)) ps)
  in expand t end;

fun read_decl ctxt = variant
  [("lemma", read_statement ctxt Lemma),
   ("axiom", read_statement ctxt (fn (name, prems, concls) =>
      Axiom (name, map (fn concl =>
        Logic.list_implies (prems, concl)) concls))),
   ("typedecl", fn atts => fn params :: rhs => Typedecl
      (get_name' atts,
       read_ty_params params,
       option (read_type ctxt) rhs)),
   ("param", fn atts => fn [ty] => Param
      (get_name' atts, read_type ctxt ty)),
   ("definition", fn atts => fn [t] =>
      Definition (get_name'' atts, read_prop ctxt t)),
   ("datatypes", fn _ => fn xs => Datatype (prep_datatypes ctxt
      (map (elem "datatype" (fn atts => fn [params, constrs] =>
         (get_name' atts,
          read_ty_params params,
          elem "constrs"
            (K (map (elem "constr" (fn atts => fn ys =>
               (get_name' atts, ys))))) constrs))) xs))),
   ("inductive", fn atts => fn xs => Inductive
      (get_bool "coind" atts,
       map (elem "pred" (fn atts => fn ty :: rls =>
         (get_name' atts,
          read_type ctxt ty,
          map (elem "rule" (fn atts => fn [prems, concl] =>
            (get_name' atts,
             Logic.list_implies
               (elem "prems" (K (map (read_prop ctxt))) prems,
                read_prop ctxt concl)))) rls))) xs)),
   ("function", fn _ => fn xs => Function
      (map (elem "eqn" (fn atts => fn [t] =>
         (get_name'' atts, expand_cases ctxt (read_prop ctxt t)))) xs))];

fun rename_const ps = map_aterms
  (fn t as Const (s, T) => (case AList.lookup (op =) ps s of
          SOME s' => Free (s', T)
        | NONE => t)
    | t => t);

fun string_of_id (SOME (s, s')) = s ^ "." ^ s';

fun lookup_list sel lookup xs =
  let val ps = map (fn x => (x, lookup (sel x))) xs
  in
    if forall (is_none o snd) ps then NONE
    else SOME (map
      (fn (x, SOME y) => (x, y)
        | (x, NONE) =>
            error ("No association given for " ^ string_of_id (sel x)))
      ps)
  end;

fun fact_binding s = Binding.qualify false "facts" (Binding.name s);

fun mk_decl _ (Axiom ((s, id), ts)) thy =
      (case lookup_thm thy id of
         NONE =>
           (thy |> Specification.axiomatization
              [] [((fact_binding s, []), ts)] |> snd,
            true)
       | SOME thms =>
           if length thms = length ts andalso
             forall (Pattern.matches thy o apfst prop_of) (thms ~~ ts)
           then (thy, false)
           else error ("Failed to match axiom " ^ string_of_id id))
  | mk_decl realize (Typedecl ((s, id), args, opt_rhs)) thy =
      (case opt_rhs of
         NONE =>
           if realize then (thy, false) else
           (case lookup_type' thy id of
              NONE =>
                (thy |> globalize (Typedecl.typedecl
                   (Binding.name s, map (rpair dummyS) args, NoSyn) #> snd) |>
                 add_type s,
                 true)
            | SOME s' => (add_type_raw NONE (s, s') thy, false))
       | SOME T =>
           (thy |> globalize (Typedecl.abbrev
              (Binding.name s, args, NoSyn) T #> snd) |>
            add_type s,
            true))
  | mk_decl realize (Param ((s, id), T)) thy =
      if realize then (thy, false) else
      (case lookup_const' thy id of
         NONE =>
           (thy |> Specification.axiomatization
              [(Binding.name s, SOME T, NoSyn)] [] |> snd |>
            add_const s,
            true)
       | SOME s' => (add_const_raw NONE (s, s') thy, false))
  | mk_decl _ (Definition (id, eqn)) thy =
      let val (s, _) = head_of_eqn eqn
      in
        case lookup_def thy id of
          NONE =>
            (thy |> globalize (Specification.definition
               (NONE, (Attrib.empty_binding, eqn)) #> snd) |>
             add_const s,
             true)
        | SOME [th] =>
            let val (s', _) = head_of_eqn' (prop_of th)
              handle TERM _ => error ("Bad equation for " ^ string_of_id id)
            in
              if Pattern.matches thy (rename_const [(s', s)] (prop_of th), eqn)
              then (add_const_raw NONE (s, s') thy, false)
              else error ("Failed to match definition " ^ string_of_id id)
            end
        | _ => error ("Single theorem expected for " ^ string_of_id id)
      end
  | mk_decl _ (Datatype dts) thy =
      (case lookup_list (snd o #1) (lookup_type' thy) dts of
         NONE =>
           (thy |> Datatype.add_datatype Datatype_Aux.default_config
              (map (fn ((s, _), args, constrs) =>
                 ((Binding.name s, map (rpair dummyS) args, NoSyn),
                  map (fn ((s', _), Ts) =>
                    (Binding.name s', Ts, NoSyn)) constrs)) dts) |> snd |>
            fold (fn ((s, _), _, constrs) => add_type s #>
              fold (add_const o fst o fst) constrs) dts,
            true)
       | SOME dts' =>
           let val tcmap = map (fn (((s, _), _, _), s') =>
             (Sign.full_name thy (Binding.name s), s')) dts'
           in
             (fold (fn (((s, id), args, constrs), s') =>
                let
                  val (args', constrs') = Datatype.the_spec thy s';
                  fun err () = error ("Failed to match type " ^ string_of_id id);
                  val _ =
                    length args = length args' andalso
                    length constrs = length constrs' orelse err ();
                  val tvmap = args ~~ map fst args';

                  fun rename (Type (tc, Ts)) = Type
                        (the_default tc (AList.lookup (op =) tcmap tc),
                         map rename Ts)
                    | rename (TFree (a, S)) = TFree
                        (the_default a (AList.lookup (op =) tvmap a), S)
                    | rename T = T
                in
                  add_type_raw NONE (s, s') #>
                  fold2 (fn ((s, _), Ts) => fn (s', Us) =>
                    if map rename Ts = Us
                    then add_const_raw NONE (s, s')
                    else err ()) constrs constrs'
                end) dts' thy,
              false)
           end)
  | mk_decl _ (Inductive (coind, preds)) thy =
      (case lookup_list (snd o #1) (lookup_def thy) preds of
         NONE =>
           (thy |> Inductive.add_inductive_global
              {quiet_mode = true, verbose = false,
               alt_name = Binding.empty, coind = coind,
               no_elim = false, no_ind = false, skip_mono = false}
              (map (fn ((s, _), T, _) => ((Binding.name s, T), NoSyn)) preds) []
              (maps (map (apfst (rpair [] o Binding.name o fst)) o #3) preds) [] |>
            snd |> fold (add_const o fst o #1) preds,
            true)
       | SOME preds' =>
           let val cmap = map (fn (((s, id), _, _), th :: _) =>
             (th |> concl_of |> HOLogic.dest_Trueprop |> head_of |>
              dest_Const |> fst handle TERM _ =>
                error ("Bad introduction rule for " ^ string_of_id id),
              s)) preds'
           in
             app (fn (((_, id), _, intrs), intrs') =>
               if length intrs = length intrs' andalso
                 forall2 (fn (_, t) => fn th =>
                     Pattern.matches thy (rename_const cmap (prop_of th), t))
                   intrs intrs'
               then ()
               else error ("Failed to match predicate " ^ string_of_id id)) preds';
             (fold (add_const_raw NONE o swap) cmap thy, false)
           end)
  | mk_decl _ (Function eqnss) thy =
      let val eqnss' = map (head_of_eqn o hd o snd) eqnss
      in
        case lookup_list fst (lookup_def thy) eqnss of
          NONE =>
            (thy |> globalize (fn lthy => Function_Fun.add_fun
               (map (fn (s, T) => (Binding.name s, SOME T, NoSyn)) eqnss')
               (map (pair Attrib.empty_binding) (maps snd eqnss))
               Function_Fun.fun_config lthy) |>
             fold (add_const o fst) eqnss',
             true)
        | SOME eqnss'' =>
            let val cmap = map2 (fn ((id, _), th :: _) => fn (s, _) =>
              (th |> prop_of |> head_of_eqn' |> fst handle TERM _ =>
                 error ("Bad equation for " ^ string_of_id id),
               s)) eqnss'' eqnss'
            in
              app (fn ((id, eqns), eqns') =>
                if length eqns = length eqns' andalso
                  forall2 (fn t => fn th =>
                      Pattern.matches thy (rename_const cmap (prop_of th), t))
                    eqns eqns'
                then ()
                else error ("Failed to match function " ^ string_of_id id)) eqnss'';
              (fold (add_const_raw NONE o swap) cmap thy, false)
            end
      end
  | mk_decl _ _ thy = (thy, true);

fun init_decls thyname consts types = Why3_Data.map
  (fn {theories, env = NONE} =>
        {theories = Symtab.update_new
           (thyname,
            {consts = Symtab.make consts,
             types = Symtab.make types,
             thms = Symtab.empty,
             defs = Symtab.empty})
           theories handle Symtab.DUP _ =>
             error ("Theory " ^ thyname ^ " has already been loaded."),
         env = SOME
           {thyname = thyname,
            decls = [],
            vcs = Symtab.empty}}
    | _ => err_unfinished ());

fun put_decls decls = Why3_Data.map
  (fn {theories, env = SOME {thyname, ...}} =>
        {theories = theories,
         env = SOME
           {thyname = thyname,
            decls = decls,
            vcs = print_open_vcs I (fold
              (fn Lemma ((s, _), ps, cs) => Symtab.update_new (s, (NONE, ps, cs))
                | _ => I) decls Symtab.empty
              handle Symtab.DUP k => error ("Verification condition " ^ k ^
                " has already been declared."))}}
    | _ => err_no_env ());

fun close incomplete thy =
  thy |>
  Why3_Data.map (fn
      {theories, env = SOME {thyname, vcs, ...}} =>
        let
          val (proved, unproved) = partition_vcs vcs;
          val _ = Thm.join_proofs (maps (#1 o snd) proved)
        in
          (if null unproved
           then writeln ("Finished Why3 theory " ^ thyname)
           else (if incomplete then warning else error)
             (Pretty.string_of (pp_open_vcs unproved));
           {theories = theories, env = NONE})
        end
    | _ => err_no_env ()) |>
  Sign.parent_path;

fun process_decls consts types x = elem "theory" (fn atts =>
  (fn imports :: xs => elem "realized" (fn _ => fn rs => fn thy =>
        let
          val thyname = get_name atts;
          val realize = get_bool "realize" atts;
          val (ds, thy') = thy |>
            Sign.add_path thyname |>
            init_decls thyname consts types |>
            pair [] |>
            fold (fn x => fn (ds, thy) =>
              let
                val d = read_decl (Named_Target.theory_init thy) x;
                val (thy', b) = mk_decl realize d thy
              in ((b ? cons d) ds, thy') end) xs
        in put_decls (rev ds) thy' end) imports
    | _ => error "Bad theory specification")) x


(**** pretty printing ****)

fun string_of_status NONE = "(* unproved *)"
  | string_of_status (SOME _) = "(* proved *)";

fun pretty_typ s [] = Pretty.str s
  | pretty_typ s [v] = Pretty.block
      [Pretty.str v, Pretty.brk 1, Pretty.str s]
  | pretty_typ s vs = Pretty.block
      [Pretty.list "(" ")" (map Pretty.str vs), Pretty.brk 1, Pretty.str s];

fun blocks prfx1 prfx2 xs f = fst (fold_map (fn x => fn prfx =>
    (Pretty.block (Pretty.str prfx :: Pretty.brk 1 :: f x),
     prfx2))
  xs prfx1);

fun pretty_decl (p, f) ctxt (Lemma ((s, _), prems, concls)) =
      let
        val SOME (opt, _, _) = lookup_vc (Proof_Context.theory_of ctxt) s;
        val ctxt' = fold Variable.auto_fixes (prems @ concls) ctxt;
        val (context, stmt) = mk_vc true prems concls
      in
        if p opt then
          SOME (Pretty.big_list ("lemma " ^ s ^ ": " ^ f opt)
            (Element.pretty_ctxt ctxt' context @
             Element.pretty_stmt ctxt' stmt))
        else NONE
      end
  | pretty_decl _ ctxt (Axiom ((s, _), ts)) =
      let val ctxt' = fold Variable.auto_fixes ts ctxt
      in SOME (Pretty.block
        ([Pretty.str "axiomatization where", Pretty.brk 1,
          Pretty.str s, Pretty.str ":", Pretty.brk 1] @
         separate (Pretty.brk 1)
           (map (Pretty.quote o Syntax.pretty_term ctxt') ts)))
      end
  | pretty_decl _ ctxt (Typedecl ((s, _), args, opt_rhs)) = SOME (Pretty.block
      (case opt_rhs of
         NONE => [Pretty.str "typedecl", Pretty.brk 1,
           pretty_typ s args]
       | SOME T => [Pretty.str "type_synonym", Pretty.brk 1,
           pretty_typ s args, Pretty.str " =", Pretty.brk 1,
           Pretty.quote (Syntax.pretty_typ ctxt T)]))
  | pretty_decl _ ctxt (Param ((s, _), T)) = SOME (Pretty.block
      [Pretty.str "axiomatization", Pretty.brk 1,
       Pretty.str s, Pretty.str " ::", Pretty.brk 1,
       Pretty.quote (Syntax.pretty_typ ctxt T)])
  | pretty_decl _ ctxt (Definition (_, eqn)) =
      let
        val ctxt' = Variable.auto_fixes eqn ctxt;
        val (s, T) = head_of_eqn eqn
      in SOME (Pretty.block [Pretty.str "definition ", Pretty.str s,
        Pretty.str " ::", Pretty.brk 1,
        Pretty.quote (Syntax.pretty_typ ctxt' T),
        Pretty.str " where", Pretty.fbrk,
        Pretty.quote (Syntax.pretty_term ctxt' eqn)])
      end
  | pretty_decl _ ctxt (Datatype dts) = SOME (Pretty.chunks
      (blocks "datatype" "and" dts (fn ((s, _), args, constrs) =>
         [pretty_typ s args,
          Pretty.str " =", Pretty.brk 1] @
          Pretty.separate " |"
            (map (fn ((s', _), Ts) => Pretty.block
                 (separate (Pretty.brk 1) (Pretty.str s' ::
                    (map (Pretty.quote o
                       Syntax.pretty_typ ctxt) Ts))))
               constrs))))
  | pretty_decl _ ctxt (Inductive (coind, preds)) =
      let val ctxt' = fold (fold (Variable.auto_fixes o snd) o #3) preds ctxt
      in
        SOME (Pretty.chunks
          (blocks ((coind ? prefix "co") "inductive") "and" preds
             (fn ((s, _), T, _) =>
                [Pretty.str s, Pretty.str " ::", Pretty.brk 1,
                 Pretty.quote (Syntax.pretty_typ ctxt' T)]) @
           Pretty.str "where" ::
           blocks " " "|" (maps #3 preds) (fn ((s, _), t) =>
             [Pretty.str s, Pretty.str ":",
              Pretty.brk 1, Pretty.quote (Syntax.pretty_term ctxt' t)])))
      end
  | pretty_decl _ ctxt (Function eqnss) =
      let val ctxt' = fold (fold Variable.auto_fixes o snd) eqnss ctxt
      in
        SOME (Pretty.chunks
          (blocks "fun" "and" eqnss (fn (_, t :: _) =>
             let val (s, T) = head_of_eqn t
             in
               [Pretty.str s, Pretty.str " ::", Pretty.brk 1,
                Pretty.quote (Syntax.pretty_typ ctxt' T)]
             end) @
           Pretty.str "where" ::
           blocks " " "|" (maps snd eqnss)
             (single o Pretty.quote o Syntax.pretty_term ctxt')))
      end;

fun path_of_decl (Lemma ((_, SOME (s, _)), _, _)) = s
  | path_of_decl (Axiom ((_, SOME (s, _)), _)) = s
  | path_of_decl (Typedecl ((_, SOME (s, _)), _, _)) = s
  | path_of_decl (Param ((_, SOME (s, _)), _)) = s
  | path_of_decl (Definition (SOME (s, _), _)) = s
  | path_of_decl (Datatype (((_, SOME (s, _)), _, _) :: _)) = s
  | path_of_decl (Inductive (_, ((_, SOME (s, _)), _, _) :: _)) = s
  | path_of_decl (Function ((SOME (s, _), _) :: _)) = s
  | path_of_decl _ = "local";

fun show_status thy sel =
  (case Why3_Data.get thy of
     {env = SOME {decls, ...}, ...} =>
       let
         val ctxt = Proof_Context.init_global thy;
         val decls' = AList.coalesce (op =)
           (map (fn d => (path_of_decl d, d)) decls)
       in
         Pretty.writeln (Pretty.chunks2 (maps (fn (s, ds) =>
           Pretty.str ("(**** " ^ s ^ " ****)") ::
           map_filter (pretty_decl sel ctxt) ds) decls'))
       end
   | _ => ());


(**** commands ****)

fun why3_open ((name, consts), types) thy = process_decls
  (map (apsnd (Sign.intern_const thy)) consts)
  (map (apsnd (Sign.intern_type thy)) types)
  (parse_xml (snd (Thy_Load.load_file thy (Path.explode name)))) thy;

fun prove_vc vc_name lthy =
  let
    val thy = Proof_Context.theory_of lthy;
    val (ctxt, stmt) = get_vc thy vc_name
  in
    Specification.theorem Thm.theoremK NONE
      (fn thmss => (Local_Theory.background_theory
         (mark_proved vc_name (flat thmss))))
      (fact_binding vc_name, []) [] [ctxt] stmt false lthy
  end;

val _ =
  Outer_Syntax.command @{command_spec "why3_open"}
    "open a new Why3 environment and load a Why3-generated .xml file"
    (Parse.name --
     Scan.optional (Parse.reserved "constants" |-- Parse.!!! (Scan.repeat1
       (Parse.name --| Args.$$$ "=" -- Parse.!!! Parse.xname))) [] --
     Scan.optional (Parse.reserved "types" |-- (Scan.repeat1
       (Parse.name --| Args.$$$ "=" -- Parse.!!! Parse.xname))) [] >>
     (Toplevel.theory o why3_open));

val _ =
  Outer_Syntax.command @{command_spec "why3_vc"}
    "enter into proof mode for a specific verification condition"
    (Parse.name >> (fn name =>
      (Toplevel.print o Toplevel.local_theory_to_proof NONE (prove_vc name))));

val _ =
  Outer_Syntax.improper_command @{command_spec "why3_status"}
    "show the name and state of all loaded verification conditions"
    (Scan.optional
       (Args.parens
          (   Args.$$$ "proved" >> K (is_some, K "")
           || Args.$$$ "unproved" >> K (is_none, K "")))
       (K true, string_of_status) >> (fn args =>
        Toplevel.keep (fn state => show_status (Toplevel.theory_of state) args)))

val _ =
  Outer_Syntax.command @{command_spec "why3_end"}
    "close the current Why3 environment"
    (Scan.optional (@{keyword "("} |-- Parse.!!!
         (Parse.reserved "incomplete" --| @{keyword ")"}) >> K true) false >>
       (Toplevel.theory o close));

val _ =
  Outer_Syntax.command @{command_spec "why3_consts"}
    "associate Why3 constants with constants"
    (Scan.repeat1 (Parse.xname --| Args.$$$ "=" -- Parse.xname) >>
       (Toplevel.theory o fold add_why3_const));

val _ =
  Outer_Syntax.command @{command_spec "why3_types"}
    "associate Why3 types with types"
    (Scan.repeat1 (Parse.xname --| Args.$$$ "=" -- Parse.xname) >>
       (Toplevel.theory o fold add_why3_type));

val _ =
  Outer_Syntax.command @{command_spec "why3_thms"}
    "associate Why3 axioms with theorems"
    (Parse.and_list1 (Parse.xname --| Args.$$$ "=" -- Parse_Spec.xthms1) >>
       (Toplevel.theory o fold add_why3_thm));

val _ =
  Outer_Syntax.command @{command_spec "why3_defs"}
    "associate Why3 definitions with definitions"
    (Parse.and_list1 (Parse.xname --| Args.$$$ "=" -- Parse_Spec.xthms1) >>
       (Toplevel.theory o fold add_why3_def));

val setup = Theory.at_end (fn thy =>
  let
    val _ = is_closed thy
      orelse error ("Found the end of the theory, " ^
        "but the last Why3 environment is still open.")
  in NONE end);

end;
