Require Import FSets.
Require Import CoqlibC Maps Ordered Errors Lattice Kildall Integers.
Require Import AST Linking.
Require Import Values Memory Events Globalenvs Smallstep.
Require Import Op Locations LTLC LinearC.
Require Import Linearize.
Require Import sflib.
(** newly added **)
Require Export Linearizeproof.
Require Import Simulation.
Require Import Skeleton Mod ModSem SimMod SimModSem SimSymb SimMem AsmregsC MatchSimModSem ModSemProps.
Require SimMemId.
Require SoundTop.
Require Import Program.

Set Implicit Arguments.



Definition wf_tgt (st_tgt0: Linear.state): Prop :=
  exists sg_init ls_init, last_option st_tgt0.(LinearC.get_stack) = Some (LinearC.dummy_stack sg_init ls_init)
.

Lemma lift_starN
      cnt tse tge st_tgt0 tr st_tgt1
      (STAR: starN Linear.step tse tge cnt st_tgt0 tr st_tgt1)
      (DUMMYTGT: wf_tgt st_tgt0)
      (STKAFTER: get_stack st_tgt1 <> [])
  :
    <<STAR: starN step tse tge cnt st_tgt0 tr st_tgt1>>
.
Proof.
  unfold wf_tgt in *.
  induction STAR; ii; ss.
  { econs; et. }
  pose s as S1. pose s' as S2. pose s'' as S3.
  (* pose s1 as S1. pose s2 as S2. pose s3 as S3. *)
  econs; et.
  - econs; et.
    des. inv H; ss; destruct s0; ss. exfalso. clarify.
    clear - STAR STKAFTER.
    dependent induction STAR; ii; ss. inv H; ss.
  - des. exploit IHSTAR; et. inv H; ss; try (by esplits; et).
    + des_ifs. rewrite DUMMYTGT. esplits; et.
    + des_ifs.
      * ss. clarify.
        clear - STAR STKAFTER.
        dependent induction STAR; ii; ss. inv H; ss.
      * rewrite DUMMYTGT. esplits; et.
Qed.

Lemma lift_starN_stronger
      cnt tse tge st_tgt0 tr st_tgt1
      (STAR: starN Linear.step tse tge cnt st_tgt0 tr st_tgt1)
      (DUMMYTGT: wf_tgt st_tgt0)
      (STKAFTER: get_stack st_tgt1 <> [])
  :
    <<STAR: starN step tse tge cnt st_tgt0 tr st_tgt1>> /\ <<DUMMYTGT: wf_tgt st_tgt1>>
.
Proof.
  unfold wf_tgt in *.
  revert_until STAR.
  induction STAR; ii; ss.
  { split. - econs; et. - des. esplits; et. }
  assert(DUMMYTGT0: wf_tgt s'').
  { clarify.
    eapply IHSTAR; et. clear IHSTAR.
    des. inv H; ss; try (by esplits; et).
    - des_ifs. esplits; et.
    - des_ifs.
      + ss. clarify. inv STAR; ss. inv H; ss.
      + esplits; et.
  }
  split; ss.
  econs; et.
  - econs; et.
    des. inv H; ss; destruct s0; ss. exfalso. clarify. ss. clarify.
    clear - STAR STKAFTER.
    dependent induction STAR; ii; ss. inv H; ss.
  - des.
    exploit IHSTAR; et.
    { inv H; ss; try (by esplits; et).
      - des_ifs. esplits; et.
      - des_ifs.
        + ss. clarify. inv STAR; ss. inv H; ss.
        + esplits; et.
    }
    i; des.
    inv H; ss; try (by esplits; et).
Qed.

Lemma starN_plus_iff
      G ST (step: Senv.t -> G -> ST -> trace -> ST -> Prop) se ge st0 tr st1
  :
    (exists n, starN step se ge n st0 tr st1 /\ (n > 0)%nat) <-> plus step se ge st0 tr st1
.
Proof.
  split; i; des.
  - destruct n; ss.
    { xomega. }
    ginduction H; ii; ss.
    { xomega. }
    clarify. inv H0.
    + eapply plus_star_trans; et.
      { apply plus_one; et. }
      { apply star_refl; et. }
    + eapply plus_trans; et.
      { apply plus_one; et. }
      eapply IHstarN; et. xomega.
  - inv H. apply star_starN in H1. des. exists (Datatypes.S n). esplits; et.
    { econs; et. }
    { xomega. }
