Require Import Maps.
Require Import AST.
Require Import Integers.
Require Import Values.
Require Import Memory.
Require Import Events.
Require Import Smallstep.
Require Import GlobalenvsC.
Require Import Asmregs.
Require Import LinkingC.
Require Import CoqlibC.
Require Import sflib.

Require Import ModSem Mod Skeleton System.
Require Export Syntax.

Set Implicit Arguments.

Local Open Scope asm.








Module Frame.

  (* Naming Candidates *)
  (* Module -> Short pronunciation. its shorhand "m" conflicts with "m" of "memory". *)
  (* StackFrame (Activation Record) -> Too long *)
  (* Frame -> Short, also it is quite clear (Frame is not used elsewhere in this level) *)

  Record t: Type := mk {
    ms: ModSem.t;
    rs_init: regset;
    st: ms.(ModSem.state); (* local state *)
  }
  .

  Definition update_st (fr0: t) (st0: fr0.(ms).(ModSem.state)): t :=
    (mk fr0.(ms) fr0.(rs_init) st0)
  .

(* Definition is_internal (fr0: t): Prop := fr0.(ms).(ModSem.is_internal) fr0.(st) fr0.(sg_arg) fr0.(rs_arg). *)
  (* Definition is_internal (fr0: t): Prop := fr0.(ms).(ModSem.is_internal) fr0.(st). *)

End Frame.



Module Ge.

  (* NAMING: Consistency with SkEnv.t -> GEnv.t? but this is confusing with Genv *)
  (* Record t: Type := mk { *)
  (*   mss: list ModSem.t; *)
  (* } *)
  (* . *)

  Definition t: Type := list ModSem.t.

  (* Note: nat is much more convenient in SimLoad. (find_fptr_owner bsim) && stating disjointness. *)
  (* If needed, fefactor later to hide these details *)

  (* Inductive find_fptr_owner (ge: t) (fptr: val) (ms: ModSem.t): Prop := *)
  (* | find_fptr_owner_intro *)
  (*     blk *)
  (*     (FPTR: fptr = Vptr blk Ptrofs.zero true) *)
  (*     (MODSEM: In ms ge) *)
  (*     if_sig *)
  (*     (INTERNAL: Genv.find_def ms.(ModSem.skenv) blk = Some (Gfun (Internal if_sig))) *)
  (* . *)

  Inductive find_fptr_owner (ge: t) (fptr: val) (ms: ModSem.t): Prop :=
  | find_fptr_owner_intro
      (MODSEM: In ms ge)
      if_sig
      (INTERNAL: Genv.find_funct ms.(ModSem.skenv) fptr = Some (Internal if_sig))
  .

  (* Inductive find_fptr_owner (ge: t) (fptr: val) (n: nat): Prop := *)
  (* | find_fptr_owner_intro *)
  (*     blk *)
  (*     (FPTR: fptr = Vptr blk Ptrofs.zero true) *)
  (*     ms *)
  (*     (MODSEM: List.nth_error ge n = Some ms) *)
  (*     if_sig *)
  (*     (INTERNAL: Genv.find_def ms.(ModSem.skenv) blk = Some (Gfun (Internal if_sig))) *)
  (* . *)

  (* Definition no_fptr_owner (ge: t) (fptr: val): Prop := *)
  (*   List.Forall (not <*> find_fptr_owner ge fptr) ge. *)

  Inductive disjoint (ge: t): Prop :=
  | disjoint_intro
      (DISJOINT: forall
          fptr ms0 ms1
          (FIND0: ge.(find_fptr_owner) fptr ms0)
          (FIND1: ge.(find_fptr_owner) fptr ms1)
        ,
          ms0 = ms1)
  .

End Ge.

Inductive state: Type :=
| Callstate
    (rs: regset)
    (m: mem)
    (frs: list Frame.t)
| State
    (frs: list Frame.t)
.

(* If both are some, they are equal. *)
Definition compat_sig (sg0: option signature) (sg1: option signature): bool :=
  match sg0 with
  | None => true
  | Some sg0 => match sg1 with
           | None => true
           | Some sg1 => signature_eq sg0 sg1
           end
  end
.

(* Naming -> fr0/fr1 instead of fr_fst fr_snd. There will not be many fr_fst simultaneously, so it is OK *)
Inductive step (ge: Ge.t): state -> trace -> state -> Prop :=
| step_call
    fr0 frs
    rs_arg m_arg
    (AT: fr0.(Frame.ms).(ModSem.at_external) fr0.(Frame.st) rs_arg m_arg)
  :
    step ge (State (fr0 :: frs))
         E0 (Callstate rs_arg m_arg (fr0 :: frs))

