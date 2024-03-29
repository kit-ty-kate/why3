(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require Reals.Rtrigo_def.
Require Reals.Rpower.
Require BuiltIn.
Require real.Real.

Import Rtrigo_def.
Import Rpower.

(* Why3 comment *)
(* exp is replaced with (Reals.Rtrigo_def.exp x) by the coq driver *)

(* Why3 goal *)
Lemma Exp_zero : ((Reals.Rtrigo_def.exp 0%R) = 1%R).
exact exp_0.
Qed.

Require Import Exp_prop.

(* Why3 goal *)
Lemma Exp_sum : forall (x:R) (y:R),
  ((Reals.Rtrigo_def.exp (x + y)%R) = ((Reals.Rtrigo_def.exp x) * (Reals.Rtrigo_def.exp y))%R).
exact exp_plus.
Qed.

(* Why3 comment *)
(* log is replaced with (Reals.Rpower.ln x) by the coq driver *)

(* Why3 goal *)
Lemma Log_one : ((Reals.Rpower.ln 1%R) = 0%R).
exact ln_1.
Qed.

(* Why3 goal *)
Lemma Log_mul : forall (x:R) (y:R), ((0%R < x)%R /\ (0%R < y)%R) ->
  ((Reals.Rpower.ln (x * y)%R) = ((Reals.Rpower.ln x) + (Reals.Rpower.ln y))%R).
intros x y (Hx,Hy).
now apply ln_mult.
Qed.

(* Why3 goal *)
Lemma Log_exp : forall (x:R),
  ((Reals.Rpower.ln (Reals.Rtrigo_def.exp x)) = x).
exact ln_exp.
Qed.

(* Why3 goal *)
Lemma Exp_log : forall (x:R), (0%R < x)%R ->
  ((Reals.Rtrigo_def.exp (Reals.Rpower.ln x)) = x).
exact exp_ln.
Qed.

(* Why3 assumption *)
Definition log2 (x:R): R := ((Reals.Rpower.ln x) / (Reals.Rpower.ln 2%R))%R.

(* Why3 assumption *)
Definition log10 (x:R): R :=
  ((Reals.Rpower.ln x) / (Reals.Rpower.ln 10%R))%R.