Qed.

Lemma lift_plus
      tse tge st_tgt0 tr st_tgt1
      (PLUS: plus Linear.step tse tge st_tgt0 tr st_tgt1)
      (DUMMYTGT: wf_tgt st_tgt0)
      (STKAFTER: get_stack st_tgt1 <> [])
  :
    <<PLUS: plus step tse tge st_tgt0 tr st_tgt1>> /\ <<DUMMYTGT: wf_tgt st_tgt1>>
.
Proof.
  apply starN_plus_iff in PLUS. des. apply lift_starN_stronger in PLUS; et. des. esplits; et.
  apply starN_plus_iff; et.
Qed.




Section SIMMODSEM.

Variable skenv_link_src skenv_link_tgt: SkEnv.t.
Variable sm_link: SimMem.t.
Variable prog: LTL.program.
Variable tprog: Linear.program.
Let md_src: Mod.t := (LTLC.module prog).
Let md_tgt: Mod.t := (LinearC.module tprog).
Hypothesis (INCLSRC: SkEnv.includes skenv_link_src md_src.(Mod.sk)).
Hypothesis (INCLTGT: SkEnv.includes skenv_link_tgt md_tgt.(Mod.sk)).
Hypothesis (WFSRC: SkEnv.wf skenv_link_src).
Hypothesis (WFTGT: SkEnv.wf skenv_link_tgt).
Hypothesis TRANSL: match_prog prog tprog.
Let ge := (SkEnv.revive (SkEnv.project skenv_link_src md_src.(Mod.sk)) prog).
Let tge := (SkEnv.revive (SkEnv.project skenv_link_tgt md_tgt.(Mod.sk)) tprog).
Definition msp: ModSemPair.t :=
  ModSemPair.mk (md_src.(Mod.modsem) skenv_link_src) (md_tgt.(Mod.modsem) skenv_link_tgt) tt sm_link
.

Inductive match_states
          (sm_init: SimMem.t)
          (idx: nat) (st_src0: LTL.state) (st_tgt0: Linear.state) (sm0: SimMem.t): Prop :=
| match_states_intro
    (MATCHST: Linearizeproof.match_states st_src0 st_tgt0)
    (MCOMPATSRC: st_src0.(LTLC.get_mem) = sm0.(SimMem.src))
    (MCOMPATTGT: st_tgt0.(LinearC.get_mem) = sm0.(SimMem.tgt))
    (DUMMYTGT: wf_tgt st_tgt0)
    (MEASURE: measure st_src0 = idx)
.

Theorem make_match_genvs :
  SimSymbId.sim_skenv (SkEnv.project skenv_link_src md_src.(Mod.sk))
                      (SkEnv.project skenv_link_tgt md_tgt.(Mod.sk)) ->
  Genv.match_genvs (match_globdef (fun _ f tf => transf_fundef f = OK tf) eq prog) ge tge.
Proof. subst_locals. eapply SimSymbId.sim_skenv_revive; eauto. Qed.

Theorem sim_modsem
  :
    ModSemPair.sim msp
