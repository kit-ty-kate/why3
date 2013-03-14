(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require Import R_sqrt.
Require BuiltIn.
Require real.Real.
Require real.Square.

(* Why3 assumption *)
Definition dot (x1:R) (x2:R) (y1:R) (y2:R): R :=
  ((x1 * y1)%R + (x2 * y2)%R)%R.

(* Why3 assumption *)
Definition norm2 (x1:R) (x2:R): R := ((Rsqr x1) + (Rsqr x2))%R.

Axiom norm2_pos : forall (x1:R) (x2:R), (0%R <= (norm2 x1 x2))%R.

Axiom Lagrange : forall (a1:R) (a2:R) (b1:R) (b2:R), (((norm2 a1
  a2) * (norm2 b1 b2))%R = ((Rsqr (dot a1 a2 b1
  b2)) + (Rsqr ((a1 * b2)%R - (a2 * b1)%R)%R))%R).

Axiom CauchySchwarz_aux : forall (x1:R) (x2:R) (y1:R) (y2:R), ((Rsqr (dot x1
  x2 y1 y2)) <= ((norm2 x1 x2) * (norm2 y1 y2))%R)%R.

(* Why3 assumption *)
Definition norm (x1:R) (x2:R): R := (sqrt (norm2 x1 x2)).

Axiom norm_pos : forall (x1:R) (x2:R), (0%R <= (norm x1 x2))%R.

Require Import Why3.
Ltac ae := why3 "Alt-Ergo,0.95.1," timelimit 3.

Open Scope R_scope.

(* Why3 goal *)
Theorem sqr_le_sqrt : forall (x:R) (y:R), ((Rsqr x) <= y)%R ->
  (x <= (sqrt y))%R.
intros x y h1.
assert (0 <= Rsqr x) by ae.
assert (0 <= y) by ae.
assert (h : (x < 0 \/ x >= 0)%R).
  ae.
destruct h.
  ae.
replace x with (sqrt (Rsqr x)).
apply sqrt_le_1.
ae.
ae.
ae.
ae.
Qed.

