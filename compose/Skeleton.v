Require Import CoqlibC.
Require Export GlobalenvsC.
Require Import Memory.
Require Export ASTC.
Require Import MapsC.
Require Import Values.
Require Import Linking.

Set Implicit Arguments.

Generalizable Variables F.



Definition is_gvar F V (gd: globdef F V): bool :=
  match gd with
  | Gvar _ => true
  | _ => false
  end
.

(* I don't want it to be "AST.program"-dependent, because of Ctypes.program *)
(* TODO: In high level, prog_public can be dropped, as the data is already linked. Is it really so? *)
(* Definition flesh F V := list (ident * globdef F V)%type. *)

(* Skeleton Genv *)
Module SkEnv.

  (* TODO: Fix properly to cope with Ctypes.fundef *)
  Definition t := Genv.t (AST.fundef signature) unit.

  Inductive wf (skenv: t): Prop :=
  | wf_intro
    (SYMBDEF: forall
        id blk
        (SYMB: skenv.(Genv.find_symbol) id = Some blk)
     ,
       <<DEF: exists skd, skenv.(Genv.find_def) blk = Some skd>>)
    (DEFSYMB: forall
        blk skd
        (DEF: skenv.(Genv.find_def) blk = Some skd)
     ,
       <<SYMB: exists id, skenv.(Genv.find_symbol) id = Some blk>>)
  .

  Inductive project_spec (skenv: t) (keep: ident -> Prop)
            (skenv_proj: t): Prop :=
  | project_spec_intro
      (* (PUBLIC: skenv_proj.(Genv.genv_public) = []) *)
      (* TODO: is this OK? Check if this info affects semantics except for linking *)
      (PUBLIC: skenv_proj.(Genv.genv_public) = skenv.(Genv.genv_public))
      (NEXT: skenv.(Genv.genv_next) = skenv_proj.(Genv.genv_next))
      (* (SYMBKEEP: forall *)
      (*     id *)
      (*     (KEEP: keep id) *)
      (*     blk *)
      (*     (BIG: skenv.(Genv.find_symbol) id = Some blk) *)
      (*   , *)
      (*     (<<SMALL: skenv_proj.(Genv.find_symbol) id = Some blk>>)) *)
      (SYMBKEEP: forall
          id
          (KEEP: keep id)
        ,
          (<<KEEP: skenv_proj.(Genv.find_symbol) id = skenv.(Genv.find_symbol) id>>))
      (SYMBDROP: forall
          id
          (DROP: ~ keep id)
        ,
          <<NONE: skenv_proj.(Genv.find_symbol) id = None>>)
      (* (DEFKEEP: forall *)
      (*     id blk *)
      (*     (INV: skenv.(Genv.invert_symbol) blk = Some id) *)
      (*     (KEEP: keep id) *)
      (*     gd *)
      (*     (BIG: skenv.(Genv.find_def) id = Some gd) *)
      (*   , *)
      (*     <<SMALL: skenv_proj.(Genv.find_def) id = Some gd>>) *)
      (DEFKEEP: forall
          id blk
          (INV: skenv.(Genv.invert_symbol) blk = Some id)
          (KEEP: keep id)
        ,
          <<SMALL: skenv_proj.(Genv.find_def) blk = skenv.(Genv.find_def) blk>>)
      (DEFDROP: forall
          id blk
          (INV: skenv.(Genv.invert_symbol) blk = Some id)
          (DROP: ~ keep id)
        ,
          <<SMALL: skenv_proj.(Genv.find_def) blk = None>>)
      (DEFORPHAN: forall (* TODO: is it needed? *)
          blk
          (INV: skenv.(Genv.invert_symbol) blk = None)
        ,
          <<SMALL: skenv_proj.(Genv.find_def) blk = None>>)
  .

  (* NOTE: it is total function! This is helpful because we don't need to state bsim of this, like
"(PROGRESS: project src succed -> project tgt succeed) /\ (BSIM: project tgt ~ projet src)".
I think "sim_skenv_monotone" should be sufficient.
   *)
  Definition project (skenv: t) (keep: ident -> bool): t :=
    (skenv.(Genv_filter_symb) (fun id => keep id))
    .(Genv_map_defs) (fun blk gd => (do id <- skenv.(Genv.invert_symbol) blk; assertion(keep id); Some gd))
  .

  Lemma project_impl_spec
        skenv (keep: ident -> bool)
    :
      <<PROJ: project_spec skenv keep (project skenv keep)>>
  .
  Proof.
    u.
    unfold project in *. ss.
    econs; eauto; unfold Genv.find_symbol, Genv.find_def, Genv_map_defs in *; ss; ii.
    - rewrite PTree_filter_key_spec. des_ifs.
    - rewrite PTree_filter_key_spec. des_ifs.
    - rewrite PTree_filter_map_spec. des_ifs.
      u. des_ifs.
    - rewrite PTree_filter_map_spec. des_ifs.
      u. des_ifs.
    - rewrite PTree_filter_map_spec. des_ifs.
      u. des_ifs.
  Qed.

  Lemma project_spec_preserves_wf
        skenv
        (WF: wf skenv)
        keep skenv_proj
        (PROJ: project_spec skenv keep skenv_proj)
    :
      <<WF: wf skenv_proj>>
  .
  Proof.
    inv WF. inv PROJ.
    econs; eauto.
    - ii.
      destruct (classic (keep id)).
      + erewrite SYMBKEEP in *; eauto.
        erewrite DEFKEEP; eauto.
        apply Genv.find_invert_symbol; ss.
      + erewrite SYMBDROP in *; eauto. ss.
    - ii.
      destruct (Genv.invert_symbol skenv blk) eqn:T; cycle 1.
      { exploit DEFORPHAN; eauto. i; des. clarify. }
      rename i into id.

      exploit Genv.invert_find_symbol; eauto. intro TT.
      destruct (classic (keep id)).
      + esplits; eauto. erewrite SYMBKEEP; eauto.
      + exploit DEFDROP; eauto. i; des.
        exploit SYMBDEF; eauto. i; des. clarify.
  Qed.

  (* Definition project (skenv: t) (ids: list ident): option SkEnv.t. *)
  (*   admit "". *)
  (* Defined. *)

  Definition internals (skenv: t): list block :=
    List.map fst (skenv.(Genv.genv_defs).(PTree.elements))
  .

  (* We will not need this for now. Fix it when we need it (dynamic linking/incremental compilation) *)
  Definition filter_symbols (skenv: t) (symbols: list ident): t :=
    skenv.(Genv_filter_symb) (fun id => List.in_dec ident_eq id symbols)
  .

  (* Note: We only remove definitions. One can still get the address of external identifier. *)
  Definition revive `{HasExternal F} {V} (skenv: SkEnv.t) (prog: AST.program F V): Genv.t F V :=
    skenv.(Genv_map_defs) (fun blk gd => (do id <- skenv.(Genv.invert_symbol) blk;
                                            do gd <- prog.(prog_defmap) ! id;
                                            assertion (negb (is_external gd));
                                            Some gd))
  .

  Inductive genv_precise `{HasExternal F} {V} (ge: Genv.t F V) (p: program F V): Prop :=
  | genv_compat_intro
      (FIND_MAP: forall id g,
          p.(prog_defmap) ! id = Some g ->
          (exists b, Genv.find_symbol ge id = Some b /\
                     Genv.find_def ge b = if negb (is_external g) then Some g else None))
      (FIND_MAP_INV: forall id b g,
          (Genv.find_symbol ge id = Some b /\ Genv.find_def ge b = Some g) ->
          p.(prog_defmap) ! id = Some g)
  .

  Lemma revive_no_external
        `{HasExternal F} V (prog: AST.program F V)
        skenv blk gd
        (DEF: Genv.find_def (SkEnv.revive skenv prog) blk = Some gd)
        (EXTERNAL: is_external gd)
    :
      False
  .
  Proof.
    unfold revive in *.
    apply_all_once Genv_map_defs_def. des.
    u in *. des_ifs.
  Qed.

  Lemma revive_precise
        `{HasExternal F} V
        skenv (prog: AST.program F V)
        (DEFS0: forall id, In id prog.(prog_defs_names) -> is_some (skenv.(Genv.find_symbol) id))
        (WF: wf skenv)
    :
      <<PRECISE: genv_precise (SkEnv.revive skenv prog) prog>>
  .
  Proof.
    assert(DEFS: prog.(defs) <1= fun id => is_some (skenv.(Genv.find_symbol) id)).
    { ii; ss. eapply DEFS0; eauto. u in *. des_sumbool. ss. }
    clear DEFS0.
    econs; eauto; i; ss; cycle 1.
    - des.
      unfold revive in *.
      apply_all_once Genv_map_defs_def. des; ss.
      rewrite Genv_map_defs_symb in *. u in *. des_ifs_safe. simpl_bool.
      apply_all_once Genv.invert_find_symbol.
      determ_tac Genv.genv_vars_inj.
    - des.
      dup H. u in DEFS. unfold ident in *. spc DEFS.
      exploit DEFS; clear DEFS.
      { unfold proj_sumbool. des_ifs; ss. exfalso. apply n. eapply prog_defmap_spec; eauto. }
      i; des.
      des_ifs_safe.
      esplits; eauto.
      unfold revive. u.
      unfold Genv.find_def, Genv_map_defs. cbn. rewrite PTree_filter_map_spec.
      clear_tac.
      inv WF.
      exploit SYMBDEF; eauto. i; des.
      unfold Genv.find_def in *. rewrite H1. cbn.
      apply Genv.find_invert_symbol in Heq.
      des_ifs; ss.
  Qed.

  Print Genv.public_symbol.
  Definition privs (skenv: SkEnv.t): ident -> bool :=
    fun id =>
      match skenv.(Genv.find_symbol) id with
      | Some _ => negb (proj_sumbool (in_dec ident_eq id skenv.(Genv.genv_public)))
      | None => false
      end
  .

  Definition get_sig (skdef: (AST.fundef signature)): signature :=
    match skdef with
    | Internal sg0 => sg0
    | External ef => ef.(ef_sig)
    end
  .

  Definition empty: t := @Genv.empty_genv _ _ [].

End SkEnv.

Hint Unfold SkEnv.empty.


(* Hint Unfold SkEnv.revive. *)



Definition skdef_of_gdef {F V} (get_sg: F -> signature)
           (gdef: globdef (AST.fundef F) V): globdef (AST.fundef signature) unit :=
  match gdef with
  | Gfun (Internal f) => Gfun (Internal f.(get_sg))
  | Gfun (External ef) => Gfun (External ef)
  | Gvar v => Gvar (mkglobvar tt v.(gvar_init) v.(gvar_readonly) v.(gvar_volatile))
  end
.

Lemma skdef_of_gdef_is_external_gd
      F V get_sg
      (gdef: globdef (AST.fundef F) V)
  :
    is_external_gd (skdef_of_gdef get_sg gdef) = is_external_gd gdef
.
Proof.
  u. des_ifs. ss. clarify.
Qed.

Definition skdefs_of_gdefs {F V} (get_sg: F -> signature)
           (gdefs: list (ident * globdef (AST.fundef F) V)):
  list (ident * globdef (AST.fundef signature) unit) :=
  map (update_snd (skdef_of_gdef get_sg)) gdefs
.

(* Skeleton *)
Module Sk.

  Definition t := AST.program (AST.fundef signature) unit.

  Definition load_skenv: t -> SkEnv.t := @Genv.globalenv (AST.fundef signature) unit.
  (* No coercion! *)

  Definition load_mem: t -> option mem := @Genv.init_mem (AST.fundef signature) unit.
  (* No coercion! *)

  Lemma load_skenv_wf
        sk
    :
      <<WF: SkEnv.wf sk.(load_skenv)>>
  .
  Proof.
    unfold load_skenv. u.
    admit "easy. follow induction proofs on Globalenvs.v".
  Qed.

  Definition of_program {F V} (get_sg: F -> signature) (prog: AST.program (AST.fundef F) V): t :=
    mkprogram (skdefs_of_gdefs get_sg prog.(prog_defs)) prog.(prog_public) prog.(prog_main)
  .

  Definition wf_match_fundef CTX F1 F2 (match_fundef: CTX -> fundef F1 -> fundef F2 -> Prop): Prop := forall
      ctx f1 f2
      (MATCH: match_fundef ctx f1 f2)
    ,
      (<<EXT: exists ef, f1 = External ef /\ f2 = External ef>>)
      \/ (<<INT: exists fd1 fd2, f1 = Internal fd1 /\ f2 = Internal fd2>>)
  .

  Definition is_external_weak F (f: AST.fundef F): bool :=
    match f with
    | Internal _ => false
    | External _ => true
    end
  .

  Lemma match_program_eq
        F1 V1 F2 V2
        `{Linker (fundef F1)} `{Linker V1}
        match_fundef match_varinfo
        (p1: AST.program (fundef F1) V1)
        (p2: AST.program (fundef F2) V2)
        (MATCH: match_program match_fundef match_varinfo p1 p2)
        fn_sig1 fn_sig2
        (WF: wf_match_fundef match_fundef)
    :
      <<EQ: Sk.of_program fn_sig1 p1 = Sk.of_program fn_sig2 p2>>
  .
  Proof.
    rr in MATCH. des.
    unfold of_program. r. f_equal; ss.
    revert MATCH. generalize p1 at 1 as CTX. i.
    destruct p1, p2; ss.
    clear - MATCH WF.
    ginduction prog_defs; ii; ss; inv MATCH; ss.
    erewrite IHprog_defs; eauto. f_equal; eauto.
    inv H3. destruct a, b1; ss. clarify.
    inv H2; ss.
    - unfold update_snd. exploit WF; eauto. i; des; clarify; ss.
      + repeat f_equal. admit "ez".
    - inv H1. ss.
  Qed.

  Let match_fundef F0 F1 (_: unit): AST.fundef F0 -> AST.fundef F1 -> Prop :=
    fun f0 f1 =>
      match f0, f1 with
      | Internal _, Internal _ => true
      | External ef0, External ef1 => external_function_eq ef0 ef1
      | _, _ => false
      end
  .

  Lemma of_program_prog_defmap
        F V
        (p: AST.program (AST.fundef F) V)
        get_sg
    :
      <<SIM: forall id, option_rel (@Linking.match_globdef unit _ _ _ _ _
                                                           (@match_fundef _ _)
                                                           top2
                                                           tt)
                                   (p.(prog_defmap) ! id) ((of_program get_sg p).(prog_defmap) ! id)>>
  .
  Proof.
    admit "ez".
  Qed.

  Lemma of_program_defs
        F V
        get_sg
        (p: AST.program (AST.fundef F) V)
    :
      (of_program get_sg p).(defs) = p.(defs)
  .
  Proof.
    destruct p; ss.
    Local Opaque in_dec.
    u; ss.
    Local Transparent in_dec.
    apply Axioms.functional_extensionality. intro id; ss.
    Check (in_dec ident_eq id (map fst prog_defs)).
    rewrite map_map. ss.
  Qed.

  Lemma of_program_internals
        F V
        get_sg
        (p: AST.program (AST.fundef F) V)
    :
      (of_program get_sg p).(internals) = p.(internals)
  .
  Proof.
    unfold internals.
    destruct p; ss.
    apply Axioms.functional_extensionality. intro id; ss.
    Local Opaque prog_defmap.
    u.
    exploit (of_program_prog_defmap). i. inv H.
    - rewrite <- H2. rewrite <- H1. ss.
    - des_ifs_safe. inv H2; ss. unfold match_fundef in *. des_ifs. des_sumbool. clarify.
  Qed.

  Lemma of_program_internals'
        F V
        get_sg
        (p: AST.program (AST.fundef F) V)
    :
      (of_program get_sg p).(internals') = p.(internals')
  .
  Proof.
    destruct p; ss.
    unfold internals', of_program. ss.
    apply Axioms.functional_extensionality. intro id; ss.
    unfold skdefs_of_gdefs. rewrite find_map.
    unfold compose. ss.
    unfold ident.
    (* Print Instances HasExternal. *)
    replace (fun (x: positive * globdef (fundef F) V) =>
               ident_eq id (fst x) && is_external_gd (skdef_of_gdef get_sg (snd x))) with
        (fun (x: positive * globdef (fundef F) V) => ident_eq id (fst x) && is_external (snd x)).
    - u. des_ifs.
    - apply Axioms.functional_extensionality. i; ss.
      rewrite skdef_of_gdef_is_external_gd. ss.
  Qed.

  Definition empty: t := (mkprogram [] [] 1%positive).

End Sk.

Hint Unfold skdef_of_gdef skdefs_of_gdefs Sk.load_skenv Sk.load_mem Sk.empty.

Lemma include_defs_lift
      F V get_sg
      (prog: AST.program (AST.fundef F) V) skenv_link
      (INCL: include_defs eq (Sk.of_program get_sg prog) skenv_link)
  :
    <<INCL: include_defs
              (fun fdef skdef => skdef_of_gdef get_sg fdef = skdef) prog skenv_link>>
.
Proof.
  {
    ii. exploit (INCL id (skdef_of_gdef get_sg def0)).
    - clear - DEF.
      unfold prog_defmap in *. destruct prog. ss.
      exploit (PTree_Properties.of_list_related (fun e1 e2 => @skdef_of_gdef _ V get_sg e1 = e2)); cycle 1.
      { i. inv H; rewrite DEF in *; clarify. rewrite <- H1. ss. }
      {
        eapply list_forall2_imply.
        - eapply list_forall2_map.
        - i. ss. clarify.
      }
    - i. des. esplits; eauto.
  }
Qed.





(* Question: How does genv affect semantics? *)
Module PLAYGROUND.

Require Import RTL.

Theorem eval_addressing_irr
        F V
        (ge0 ge1: Genv.t F V)
        (SYMB: all1 (Genv.find_symbol ge0 =1= Genv.find_symbol ge1))
  :
    <<OP: all3 (Op.eval_addressing ge0 =3= Op.eval_addressing ge1)>>
.
Proof.
  u.
  ii. unfold Op.eval_addressing. des_ifs.
  destruct x1; ss.
  { des_ifs. unfold Genv.symbol_address. rewrite SYMB. ss. }
Qed.

Theorem eval_operation_irr
        F V
        (ge0 ge1: Genv.t F V)
        (SYMB: all1 (Genv.find_symbol ge0 =1= Genv.find_symbol ge1))
  :
    <<OP: all4 (Op.eval_operation ge0 =4= Op.eval_operation ge1)>>
.
Proof.
  u.
  ii.
  destruct x1; ss.
  { des_ifs. unfold Genv.symbol_address. rewrite SYMB. ss. }
  { erewrite eval_addressing_irr; eauto. }
Qed.

Goal forall ge0 ge1 st0 tr st1
            (STEP: step ge0 st0 tr st1)
            (SYMB: all1 (Genv.find_symbol ge0 =1= Genv.find_symbol ge1))
  ,
    <<STEP: step ge1 st0 tr st1>>
.
Proof.
  i. inv STEP; try (by econs; eauto).
  - erewrite eval_operation_irr in *; eauto. econs; eauto.
  - erewrite eval_addressing_irr in *; eauto. econsby eauto.
  - erewrite eval_addressing_irr in *; eauto. econsby eauto.
  - econs; eauto.
    unfold find_function_ptr in *. des_ifs_safe. rewrite SYMB in *. ss.
  - econs; eauto.
    unfold find_function_ptr in *. des_ifs_safe. rewrite SYMB in *. ss.
  - eapply Events.eval_builtin_args_preserved with (ge2 := ge1) in H0; eauto.
    econs; eauto. eapply Events.external_call_symbols_preserved; eauto.
    econs; eauto.
    split.
    admit "Publics".
    Print Genv.block_is_volatile.
    admit "Genv.find_def with Gvar. (volatile)".
  - econs; eauto.
    unfold Genv.find_funct in *. des_ifs.
    unfold Genv.find_funct_ptr in *.
    admit "Genv.find_def with Gfun. internals".
  - unfold Genv.find_funct, Genv.find_funct_ptr in *. des_ifs.
    admit "Genv.find_def with Gfun. externals".
Abort.

End PLAYGROUND.



