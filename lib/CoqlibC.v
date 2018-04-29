(** copied && added "C" **)
Require Export ZArith.
Require Export Znumtheory.
Require Export List.
Require Export Bool.

(** newly added **)
Require Export Coqlib.
Require Export sflib.
From Paco Require Export paco.
Require Export Basics.

Require Import Relations.
Require Import RelationClasses.
Require Import Wellfounded.
Require Export Classical_Prop.

Set Implicit Arguments.



Ltac determ_tac LEMMA :=
  let tac := eauto in
  let x := rev_all ltac:(fun f => apply f) in
  let y := all ltac:(fun f => apply f) in
  first[
      exploit LEMMA; [x|y|]
    | exploit LEMMA; [tac|x|y|]
    | exploit LEMMA; [tac|tac|x|y|]
    | exploit LEMMA; [tac|tac|tac|x|y|]
    | exploit LEMMA; [tac|tac|tac|tac|x|y|]
    ]
  ;
  i; des; clarify
.

(* TODO: if it is mature enough, move it to sflib & remove this file *)

Definition update_fst {A B C: Type} (f: A -> C) (ab: A * B): C * B := (f ab.(fst), ab.(snd)).

Definition update_snd {A B C: Type} (f: B -> C) (ab: A * B): A * C := (ab.(fst), f ab.(snd)).

Lemma dep_split_right
      (A B: Prop)
      (PA: A)
      (PB: <<LEFT: A>> -> B)
  :
    <<SPLIT: A /\ B>>
.
Proof.
  split; eauto.
Qed.

Lemma dep_split_left
      (A B: Prop)
      (PA: <<RIGHT: B>> -> A)
      (PB: B)
  :
    A /\ B
.
Proof.
  split; eauto.
Qed.

Lemma list_forall2_map
      X Y (f: X -> Y) xs
  :
    list_forall2 (fun x0 x1 => x1 = f x0) xs (map f xs)
.
Proof.
  ginduction xs; ii; ss.
  - econs; eauto.
  - econs; eauto.
Qed.


Lemma list_forall2_map_right
      X Y (f: X -> Y) xs
  :
    list_forall2 (fun x0 x1 => x0 = f x1) (map f xs) xs
.
Proof.
  ginduction xs; ii; ss.
  - econs; eauto.
  - econs; eauto.
Qed.

(* Lemma list_forall2_flip *)
(*       X Y (P: X -> Y -> Prop) xs ys *)
(*       (FORALL2: list_forall2 P xs ys) *)
(*   : *)
(*     <<FORALL2: list_forall2 (Basics.flip P) ys xs>> *)
(* . *)
(* Proof. *)
(*   ginduction FORALL2; ii; ss. *)
(*   - econs; eauto. *)
(*   - econs; eauto. *)
(* Qed. *)

Lemma list_forall2_stronger
      X Y xs ys (P: X -> Y -> Prop)
      (FORALL2: list_forall2 P xs ys)
      Q
      (STRONGER: P <2= Q)
  :
    <<FORALL2: list_forall2 Q xs ys>>
.
Proof.
  ginduction FORALL2; ii; ss.
  - econs; eauto.
  - econs; eauto.
    eapply IHFORALL2; eauto.
Qed.

Global Program Instance incl_PreOrder {A}: PreOrder (@incl A).
Next Obligation.
  ii. ss.
Qed.
Next Obligation.
  ii.
  eauto.
Qed.

(* is_Some & is_None? a bit harder to type *)
Definition is_some {X} (x: option X): bool :=
  match x with
  | Some _ => true
  | _ => false
  end
.

Definition is_none {X} := negb <*> (@is_some X).

Hint Unfold is_some is_none.


Notation "x $" := (x.(proj1_sig)) (at level 50, no associativity (* , only parsing *)).

Notation " 'all1' p" := (forall x0, p x0) (at level 50, no associativity).
Notation " 'all2' p" := (forall x0 x1, p x0 x1) (at level 50, no associativity).
Notation " 'all3' p" := (forall x0 x1 x2, p x0 x1 x2) (at level 50, no associativity).
Notation " 'all4' p" := (forall x0 x1 x2 x3, p x0 x1 x2 x3) (at level 50, no associativity).

Notation " ~1 p" := (fun x0 => ~ (p x0)) (at level 50, no associativity).
Notation " ~2 p" := (fun x0 x1 => ~ (p x0 x1)) (at level 50, no associativity).
Notation " ~3 p" := (fun x0 x1 x2 => ~ (p x0 x1 x2)) (at level 50, no associativity).
Notation " ~4 p" := (fun x0 x1 x2 x3 => ~ (p x0 x1 x2 x3)) (at level 50, no associativity).

