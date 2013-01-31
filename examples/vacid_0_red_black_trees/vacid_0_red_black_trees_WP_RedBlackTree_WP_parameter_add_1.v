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

Definition key  := Z.

Definition value  := Z.

Inductive color  :=
  | Red : color 
  | Black : color .

Inductive tree  :=
  | Leaf : tree 
  | Node : color -> tree -> Z -> Z -> tree -> tree .

Set Implicit Arguments.
Fixpoint memt(t:tree) (k:Z) (v:Z) {struct t}: Prop :=
  match t with
  | Leaf => False
  | (Node _ l kqt vqt r) => ((k = kqt) /\ (v = vqt)) \/ ((memt l k v) \/
      (memt r k v))
  end.
Unset Implicit Arguments.

Axiom memt_color : forall (l:tree) (r:tree) (k:Z) (kqt:Z) (v:Z) (vqt:Z)
  (c:color) (cqt:color), (memt (Node c l k v r) kqt vqt) -> (memt (Node cqt l
  k v r) kqt vqt).

Definition lt_tree(x:Z) (t:tree): Prop := forall (k:Z), forall (v:Z), (memt t
  k v) -> (k <  x)%Z.

Definition gt_tree(x:Z) (t:tree): Prop := forall (k:Z), forall (v:Z), (memt t
  k v) -> (x <  k)%Z.

Set Implicit Arguments.
Fixpoint bst(t:tree) {struct t}: Prop :=
  match t with
  | Leaf => True
  | (Node _ l k v r) => (bst l) /\ ((bst r) /\ ((lt_tree k l) /\ (gt_tree k
      r)))
  end.
Unset Implicit Arguments.

Axiom bst_Leaf : (bst Leaf).

Definition is_not_red(t:tree): Prop :=
  match t with
  | (Node Red _ _ _ _) => False
  | (Leaf|(Node Black _ _ _ _)) => True
  end.

Set Implicit Arguments.
Fixpoint rbtree(n:Z) (t:tree) {struct t}: Prop :=
  match t with
  | Leaf => (n = 0%Z)
  | (Node Red l _ _ r) => (rbtree n l) /\ ((rbtree n r) /\ ((is_not_red l) /\
      (is_not_red r)))
  | (Node Black l _ _ r) => (rbtree (n - 1%Z)%Z l) /\ (rbtree (n - 1%Z)%Z r)
  end.
Unset Implicit Arguments.

Axiom rbtree_Leaf : (rbtree 0%Z Leaf).

Axiom rbtree_Node1 : forall (k:Z) (v:Z), (rbtree 0%Z (Node Red Leaf k v
  Leaf)).

Definition almost_rbtree(n:Z) (t:tree): Prop :=
  match t with
  | Leaf => (n = 0%Z)
  | (Node Red l _ _ r) => (rbtree n l) /\ (rbtree n r)
  | (Node Black l _ _ r) => (rbtree (n - 1%Z)%Z l) /\ (rbtree (n - 1%Z)%Z r)
  end.

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Theorem WP_parameter_add : forall (t:tree), forall (k:Z), forall (v:Z),
  ((bst t) /\ exists n:Z, (rbtree n t)) -> (((bst t) /\ exists n:Z, (rbtree n
  t)) -> forall (result:tree), ((bst result) /\ ((forall (n:Z), (rbtree n
  t) ->
  (match result with
  | Leaf => (n = 0%Z)
  | (Node Red l _ _ r) => (rbtree n l) /\ (rbtree n r)
  | (Node Black l _ _ r) => (rbtree (n - 1%Z)%Z l) /\ (rbtree (n - 1%Z)%Z r)
  end /\
  (match t with
  | (Node Red _ _ _ _) => False
  | (Leaf|(Node Black _ _ _ _)) => True
  end -> (rbtree n result)))) /\ ((memt result k v) /\ forall (kqt:Z)
  (vqt:Z), ((memt result kqt vqt) \/ (((kqt = k) -> (vqt = v)) /\
  ((~ (kqt = k)) -> (memt t kqt vqt)))) -> ((memt result kqt vqt) /\
  (((kqt = k) /\ (vqt = v)) \/ ((~ (kqt = k)) /\ (memt t kqt vqt))))))) ->
  match result with
  | (Node _ l kqt vqt r) => exists n:Z, (rbtree n (Node Black l kqt vqt r))
  | Leaf => True
  end).
(* YOU MAY EDIT THE PROOF BELOW *)
intuition.
destruct result; auto.
destruct H2 as (n, h). clear H3.
generalize (H0 n h); clear H0.
intros.
destruct c; intuition.
(* c = Red *)
exists (n+1)%Z; intuition.
simpl rbtree. replace (n+1-1)%Z with n by omega.
intuition.
(* c = Black *)
exists n; intuition.
simpl rbtree. 
intuition.
Qed.
(* DO NOT EDIT BELOW *)

