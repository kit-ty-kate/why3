(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require set.Set.
Require settheory.Interval.
Require settheory.Relation.
Require settheory.InverseDomRan.
Require settheory.Function.
Require settheory.Identity.

Import set.Set.
Open Scope Z_scope.

(* Why3 assumption *)
Definition seq_length {a:Type} {a_WT:WhyType a}(n:Z) (s:(set.Set.set
  a)): (set.Set.set (set.Set.set (Z* a)%type)) :=
  (settheory.Function.infix_mnmngt (settheory.Interval.mk 1%Z n) s).

(* Why3 goal *)
Definition seq: forall {a:Type} {a_WT:WhyType a}, (set.Set.set a) ->
  (set.Set.set (set.Set.set (Z* a)%type)).
intros a a_WT s.
exact (fun f => exists n:Z, 0 <= n /\ mem f (seq_length n s)).
Defined.

(* Why3 goal *)
Definition size: forall {a:Type} {a_WT:WhyType a}, (set.Set.set (Z*
  a)%type) -> Z.

Defined.

(* Why3 goal *)
Lemma mem_seq : forall {a:Type} {a_WT:WhyType a}, forall (s:(set.Set.set a))
  (r:(set.Set.set (Z* a)%type)), (set.Set.mem r (seq s)) <->
  ((0%Z <= (size r))%Z /\ (set.Set.mem r (seq_length (size r) s))).
intros a a_WT s r.

Qed.

(* Why3 goal *)
Lemma seq_as_total_function : forall {a:Type} {a_WT:WhyType a},
  forall (s:(set.Set.set a)) (r:(set.Set.set (Z* a)%type)), (set.Set.mem r
  (seq s)) -> (set.Set.mem r
  (settheory.Function.infix_mnmngt (settheory.Interval.mk 1%Z (size r)) s)).
intros a a_WT s r h1.

Qed.

(* Why3 goal *)
Lemma size_def : forall {a:Type} {a_WT:WhyType a}, forall (n:Z)
  (r:(set.Set.set (Z* a)%type)), ((size r) = n) <-> exists s:(set.Set.set a),
  (set.Set.mem r (seq_length n s)).
intros a a_WT n r.

Qed.


(* Unused content named mem_seq_length
intros a a_WT n s.

Qed.
 *)