Notation "p /1\ q" := (fun x0 => and (p x0) (q x0)) (at level 50, no associativity).
Notation "p /2\ q" := (fun x0 x1 => and (p x0 x1) (q x0 x1)) (at level 50, no associativity).
Notation "p /3\ q" := (fun x0 x1 x2 => and (p x0 x1 x2) (q x0 x1 x2)) (at level 50, no associativity).
Notation "p /4\ q" := (fun x0 x1 x2 x3 => and (p x0 x1 x2 x3) (q x0 x1 x2 x3)) (at level 50, no associativity).

(* Definition less1 X0 (p q: X0 -> Prop) := (forall x0 (PR: p x0 : Prop), q x0 : Prop). *)
(* Hint Unfold less1. *)
(* Notation "p <1= q" := (less1 p q) (at level 50). *)
(* Global Program Instance less1_PreOrder X0: PreOrder (@less1 X0). *)

Notation "p <1= q" := (fun x0 => (forall (PR: p x0: Prop), q x0): Prop).
Notation "p <2= q" := (fun x0 x1 => (forall (PR: p x0 x1: Prop), q x0 x1): Prop).
Notation "p <3= q" := (fun x0 x1 x2 => ((forall (PR: p x0 x1 x2: Prop), q x0 x1 x2): Prop)).
Notation "p <4= q" := (fun x0 x1 x2 x3 => (forall (PR: p x0 x1 x2 x3: Prop), q x0 x1 x2 x3): Prop).

(* Notation "p =1= q" := (forall x0, eq (p x0) (q x0)) (at level 50, no associativity). *)
Notation "p =1= q" := (fun x0 => eq (p x0) (q x0)) (at level 50, no associativity).
Notation "p =2= q" := (fun x0 x1 => eq (p x0 x1) (q x0 x1)) (at level 50, no associativity).
Notation "p =3= q" := (fun x0 x1 x2 => eq (p x0 x1 x2) (q x0 x1 x2)) (at level 50, no associativity).
Notation "p =4= q" := (fun x0 x1 x2 x3 => eq (p x0 x1 x2 x3) (q x0 x1 x2 x3)) (at level 50, no associativity).

Notation top1 := (fun _ => True).
Notation top2 := (fun _ _ => True).
Notation top3 := (fun _ _ _ => True).
Notation top4 := (fun _ _ _ => True).

Goal all1 ((bot1: unit -> Prop) <1= top1).
(* Goal ((bot1: unit -> Prop) <1= top1). *)
Proof. ii. ss. Qed.

(* Originally in sflib, (t):Prop *)
(* Removed it for use in "privs" of ASTM *)
(* Notation "<< x : t >>" := (NW (fun x => (t))) (at level 80, x ident, no associativity). *)


Print Ltac uf.
Ltac u := repeat (autounfold with * in *; cbn in *).
(* TODO add in sflib *)

Hint Unfold Basics.compose.


(* Note: not clos_refl_trans. That is not well-founded.. *)
Lemma well_founded_clos_trans
      index
      (order: index -> index -> Prop)
      (WF: well_founded order)
  :
    <<WF: well_founded (clos_trans index order)>>
.
Proof.
  hnf in WF.
  hnf.
  i.
  eapply Acc_clos_trans. eauto.
Qed.

Lemma Forall2_impl
      X Y
      (xs: list X) (ys: list Y)
      (P Q: X -> Y -> Prop)
      (* (IMPL: all3 (P <3= Q)) *)
      (IMPL: all2 (P <2= Q))
      (FORALL: Forall2 P xs ys)
  :
    <<FORALL: Forall2 Q xs ys>>
.
Proof.
  admit "easy".
Qed.

Inductive Forall3 X Y Z (R: X -> Y -> Z -> Prop): list X -> list Y -> list Z -> Prop :=
| Forall3_nil: Forall3 R [] [] []
| Forall3_cons
    x y z
    xs ys zs
    (TAIL: Forall3 R xs ys zs)
  :
    Forall3 R (x :: xs) (y :: ys) (z :: zs)
.

Lemma Forall3_impl
      X Y Z
      (xs: list X) (ys: list Y) (zs: list Z)
      (P Q: X -> Y -> Z -> Prop)
      (* (IMPL: all3 (P <3= Q)) *)
      (IMPL: all3 (P <3= Q))
      (FORALL: Forall3 P xs ys zs)
  :
    <<FORALL: Forall3 Q xs ys zs>>
.
Proof.
  admit "easy".
Qed.

Definition option_join A (a: option (option A)): option A :=
  match a with
  | Some a => a
  | None => None
  end
.

Ltac subst_locals := all ltac:(fun H => is_local_definition H; subst H).

Hint Unfold flip.