| step_init
    rs_arg m_arg frs
    fptr_arg ms
    (FPTR: fptr_arg = rs_arg PC)
    (MSFIND: ge.(Ge.find_fptr_owner) fptr_arg ms)
    st_init
    (INIT: ms.(ModSem.initial_frame) rs_arg m_arg st_init)
  :
    step ge (Callstate rs_arg m_arg frs)
         E0 (State ((Frame.mk ms rs_arg st_init) :: frs))

| step_internal
    fr0 frs
    (* (INTERNAL: fr0.(Frame.is_internal)) *)
    tr st0
    (STEP: fr0.(Frame.ms).(ModSem.step) fr0.(Frame.ms).(ModSem.globalenv) fr0.(Frame.st) tr st0)
  :
    step ge (State (fr0 :: frs))
         tr (State ((fr0.(Frame.update_st) st0) :: frs))
| step_return
    fr0 fr1 frs
    rs_ret
    (FINAL: fr0.(Frame.ms).(ModSem.final_frame) fr0.(Frame.rs_init) fr0.(Frame.st) rs_ret)
    st0
    (AFTER: fr1.(Frame.ms).(ModSem.after_external) fr1.(Frame.st) fr0.(Frame.rs_init) rs_ret
                                                   fr0.(Frame.st).(ModSem.get_mem fr0.(Frame.ms)) st0)
  :
    step ge (State (fr0 :: fr1 :: frs))
         E0 (State ((fr1.(Frame.update_st) st0) :: frs))
.




Section SEMANTICS.

  Variable p: program.
  (* Variable init_skel: Skel.t. *)
  (* Hypothesis LINKED: link_list (List.map Mod.skel p) = Some init_skel. *)

  Definition link_sk: option Sk.t := link_list (List.map Mod.sk p).

  (* Definition init_skenv: option SkEnv.t := option_map (@Genv.globalenv (fundef unit) unit) init_sk. *)
  (* Definition init_skenv (init_sk: Sk.t): SkEnv.t := (@Genv.globalenv (fundef (option signature)) unit) init_sk. *)

  Definition load_modsems (skenv: SkEnv.t): list ModSem.t :=
    (System.modsem skenv) :: List.map ((flip Mod.modsem) skenv) p.

  (* Definition init_mem: option mem := option_join (option_map (@Genv.init_mem (fundef unit) unit) init_sk). *)
  (* Definition init_mem (init_sk: Sk.t): option mem := (@Genv.init_mem (fundef (option signature)) unit) init_sk. *)

  (* Definition init_genv: option Ge.t := *)
  (*   option_map (fun skenv => (Ge.mk skenv (init_modsem skenv))) init_skenv. *)
  Definition load_genv (init_skenv: SkEnv.t): Ge.t := (load_modsems init_skenv).

  (* Making dummy_module that calls main? => Then what is sk of it? Memory will be different with physical linking *)
  Inductive initial_state: state -> Prop :=
  | initial_state_intro
      sk_link skenv_link m_init ge
      (INITSK: link_sk = Some sk_link)
      (INITSKENV: sk_link.(Sk.load_skenv) = skenv_link)
      (INITMEM: sk_link.(Sk.load_mem) = Some m_init)
      (INITGENV: load_genv (skenv_link) = ge)

      rs_init
      (INITREG: rs_init = init_regs (Genv.symbol_address skenv_link sk_link.(prog_main) Ptrofs.zero))
    :
      initial_state (Callstate rs_init m_init [])
  .

  Inductive final_state: state -> int -> Prop :=
  | final_state_intro
      fr0
      rs_ret
      (FINAL: fr0.(Frame.ms).(ModSem.final_frame) fr0.(Frame.rs_init) fr0.(Frame.st)
                                                    rs_ret)
      reti
      (RETPC: rs_ret#PC = Vnullptr)
      (RETV: rs_ret#RAX = Vint reti)
    :
      final_state (State [fr0]) reti
  .

  Definition semantics: semantics :=
    (Semantics_gen step initial_state final_state
                   (match link_sk with
                    | Some sk_link => load_genv sk_link.(Sk.load_skenv)
                    | None => nil
                    end)
                   (admit "dummy for now. it is not used"))
  .
  (* Note: I don't want to make it option type. If it is option type, there is a problem. *)
  (* I have to state this way:
```
Variable sem_src: semantics.
Hypothesis LOADSRC: load p_src = Some sem_src.
```
Then, sem_src.(state) is not evaluatable.
   *)
  (* However, if it is not option type.
```
Let sem_src := semantics prog.
```
Then, sem_src.(state) is evaluatable.
   *)

End SEMANTICS.

Hint Unfold link_sk load_modsems load_genv.


