(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
Axiom Max_is_ge : forall (x:Z) (y:Z), (x <= (Zmax x y))%Z /\
  (y <= (Zmax x y))%Z.

Axiom Max_is_some : forall (x:Z) (y:Z), ((Zmax x y) = x) \/ ((Zmax x y) = y).

Axiom Min_is_le : forall (x:Z) (y:Z), ((Zmin x y) <= x)%Z /\
  ((Zmin x y) <= y)%Z.

Axiom Min_is_some : forall (x:Z) (y:Z), ((Zmin x y) = x) \/ ((Zmin x y) = y).

Axiom Max_x : forall (x:Z) (y:Z), (y <= x)%Z -> ((Zmax x y) = x).

Axiom Max_y : forall (x:Z) (y:Z), (x <= y)%Z -> ((Zmax x y) = y).

Axiom Min_x : forall (x:Z) (y:Z), (x <= y)%Z -> ((Zmin x y) = x).

Axiom Min_y : forall (x:Z) (y:Z), (y <= x)%Z -> ((Zmin x y) = y).

Axiom Max_sym : forall (x:Z) (y:Z), (y <= x)%Z -> ((Zmax x y) = (Zmax y x)).

Axiom Min_sym : forall (x:Z) (y:Z), (y <= x)%Z -> ((Zmin x y) = (Zmin y x)).

Inductive list (a:Type) :=
  | Nil : list a
  | Cons : a -> (list a) -> list a.
Set Contextual Implicit.
Implicit Arguments Nil.
Unset Contextual Implicit.
Implicit Arguments Cons.

Parameter length: forall (a:Type), (list a)  -> Z.

Implicit Arguments length.

Axiom length_def : forall (a:Type), forall (l:(list a)),
  match l with
  | Nil  => ((length l) = 0%Z)
  | Cons _ r => ((length l) = (1%Z + (length r))%Z)
  end.

Axiom Length_nonnegative : forall (a:Type), forall (l:(list a)),
  (0%Z <= (length l))%Z.

Axiom Length_nil : forall (a:Type), forall (l:(list a)),
  ((length l) = 0%Z) <-> (l = (Nil:(list a))).

Parameter char : Type.

Definition word  := (list char).

Inductive dist : (list char) -> (list char) -> Z -> Prop :=
  | dist_eps : (dist (Nil:(list char)) (Nil:(list char)) 0%Z)
  | dist_add_left : forall (w1:(list char)) (w2:(list char)) (n:Z), (dist w1
      w2 n) -> forall (a:char), (dist (Cons a w1) w2 (n + 1%Z)%Z)
  | dist_add_right : forall (w1:(list char)) (w2:(list char)) (n:Z), (dist w1
      w2 n) -> forall (a:char), (dist w1 (Cons a w2) (n + 1%Z)%Z)
  | dist_context : forall (w1:(list char)) (w2:(list char)) (n:Z), (dist w1
      w2 n) -> forall (a:char), (dist (Cons a w1) (Cons a w2) n).

Definition min_dist(w1:(list char)) (w2:(list char)) (n:Z): Prop := (dist w1
  w2 n) /\ forall (m:Z), (dist w1 w2 m) -> (n <= m)%Z.

Axiom min_dist_equal : forall (w1:(list char)) (w2:(list char)) (a:char)
  (n:Z), (min_dist w1 w2 n) -> (min_dist (Cons a w1) (Cons a w2) n).

Axiom min_dist_diff : forall (w1:(list char)) (w2:(list char)) (a:char)
  (b:char) (m:Z) (p:Z), (~ (a = b)) -> ((min_dist (Cons a w1) w2 p) ->
  ((min_dist w1 (Cons b w2) m) -> (min_dist (Cons a w1) (Cons b w2)
  ((Zmin m p) + 1%Z)%Z))).

Theorem min_dist_eps : forall (w:(list char)) (a:char) (n:Z), (min_dist w
  (Nil:(list char)) n) -> (min_dist (Cons a w) (Nil:(list char))
  (n + 1%Z)%Z).
(* YOU MAY EDIT THE PROOF BELOW *)
unfold min_dist.
intros w a n [H1 H2].
 split.
apply dist_add_left.
assumption.
intros m Hm; inversion Hm.
generalize (H2 n0 H5).
intros; omega.
Qed.
(* DO NOT EDIT BELOW *)