.
Proof.
  eapply match_states_sim with (match_states := match_states) (match_states_at := top4) (sound_state := SoundTop.sound_state);
    eauto; ii; ss.
  - instantiate (1:= Nat.lt). apply lt_wf.
  - eapply SoundTop.sound_state_local_preservation.
  - (* init bsim *)
    destruct sm_arg; ss. clarify.
    inv SIMARGS; ss. clarify.
    inv INITTGT.
    exploit make_match_genvs; eauto. { apply SIMSKENV. } intro SIMGE. des.
    folder.
    exploit (bsim_internal_funct_id SIMGE); et. i; des.
    generalize (sig_preserved fd_src (Internal fd) MATCH); intro SGEQ. ss.
    destruct fd_src; ss.
    eexists. eexists (SimMemId.mk _ _).
    esplits; cycle 2.
    + econs; eauto; ss.
      * inv TYP. rpapply match_states_call; eauto.
        { instantiate (1:= [LTLC.dummy_stack (fn_sig fd) ls_init]). econs; eauto.
          - econs; et.
          - econs; et.
        }
      * rr. ss. esplits; et.
      (* * ss. esplits; et. *)
    + rewrite SGEQ.
      rpapply LTLC.initial_frame_intro; revgoals; [ f_equal; et | .. ]; eauto with congruence.
      folder. rewrite FPTR. ss.
    + ss.
  - (* init progress *)
    des. inv SAFESRC.
    inv SIMARGS; ss.
    exploit make_match_genvs; eauto. { apply SIMSKENV. } intro SIMGE.
    exploit (Genv.find_funct_match_genv SIMGE); eauto. i; des. ss. unfold bind in *. folder. des_ifs.
    inv TYP.
    unfold transf_function in *. unfold bind in *. des_ifs.
    esplits; eauto. econs; eauto.
    + folder. rewrite <- FPTR. rewrite H. eauto.
    + econs; eauto.
      * ss. congruence.
      * ss. rewrite <- VALS. et.
    + ss.
    + ss.
  - (* call wf *)
    inv MATCH; ss. destruct sm0; ss. clarify.
    u in CALLSRC. des. inv CALLSRC. inv MATCHST; ss.
  - (* call fsim *)
    inv MATCH; ss. destruct sm0; ss. clarify.
    inv CALLSRC. inv MATCHST; ss.
    folder.
    esplits; eauto.
    + econs; eauto.
      * folder. des.
        r in TRANSL. r in TRANSL.
        exploit (SimSymbId.sim_skenv_revive TRANSL); eauto.
        { apply SIMSKENV. }
        intro GE.
        apply (fsim_external_funct_id GE); ss.
      * des. esplits; eauto. eapply SimSymb.simskenv_func_fsim; eauto; ss. inv SIMSKENV. ss.
    + econs; ss; eauto.
      * instantiate (1:= SimMemId.mk _ _). ss.
      * ss.
    + ss.
  - (* after fsim *)
    inv AFTERSRC.
    inv SIMRET. ss. exists sm_ret. destruct sm_ret; ss. clarify.
    inv MATCH; ss. inv MATCHST; ss.
    esplits; eauto.
    + econs; eauto.
    + econs; ss; eauto.
      * destruct retv_src, retv_tgt; ss. clarify. econs; eauto.
        { clear - H5.
          inv H5.
          { econs; et. }
          ss. des_ifs. econs; et.
          inv H; econs; et.
        }
      * clear - DUMMYTGT. unfold wf_tgt in *. des. destruct ts; ss. unfold dummy_stack, dummy_function in *. des_ifs; ss; clarify; esplits; et.
  - (* final fsim *)
    inv MATCH. inv FINALSRC; inv MATCHST; ss.
    inv H3; ss. inv H4; ss. destruct sm0; ss. clarify.
    eexists (SimMemId.mk _ _). esplits; ss; eauto.
    rr in DUMMYTGT. des. ss. clarify.
    assert(sg_init = sg_init0).
    { inv H1; ss. unfold transf_function, bind in *. des_ifs. }
    clarify.
    (* repeat f_equal; et. *)
  - esplits; eauto.
    { apply LTLC.modsem_receptive; et. }
    inv MATCH.
    ii. inv STEPSRC. hexploit (@transf_step_correct prog skenv_link_src skenv_link_tgt); eauto.
    { inv SIMSKENV. inv SIMSKELINK. ss. clarify. }
    { apply make_match_genvs; eauto. apply SIMSKENV. }
    i; des.
    + exploit lift_plus; et.
      { ii. inv H0; try inv STACKS; ss; clarify; et; inv H2; ss. }
      intro TT; des.
      esplits; eauto.
      * left. eapply spread_dplus; eauto.
        { eapply modsem_determinate; eauto. }
      * instantiate (1:= SimMemId.mk _ _). econs; ss.
    + clarify.
      esplits; et.
      * right. esplits; et.
        { eapply star_refl. }
      * instantiate (1:= SimMemId.mk _ _). econs; ss.
        
Unshelve.
  all: ss; try (by econs).
Qed.

End SIMMODSEM.




Section SIMMOD.

Variable prog: LTL.program.
Variable tprog: Linear.program.
Hypothesis TRANSL: match_prog prog tprog.

Definition mp: ModPair.t :=
  ModPair.mk (LTLC.module prog) (LinearC.module tprog) tt
.

Theorem sim_mod
  :
    ModPair.sim mp
.
Proof.
  econs; ss.
  - r. admit "easy - see DeadcodeproofC".
  - ii. eapply sim_modsem; eauto.
Unshelve.
  all: ss.
Qed.

End SIMMOD.