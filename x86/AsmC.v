Require Import Coqlib Maps.
Require Import AST Integers Floats Values Memory Events Globalenvs Smallstep.
Require Import Locations Stacklayout Conventions.
(** newly added **)
Require Import Asmregs.
Require Export Asm.
Require Import ModSem.
Require Import CoqlibC.

Set Implicit Arguments.



Definition get_mem (st: state): mem :=
  match st with
  | State _ m0 => m0
  end.

Definition funsig (fd: fundef) :=
  match fd with
  | Internal f => fn_sig f
  | External ef => ef_sig ef
  end.

Definition st_rs (st0: state): regset :=
  match st0 with
  | State rs _ => rs
  end
.

Definition st_m (st0: state): mem :=
  match st0 with
  | State _ m => m
  end
.

Section MODSEM.

  Variable p: program.
  Let ge := p.(Genv.globalenv).


  (* Inductive at_external: state -> val -> option signature -> regset -> mem -> Prop := *)
  (* | at_external_intro *)
  (*     rs_arg m_arg b_arg *)
  (*     (FPTR: rs_arg # PC = Vptr b_arg Ptrofs.zero true) *)
  (*     (EXTERNAL: Genv.find_funct_ptr ge b_arg = None) *)
  (*   : *)
  (*     at_external (State rs_arg m_arg) (Vptr b_arg Ptrofs.zero true) None rs_arg m_arg *)
  (* . *)

  Inductive at_external (st0: state): regset -> mem -> Prop :=
  | at_external_intro
      fb_arg
      (FPTR: st0.(st_rs) # PC = Vptr fb_arg Ptrofs.zero true)
      (EXTERNAL: Genv.find_funct_ptr ge fb_arg = None)
      fd
      (RAINTERNAL: Genv.find_funct ge (st0.(st_rs) # RA) = Some (Internal fd)) (* Only for disjointness with final_frame *)
    :
      at_external st0 st0.(st_rs) st0.(st_m)
  .

  Inductive initial_frame (rs_arg: regset) (m_arg: mem)
    : state -> Prop :=
  | initial_frame_intro
    :
      initial_frame rs_arg m_arg (State rs_arg m_arg)
  .

  Inductive final_frame (rs_init: regset) (st0: state): regset -> Prop :=
  | final_frame_intro
      fb
      (FPTR: st0.(st_rs) # PC = Vptr fb Ptrofs.zero true)
      (EXTERNAL: Genv.find_funct_ptr ge fb = None)
      (RA: st0.(st_rs) # PC = st0.(st_rs) # RA)
    :
      final_frame rs_init st0 st0.(st_rs)
  .

  Inductive after_external (st0: state) (rs_arg: regset)
            (rs_ret: regset) (m_ret: mem): state -> Prop :=
  | after_external_intro
    :
      after_external st0 rs_arg rs_ret m_ret (State rs_ret m_ret)
  .

  Program Definition modsem: ModSem.t :=
    {|
      ModSem.step := Asm.step;
      ModSem.get_mem := get_mem;
      ModSem.at_external := at_external;
      ModSem.initial_frame := initial_frame;
      ModSem.final_frame := final_frame;
      ModSem.after_external := after_external;
      ModSem.globalenv := ge; (* TODO: Change this properly *)
      ModSem.skenv := (admit "TODO")
      (* ModSem.after_external := (admit ""); *)
    |}
  .
  Next Obligation. all_prop_inv; ss. Qed.
  Next Obligation. all_prop_inv; ss. Qed.
  Next Obligation. inv FINAL0. inv FINAL1. ss. Qed.
  Next Obligation. all_prop_inv; ss. Qed.
  Next Obligation. ii; des; ss. inv PR; inv PR0; ss; rewrite FPTR in *; clarify. Qed.
  Next Obligation. ii; des; ss. inv PR; inv PR0; ss; rewrite FPTR in *; clarify. Qed.
  Next Obligation.
    ii; des; ss. inv PR; inv PR0; ss; rewrite FPTR in *; clarify.
    rewrite <- RA in *. ss. des_ifs.
  Qed.

End MODSEM.