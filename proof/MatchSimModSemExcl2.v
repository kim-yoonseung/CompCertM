Require Import CoqlibC.
Require Import SmallstepC.
Require Import Simulation.
Require Import ModSem AsmregsC GlobalenvsC MemoryC ASTC.
Require Import Skeleton SimModSem SimMem SimMemLift SimSymb.
Require Import Sound Preservation.
Require Import ModSemProps.

Set Implicit Arguments.





Section MATCHSIMFORWARD.

  Context {SM: SimMem.class} {SS: SimSymb.class SM} {SU: Sound.class}.
  Context {SML: SimMemLift.class SM}.

  Variable msp: ModSemPair.t.
  Variable index: Type.
  Variable order: index -> index -> Prop.
  Hypothesis WFORD: well_founded order.
  Let ms_src: ModSem.t := msp.(ModSemPair.src).
  Let ms_tgt: ModSem.t := msp.(ModSemPair.tgt).
  Variable sidx: Type.
  Hypothesis INHAB: inhabited sidx.
  Variable sound_states: sidx -> Sound.t -> mem -> ms_src.(state) -> Prop.
  Hypothesis PRSV: forall si, local_preservation ms_src (sound_states si).

  Variable match_states: forall
      (idx: index) (st_src0: ms_src.(ModSem.state)) (st_tgt0: ms_tgt.(ModSem.state)) (sm0: SimMem.t),
      Prop.

  Variable match_states_at: forall
      (st_src0: ms_src.(ModSem.state)) (st_tgt0: ms_tgt.(ModSem.state)) (sm_at sm_arg: SimMem.t),
      Prop.

  Inductive match_states_at_helper
            (idx_at: index) (st_src0: ms_src.(ModSem.state)) (st_tgt0: ms_tgt.(ModSem.state)) (sm_at sm_arg: SimMem.t): Prop :=
  | match_states_at_intro
      (MATCH: match_states idx_at st_src0 st_tgt0 sm_at)
      args_src args_tgt
      (CALLSRC: ms_src.(ModSem.at_external) st_src0 args_src)
      (CALLTGT: ms_tgt.(ModSem.at_external) st_tgt0 args_tgt)
      (SIMARGS: SimMem.sim_args args_src args_tgt sm_arg)
      (MLE: SimMem.le sm_at sm_arg)
      (MWF: SimMem.wf sm_arg)
      (MATCHARG: match_states_at st_src0 st_tgt0 sm_at sm_arg).
      (* (FOOT: has_footprint st_src0 st_tgt0 sm_at) *)

  Hypothesis INITBSIM: forall
      sm_arg args_src args_tgt st_init_tgt
      (SIMSKENV: ModSemPair.sim_skenv msp sm_arg)
      (MWF: SimMem.wf sm_arg)
      (SIMARGS: SimMem.sim_args args_src args_tgt sm_arg)
      (INITTGT: ms_tgt.(ModSem.initial_frame) args_tgt st_init_tgt)
      (SAFESRC: exists _st_init_src, ms_src.(ModSem.initial_frame) args_src _st_init_src),
      exists st_init_src sm_init idx_init,
        (<<INITSRC: ms_src.(ModSem.initial_frame) args_src st_init_src>>) /\
        (<<MLE: SimMem.le sm_arg sm_init>>) /\
        (<<MATCH: match_states idx_init st_init_src st_init_tgt sm_init>>).

  Hypothesis INITPROGRESS: forall sm_arg args_src args_tgt
      (SIMSKENV: ModSemPair.sim_skenv msp sm_arg)
      (MWF: SimMem.wf sm_arg)
      (SIMARGS: SimMem.sim_args args_src args_tgt sm_arg)
      (SAFESRC: exists st_init_src, ms_src.(ModSem.initial_frame) args_src st_init_src),
      exists st_init_tgt, (<<INITTGT: ms_tgt.(ModSem.initial_frame) args_tgt st_init_tgt>>).

  Hypothesis ATMWF: forall idx0 st_src0 st_tgt0 sm0
      (MATCH: match_states idx0 st_src0 st_tgt0 sm0)
      (CALLSRC: ms_src.(ModSem.is_call) st_src0),
      <<MWF: SimMem.wf sm0>>.

  Hypothesis ATFSIM: forall idx0 st_src0 st_tgt0 sm0 args_src
      (SIMSKENV: ModSemPair.sim_skenv msp sm0)
      (MATCH: match_states idx0 st_src0 st_tgt0 sm0)
      (CALLSRC: ms_src.(ModSem.at_external) st_src0 args_src)
      (SOUND: forall si, exists su0 m_init, (sound_states si) su0 m_init st_src0),
      exists args_tgt sm_arg,
        (<<CALLTGT: ms_tgt.(ModSem.at_external) st_tgt0 args_tgt>>) /\
        (<<SIMARGS: SimMem.sim_args args_src args_tgt sm_arg>>) /\
        (<<MLE: SimMem.le sm0 sm_arg>>) /\
        (<<MWF: SimMem.wf sm_arg>>) /\
        (<<MATCHAT: match_states_at st_src0 st_tgt0 sm0 sm_arg>>).

  Hypothesis AFTERFSIM: forall idx0 st_src0 st_tgt0 sm0 sm_arg sm_ret retv_src retv_tgt st_src1
      (SIMSKENV: ModSemPair.sim_skenv msp sm0)
      (MATCH: match_states idx0 st_src0 st_tgt0 sm0)
      (MLE: SimMem.le sm0 sm_arg)
      (* (MWF: SimMem.wf sm_arg) *)
      (MLE: SimMem.le (SimMemLift.lift sm_arg) sm_ret)
      (MWF: SimMem.wf sm_ret)
      (SIMRET: SimMem.sim_retv retv_src retv_tgt sm_ret)
      (AFTERSRC: ms_src.(ModSem.after_external) st_src0 retv_src st_src1)
      (SOUND: forall si, exists su0 m_init, (sound_states si) su0 m_init st_src0)

      (* history *)
      (HISTORY: match_states_at_helper idx0 st_src0 st_tgt0 sm0 sm_arg)

      (* just helpers *)
      (MWFAFTR: SimMem.wf (SimMemLift.unlift sm_arg sm_ret))
      (MLEAFTR: SimMem.le sm_arg (SimMemLift.unlift sm_arg sm_ret)),
      exists sm_after idx1 st_tgt1,
        (<<MLE: SimMem.le sm0 sm_after>>) /\
        forall (MLE: SimMem.le sm0 sm_after) (* helper *),
          ((<<AFTERTGT: ms_tgt.(ModSem.after_external) st_tgt0 retv_tgt st_tgt1>>) /\
           (<<MATCH: match_states idx1 st_src1 st_tgt1 sm_after>>)).

  Hypothesis FINALFSIM: forall idx0 st_src0 st_tgt0 sm0 retv_src
      (SIMSKENV: ModSemPair.sim_skenv msp sm0)
      (MATCH: match_states idx0 st_src0 st_tgt0 sm0)
      (FINALSRC: ms_src.(ModSem.final_frame) st_src0 retv_src),
      exists sm_ret retv_tgt,
        (<<FINALTGT: ms_tgt.(ModSem.final_frame) st_tgt0 retv_tgt>>) /\
        (<<SIMRET: SimMem.sim_retv retv_src retv_tgt sm_ret>>) /\
        (<<MLE: SimMem.le sm0 sm_ret>>) /\
        (<<MWF: SimMem.wf sm_ret>>).

  Let STEPFSIM := forall idx0 st_src0 st_tgt0 sm0
      (SIMSKENV: ModSemPair.sim_skenv msp sm0)
      (NOTCALL: ~ ModSem.is_call ms_src st_src0)
      (NOTRET: ~ ModSem.is_return ms_src st_src0)
      (MATCH: match_states idx0 st_src0 st_tgt0 sm0)
      (SOUND: forall si, exists su0 m_init, (sound_states si) su0 m_init st_src0),
      (<<RECEP: receptive_at ms_src st_src0>>) /\
      (<<STEPFSIM: forall tr st_src1
             (STEPSRC: Step ms_src st_src0 tr st_src1),
             exists idx1 st_tgt1 sm1,
               (<<PLUS: DPlus ms_tgt st_tgt0 tr st_tgt1>> \/
                           <<STAR: DStar ms_tgt st_tgt0 tr st_tgt1 /\ order idx1 idx0>>)
               /\ (<<MLE: SimMem.le sm0 sm1>>)
               (* Note: We require le for mle_preserves_sim_ge, but we cannot require SimMem.wf, beacuse of DCEproof *)
               /\ (<<MATCH: match_states idx1 st_src1 st_tgt1 sm1>>)>>).

  Let STEPBSIM := forall idx0 st_src0 st_tgt0 sm0
      (SIMSKENV: ModSemPair.sim_skenv msp sm0)
      (NOTCALL: ~ ModSem.is_call ms_src st_src0)
      (NOTRET: ~ ModSem.is_return ms_src st_src0)
      (MATCH: match_states idx0 st_src0 st_tgt0 sm0)
      (SOUND: forall si, exists su0 m_init, (sound_states si) su0 m_init st_src0),
      (<<PROGRESS: safe_modsem ms_src st_src0 -> ModSem.is_step ms_tgt st_tgt0>>) /\
      (<<STEPBSIM: forall tr st_tgt1
             (STEPTGT: Step ms_tgt st_tgt0 tr st_tgt1),
             exists idx1 st_src1 sm1,
               (<<PLUS: Plus ms_src st_src0 tr st_src1>> \/
                           <<STAR: Star ms_src st_src0 tr st_src1 /\ order idx1 idx0>>)
               /\ (<<MLE: SimMem.le sm0 sm1>>)
               (* Note: We require le for mle_preserves_sim_ge, but we cannot require SimMem.wf, beacuse of DCEproof *)
               /\ (<<MATCH: match_states idx1 st_src1 st_tgt1 sm1>>)>>).

  Hypothesis STEPSIM: STEPFSIM \/ STEPBSIM.

  Hypothesis BAR: bar_True.

  Lemma match_states_lxsim
        sm_init i0 st_src0 st_tgt0 sm0
        (SIMSKENV: ModSemPair.sim_skenv msp sm0)
        (MLE: SimMem.le sm_init sm0)
        (* (MWF: SimMem.wf sm0) *)
        (* (MCOMPAT: mem_compat st_src0 st_tgt0 sm0) *)
        (MATCH: match_states i0 st_src0 st_tgt0 sm0):
        (* su0 *)
      (* <<LXSIM: lxsim ms_src ms_tgt (sound_state su0) sm_init i0.(to_idx WFORD) st_src0 st_tgt0 sm0>> *)
      <<LXSIM: lxsim ms_src ms_tgt (fun st => forall si, exists su0 m_init, sound_states si su0 m_init st)
                     i0.(Ord.lift_idx WFORD) st_src0 st_tgt0 sm0>>.
  Proof.
    (* move su0 at top. *)
    revert_until BAR. pcofix CIH. i. pfold. ii.
    generalize (classic (ModSem.is_call ms_src st_src0)). intro CALLSRC; des.
    { (* CALL *)
      - (* u in CALLSRC. des. *)
        exploit ATMWF; eauto. i; des. ii. eapply lxsim_at_external; eauto. ii. clear CALLSRC.
        exploit ATFSIM; eauto. { ii. eapply SUSTAR; eauto. eapply star_refl. } i; des.
        (* determ_tac ModSem.at_external_dtm. clear_tac. *)
        eexists _, (SimMemLift.lift sm_arg).
        esplits; eauto.
        { eapply SimMemLift.lift_args; eauto. }
        { eapply SimMemLift.lift_wf; eauto. }
        { etrans; eauto. eapply SimMemLift.lift_priv; eauto. }
        i. exploit AFTERFSIM; try apply SAFESRC; try apply SIMRET; eauto.
        { ii. eapply SUSTAR. eapply star_refl. }
        { econs; eauto. }
        { eapply SimMemLift.unlift_wf; eauto. }
        { eapply SimMemLift.lift_spec; eauto. }
        i; des. spc H1. des. esplits; eauto. right. eapply CIH; eauto.
        { eapply ModSemPair.mfuture_preserves_sim_skenv; try apply SIMSKENV; eauto.
          apply rtc_once. left. et.
        }
    }
    generalize (classic (ModSem.is_return ms_src st_src0)). intro RETSRC; des.
    { (* RETURN *)
      u in RETSRC. des. exploit FINALFSIM; eauto. i; des. ii.
      eapply lxsim_final; try apply SIMRET; eauto.
    }
    destruct STEPSIM as [STEPFSIM0|STEPBSIM0].
    { eapply lxsim_step_forward; eauto. i.
      exploit STEPFSIM0; eauto. { ii. eapply SUSTAR; eauto. eapply star_refl. } i; des.
      esplits; eauto. econs 1; eauto. ii. exploit STEPFSIM1; eauto. i; des_safe. esplits; eauto.
      - des.
        + left. eauto.
        + right. esplits; eauto. eapply Ord.lift_idx_spec; eauto.
      - right. eapply CIH; eauto.
        { eapply ModSemPair.mfuture_preserves_sim_skenv; try apply SIMSKENV; eauto. apply rtc_once; eauto. }
    }
    { rr in STEPBSIM0. eapply lxsim_step_backward; eauto. i.
      exploit STEPBSIM0; eauto. { ii. eapply SUSTAR; eauto. eapply star_refl. } i; des. rr in PROGRESS. des.
      esplits; eauto; cycle 1. econs 1; eauto. ii. exploit STEPBSIM1; eauto. i; des_safe. esplits; eauto.
      - des.
        + left. eauto.
        + right. esplits; eauto. eapply Ord.lift_idx_spec; eauto.
      - right. eapply CIH; eauto.
        { eapply ModSemPair.mfuture_preserves_sim_skenv; try apply SIMSKENV; eauto. apply rtc_once; eauto. }
    }
  Qed.

  Theorem match_states_sim: <<SIM: msp.(ModSemPair.sim)>>.
  Proof.
    inv INHAB. econs; eauto.
    { i. eapply local_preservation_noguarantee_weak; eauto. }
    ii; ss. folder.
    exploit SimSymb.sim_skenv_func_bisim; eauto. { apply SIMSKENV. } intro FSIM; des.
    inv FSIM. exploit FUNCFSIM; eauto. { apply SimMem.sim_args_sim_fptr; et. } i; des.
    split; ii.
    - exploit INITBSIM; eauto. i; des.
      esplits; eauto.
      eapply match_states_lxsim; eauto.
      { eapply ModSemPair.mfuture_preserves_sim_skenv; try apply SIMSKENV; eauto. apply rtc_once; eauto. }
    - exploit INITPROGRESS; eauto.
  Unshelve.
    all: ss.
  Qed.

End MATCHSIMFORWARD.
