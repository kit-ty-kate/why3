(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
Definition unit  := unit.

Parameter qtmark : Type.

Parameter at1: forall (a:Type), a -> qtmark -> a.

Implicit Arguments at1.

Parameter old: forall (a:Type), a -> a.

Implicit Arguments old.

Definition implb(x:bool) (y:bool): bool := match (x,
  y) with
  | (true, false) => false
  | (_, _) => true
  end.

Inductive list (a:Type) :=
  | Nil : list a
  | Cons : a -> (list a) -> list a.
Set Contextual Implicit.
Implicit Arguments Nil.
Unset Contextual Implicit.
Implicit Arguments Cons.

Set Implicit Arguments.
Fixpoint length (a:Type)(l:(list a)) {struct l}: Z :=
  match l with
  | Nil => 0%Z
  | (Cons _ r) => (1%Z + (length r))%Z
  end.
Unset Implicit Arguments.

Axiom Length_nonnegative : forall (a:Type), forall (l:(list a)),
  (0%Z <= (length l))%Z.

Axiom Length_nil : forall (a:Type), forall (l:(list a)),
  ((length l) = 0%Z) <-> (l = (Nil:(list a))).

Set Implicit Arguments.
Fixpoint infix_plpl (a:Type)(l1:(list a)) (l2:(list a)) {struct l1}: (list
  a) :=
  match l1 with
  | Nil => l2
  | (Cons x1 r1) => (Cons x1 (infix_plpl r1 l2))
  end.
Unset Implicit Arguments.

Axiom Append_assoc : forall (a:Type), forall (l1:(list a)) (l2:(list a))
  (l3:(list a)), ((infix_plpl l1 (infix_plpl l2
  l3)) = (infix_plpl (infix_plpl l1 l2) l3)).

Axiom Append_l_nil : forall (a:Type), forall (l:(list a)), ((infix_plpl l
  (Nil:(list a))) = l).

Axiom Append_length : forall (a:Type), forall (l1:(list a)) (l2:(list a)),
  ((length (infix_plpl l1 l2)) = ((length l1) + (length l2))%Z).

Set Implicit Arguments.
Fixpoint mem (a:Type)(x:a) (l:(list a)) {struct l}: Prop :=
  match l with
  | Nil => False
  | (Cons y r) => (x = y) \/ (mem x r)
  end.
Unset Implicit Arguments.

Axiom mem_append : forall (a:Type), forall (x:a) (l1:(list a)) (l2:(list a)),
  (mem x (infix_plpl l1 l2)) <-> ((mem x l1) \/ (mem x l2)).

Axiom mem_decomp : forall (a:Type), forall (x:a) (l:(list a)), (mem x l) ->
  exists l1:(list a), exists l2:(list a), (l = (infix_plpl l1 (Cons x l2))).

Inductive tree  :=
  | Leaf : tree 
  | Node : tree -> tree -> tree .

Set Implicit Arguments.
Fixpoint depths(d:Z) (t:tree) {struct t}: (list Z) :=
  match t with
  | Leaf => (Cons d (Nil:(list Z)))
  | (Node l r) => (infix_plpl (depths (d + 1%Z)%Z l) (depths (d + 1%Z)%Z r))
  end.
Unset Implicit Arguments.

Axiom depths_head : forall (t:tree) (d:Z), match (depths d
  t) with
  | (Cons x _) => (d <= x)%Z
  | Nil => False
  end.

Axiom depths_unique : forall (t1:tree) (t2:tree) (d:Z) (s1:(list Z))
  (s2:(list Z)), ((infix_plpl (depths d t1) s1) = (infix_plpl (depths d t2)
  s2)) -> ((t1 = t2) /\ (s1 = s2)).

Definition lex(x1:((list Z)* Z)%type) (x2:((list Z)* Z)%type): Prop :=
  match x1 with
  | (s1, d1) =>
      match x2 with
      | (s2, d2) => ((length s1) <  (length s2))%Z \/
          (((length s1) = (length s2)) /\ match (s1,
          s2) with
          | ((Cons h1 _), (Cons h2 _)) => ((d2 <  d1)%Z /\ (d1 <= h1)%Z) /\
              (h1 = h2)
          | _ => False
          end)
      end
  end.

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Theorem WP_parameter_build_rec : forall (d:Z), forall (s:(list Z)),
  match s with
  | Nil => True
  | (Cons h t) => (~ (h <  d)%Z) -> ((~ (h = d)) -> ((lex (s, (d + 1%Z)%Z) (
      s, d)) -> forall (result:tree) (result1:(list Z)),
      (s = (infix_plpl (depths (d + 1%Z)%Z result) result1)) -> ((lex (
      result1, (d + 1%Z)%Z) (s, d)) -> ((forall (result2:tree) (result3:(list
      Z)), (result1 = (infix_plpl (depths (d + 1%Z)%Z result2) result3)) ->
      (s = (infix_plpl (depths d (Node result result2)) result3))) ->
      ((forall (t1:tree) (sqt:(list Z)), ~ ((infix_plpl (depths (d + 1%Z)%Z
      t1) sqt) = result1)) -> forall (t1:tree) (sqt:(list Z)),
      ~ ((infix_plpl (depths d t1) sqt) = s))))))
  end.
(* YOU MAY EDIT THE PROOF BELOW *)
intuition.
destruct s; intuition.
rename z into h. rename s into t.
clear H1.
rename result into l. rename result1 into sl.
clear H3.
rename sqt into st1.
destruct t1 as [_|t1 t2].
(* t1 = Leaf *)
simpl in H6.
injection H6.
omega.
(* t1 = Node t1 t2 *)
simpl in H6.
rewrite <- Append_assoc in H6.
rewrite H2 in H6.
generalize (depths_unique _ _ _ _ _ H6).
intuition.
subst t1.
apply (H5 t2 st1); intuition.

Qed.
(* DO NOT EDIT BELOW *)


