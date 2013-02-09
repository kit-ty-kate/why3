(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require map.Map.

(* Why3 assumption *)
Definition unit  := unit.

(* Why3 assumption *)
Inductive ref (a:Type) {a_WT:WhyType a} :=
  | mk_ref : a -> ref a.
Axiom ref_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (ref a).
Existing Instance ref_WhyType.
Implicit Arguments mk_ref [[a] [a_WT]].

(* Why3 assumption *)
Definition contents {a:Type} {a_WT:WhyType a}(v:(ref a)): a :=
  match v with
  | (mk_ref x) => x
  end.

(* Why3 assumption *)
Inductive array (a:Type) {a_WT:WhyType a} :=
  | mk_array : Z -> (map.Map.map Z a) -> array a.
Axiom array_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (array a).
Existing Instance array_WhyType.
Implicit Arguments mk_array [[a] [a_WT]].

(* Why3 assumption *)
Definition elts {a:Type} {a_WT:WhyType a}(v:(array a)): (map.Map.map Z a) :=
  match v with
  | (mk_array x x1) => x1
  end.

(* Why3 assumption *)
Definition length {a:Type} {a_WT:WhyType a}(v:(array a)): Z :=
  match v with
  | (mk_array x x1) => x
  end.

(* Why3 assumption *)
Definition get {a:Type} {a_WT:WhyType a}(a1:(array a)) (i:Z): a :=
  (map.Map.get (elts a1) i).

(* Why3 assumption *)
Definition set {a:Type} {a_WT:WhyType a}(a1:(array a)) (i:Z) (v:a): (array
  a) := (mk_array (length a1) (map.Map.set (elts a1) i v)).

(* Why3 assumption *)
Definition make {a:Type} {a_WT:WhyType a}(n:Z) (v:a): (array a) :=
  (mk_array n (map.Map.const v:(map.Map.map Z a))).

(* Why3 assumption *)
Definition exchange {a:Type} {a_WT:WhyType a}(a1:(map.Map.map Z a))
  (a2:(map.Map.map Z a)) (i:Z) (j:Z): Prop := ((map.Map.get a1
  i) = (map.Map.get a2 j)) /\ (((map.Map.get a2 i) = (map.Map.get a1 j)) /\
  forall (k:Z), ((~ (k = i)) /\ ~ (k = j)) -> ((map.Map.get a1
  k) = (map.Map.get a2 k))).

Axiom exchange_set : forall {a:Type} {a_WT:WhyType a},
  forall (a1:(map.Map.map Z a)), forall (i:Z) (j:Z), (exchange a1
  (map.Map.set (map.Map.set a1 i (map.Map.get a1 j)) j (map.Map.get a1 i)) i
  j).

(* Why3 assumption *)
Inductive permut_sub{a:Type} {a_WT:WhyType a}  : (map.Map.map Z a)
  -> (map.Map.map Z a) -> Z -> Z -> Prop :=
  | permut_refl : forall (a1:(map.Map.map Z a)), forall (l:Z) (u:Z),
      (permut_sub a1 a1 l u)
  | permut_sym : forall (a1:(map.Map.map Z a)) (a2:(map.Map.map Z a)),
      forall (l:Z) (u:Z), (permut_sub a1 a2 l u) -> (permut_sub a2 a1 l u)
  | permut_trans : forall (a1:(map.Map.map Z a)) (a2:(map.Map.map Z a))
      (a3:(map.Map.map Z a)), forall (l:Z) (u:Z), (permut_sub a1 a2 l u) ->
      ((permut_sub a2 a3 l u) -> (permut_sub a1 a3 l u))
  | permut_exchange : forall (a1:(map.Map.map Z a)) (a2:(map.Map.map Z a)),
      forall (l:Z) (u:Z) (i:Z) (j:Z), ((l <= i)%Z /\ (i < u)%Z) ->
      (((l <= j)%Z /\ (j < u)%Z) -> ((exchange a1 a2 i j) -> (permut_sub a1
      a2 l u))).

Axiom permut_weakening : forall {a:Type} {a_WT:WhyType a},
  forall (a1:(map.Map.map Z a)) (a2:(map.Map.map Z a)), forall (l1:Z) (r1:Z)
  (l2:Z) (r2:Z), (((l1 <= l2)%Z /\ (l2 <= r2)%Z) /\ (r2 <= r1)%Z) ->
  ((permut_sub a1 a2 l2 r2) -> (permut_sub a1 a2 l1 r1)).

Axiom permut_eq : forall {a:Type} {a_WT:WhyType a}, forall (a1:(map.Map.map Z
  a)) (a2:(map.Map.map Z a)), forall (l:Z) (u:Z), (permut_sub a1 a2 l u) ->
  forall (i:Z), ((i < l)%Z \/ (u <= i)%Z) -> ((map.Map.get a2
  i) = (map.Map.get a1 i)).

Axiom permut_exists : forall {a:Type} {a_WT:WhyType a},
  forall (a1:(map.Map.map Z a)) (a2:(map.Map.map Z a)), forall (l:Z) (u:Z),
  (permut_sub a1 a2 l u) -> forall (i:Z), ((l <= i)%Z /\ (i < u)%Z) ->
  exists j:Z, ((l <= j)%Z /\ (j < u)%Z) /\ ((map.Map.get a2
  i) = (map.Map.get a1 j)).

(* Why3 assumption *)
Definition exchange1 {a:Type} {a_WT:WhyType a}(a1:(array a)) (a2:(array a))
  (i:Z) (j:Z): Prop := (exchange (elts a1) (elts a2) i j).

(* Why3 assumption *)
Definition permut_sub1 {a:Type} {a_WT:WhyType a}(a1:(array a)) (a2:(array a))
  (l:Z) (u:Z): Prop := (permut_sub (elts a1) (elts a2) l u).

(* Why3 assumption *)
Definition permut {a:Type} {a_WT:WhyType a}(a1:(array a)) (a2:(array
  a)): Prop := ((length a1) = (length a2)) /\ (permut_sub (elts a1) (elts a2)
  0%Z (length a1)).

Axiom exchange_permut : forall {a:Type} {a_WT:WhyType a}, forall (a1:(array
  a)) (a2:(array a)) (i:Z) (j:Z), (exchange1 a1 a2 i j) ->
  (((length a1) = (length a2)) -> (((0%Z <= i)%Z /\ (i < (length a1))%Z) ->
  (((0%Z <= j)%Z /\ (j < (length a1))%Z) -> (permut a1 a2)))).

Axiom permut_sym1 : forall {a:Type} {a_WT:WhyType a}, forall (a1:(array a))
  (a2:(array a)), (permut a1 a2) -> (permut a2 a1).

Axiom permut_trans1 : forall {a:Type} {a_WT:WhyType a}, forall (a1:(array a))
  (a2:(array a)) (a3:(array a)), (permut a1 a2) -> ((permut a2 a3) ->
  (permut a1 a3)).

(* Why3 assumption *)
Definition map_eq_sub {a:Type} {a_WT:WhyType a}(a1:(map.Map.map Z a))
  (a2:(map.Map.map Z a)) (l:Z) (u:Z): Prop := forall (i:Z), ((l <= i)%Z /\
  (i < u)%Z) -> ((map.Map.get a1 i) = (map.Map.get a2 i)).

(* Why3 assumption *)
Definition array_eq_sub {a:Type} {a_WT:WhyType a}(a1:(array a)) (a2:(array
  a)) (l:Z) (u:Z): Prop := (map_eq_sub (elts a1) (elts a2) l u).

(* Why3 assumption *)
Definition array_eq {a:Type} {a_WT:WhyType a}(a1:(array a)) (a2:(array
  a)): Prop := ((length a1) = (length a2)) /\ (array_eq_sub a1 a2 0%Z
  (length a1)).

Axiom array_eq_sub_permut : forall {a:Type} {a_WT:WhyType a},
  forall (a1:(array a)) (a2:(array a)) (l:Z) (u:Z), (array_eq_sub a1 a2 l
  u) -> (permut_sub1 a1 a2 l u).

Axiom array_eq_permut : forall {a:Type} {a_WT:WhyType a}, forall (a1:(array
  a)) (a2:(array a)), (array_eq a1 a2) -> (permut a1 a2).

Axiom param : Type.
Parameter param_WhyType : WhyType param.
Existing Instance param_WhyType.

Axiom elt : Type.
Parameter elt_WhyType : WhyType elt.
Existing Instance elt_WhyType.

Parameter le: param -> elt -> elt -> Prop.

Axiom le_refl : forall (p:param) (x:elt), (le p x x).

Axiom le_asym : forall (p:param) (x:elt) (y:elt), (~ (le p x y)) -> (le p y
  x).

Axiom le_trans : forall (p:param) (x:elt) (y:elt) (z:elt), ((le p x y) /\
  (le p y z)) -> (le p x z).

(* Why3 assumption *)
Definition sorted_sub(p:param) (a:(array elt)) (l:Z) (u:Z): Prop :=
  forall (i1:Z) (i2:Z), (((l <= i1)%Z /\ (i1 <= i2)%Z) /\ (i2 < u)%Z) ->
  (le p (get a i1) (get a i2)).

(* Why3 assumption *)
Definition sorted(p:param) (a:(array elt)): Prop := (sorted_sub p a 0%Z
  (length a)).

Require Import Why3.
Ltac ae := why3 "alt-ergo" timelimit 2.

(* Why3 goal *)
Theorem WP_parameter_sort : forall (p:param) (a:Z), forall (a1:(map.Map.map Z
  elt)), let a2 := (mk_array a a1) in ((0%Z <= (a - 1%Z)%Z)%Z ->
  forall (a3:(map.Map.map Z elt)), let a4 := (mk_array a a3) in forall (i:Z),
  ((0%Z <= i)%Z /\ (i <= (a - 1%Z)%Z)%Z) -> (((permut a2 a4) /\ (sorted_sub p
  a4 0%Z i)) -> forall (j:Z) (a5:(map.Map.map Z elt)), let a6 := (mk_array a
  a5) in (((((((0%Z <= j)%Z /\ (j <= i)%Z) /\ (permut a2 a6)) /\
  (sorted_sub p a6 0%Z j)) /\ (sorted_sub p a6 j (i + 1%Z)%Z)) /\
  forall (k1:Z) (k2:Z), (((0%Z <= k1)%Z /\ (k1 < j)%Z) /\
  (((j + 1%Z)%Z <= k2)%Z /\ (k2 <= i)%Z)) -> (le p (map.Map.get a5 k1)
  (map.Map.get a5 k2))) -> ((0%Z < j)%Z -> (((0%Z <= j)%Z /\ (j < a)%Z) ->
  (((0%Z <= (j - 1%Z)%Z)%Z /\ ((j - 1%Z)%Z < a)%Z) -> ((~ (le p
  (map.Map.get a5 (j - 1%Z)%Z) (map.Map.get a5 j))) -> (((0%Z <= j)%Z /\
  (j < a)%Z) -> (((0%Z <= (j - 1%Z)%Z)%Z /\ ((j - 1%Z)%Z < a)%Z) ->
  (((0%Z <= j)%Z /\ (j < a)%Z) -> forall (a7:(map.Map.map Z elt)),
  (a7 = (map.Map.set a5 j (map.Map.get a5 (j - 1%Z)%Z))) ->
  (((0%Z <= (j - 1%Z)%Z)%Z /\ ((j - 1%Z)%Z < a)%Z) -> forall (a8:(map.Map.map
  Z elt)), (a8 = (map.Map.set a7 (j - 1%Z)%Z (map.Map.get a5 j))) ->
  ((exchange a5 a8 (j - 1%Z)%Z j) -> forall (j1:Z), (j1 = (j - 1%Z)%Z) ->
  (sorted_sub p (mk_array a a8) j1 (i + 1%Z)%Z))))))))))))).
intros p a a1 a2 h1 a3 a4 i (h2,h3) (h4,h5) j a5 a6
(((((h6,h7),h8),h9),h10),h11) h12 (h13,h14) (h15,h16) h17 (h18,h19) (h20,h21)
(h22,h23) a7 h24 (h25,h26) a8 h27 h28 j1 h29.
unfold sorted_sub,get in *.
simpl in *.
ae.
Qed.

