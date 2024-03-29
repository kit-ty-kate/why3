(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.

(* Why3 goal *)
Lemma andb_def : forall (x:bool) (y:bool),
  ((Init.Datatypes.andb x y) = match x with
  | true => y
  | false => false
  end).
Proof.
intros x y.
apply refl_equal.
Qed.

(* Why3 goal *)
Lemma orb_def : forall (x:bool) (y:bool),
  ((Init.Datatypes.orb x y) = match x with
  | false => y
  | true => true
  end).
Proof.
intros x y.
apply refl_equal.
Qed.

(* Why3 goal *)
Lemma xorb_def : forall (x:bool) (y:bool),
  ((Init.Datatypes.xorb x y) = match (x,
  y) with
  | (true, false) => true
  | (false, true) => true
  | (_, _) => false
  end).
Proof.
intros x y.
apply refl_equal.
Qed.

(* Why3 goal *)
Lemma notb_def : forall (x:bool),
  ((Init.Datatypes.negb x) = match x with
  | false => true
  | true => false
  end).
Proof.
intros x.
apply refl_equal.
Qed.

(* Why3 goal *)
Lemma implb_def : forall (x:bool) (y:bool),
  ((Init.Datatypes.implb x y) = match (x,
  y) with
  | (true, false) => false
  | (_, _) => true
  end).
Proof.
now intros [|] [|].
Qed.

