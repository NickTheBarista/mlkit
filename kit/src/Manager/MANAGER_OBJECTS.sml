
signature MANAGER_OBJECTS =
  sig
    type modcode and target and linkinfo and StringTree

    type absprjid  

    (* Absolute project identifiers; project identifiers with absolute
       path information (e.g.,
       /home/mael/kit/ml-yacc-lib/ml-yacc-lib.pm); there is one
       exception: the project identifier basislib.pm is unique---it
       cannot be redefined---and it must be referred to without a
       path. This special treatment of basislib.pm makes it possible
       to relocate the distribution of the kit, with the basis library
       compiled. *)
		    
    structure TyName : TYNAME

    structure SystemTools :
      sig
	val delete_file : string -> unit
      end

    structure ModCode :
      sig
	val empty : modcode
	val seq : modcode * modcode -> modcode
	val mk_modcode : target * linkinfo * string -> modcode 
	(* Use emit or mk_exe to actually emit code.
	 * The string is a program unit name. *)
	val exist : modcode -> bool
	val emit : absprjid * modcode -> modcode       
	val mk_exe : absprjid * modcode * string list * string -> unit  
        (* produces executable `string' in target directory the string
	 * list is a list of external object files as generated by a
	 * foreign compiler (e.g., gcc). *)
	val size : modcode -> int (* for debugging *)
	(* write the file absprjid[.pm -> .ul] *)
	val mk_uoFileList : absprjid * modcode -> unit
	val deleteTimeStampFile : absprjid -> unit
      end

    type filename (*= string*)
    val mk_filename : string -> filename
    val filename_to_string : filename -> string
    val pmdir : unit -> string (* based on flags, returns a relative path to a directory
				* in which to store object code. *)

    type funstamp and funid
    structure FunStamp :
      sig
	val new : funid -> funstamp
	val from_filemodtime : filename -> funstamp option
	val modTime : funstamp -> Time.time option
	val eq : funstamp * funstamp -> bool
	val pu : funstamp Pickle.pu
      end

    val funid_from_filename : filename -> funid
    val funid_to_filename : funid -> filename

    type IntFunEnv and IntBasis and ElabEnv and strexp and strid
     and InfixBasis and ElabBasis and opaq_env

    type BodyBuilderClos = {infB: InfixBasis,
			    elabB: ElabBasis,
			    absprjid: absprjid,
			    filename: string,
			    opaq_env: opaq_env,
			    T: TyName.TyName list,
			    resE: ElabEnv}

    structure IntFunEnv :
      sig
	val empty : IntFunEnv
	val initial : IntFunEnv
	val plus : IntFunEnv * IntFunEnv -> IntFunEnv
	val add : funid * (absprjid * funstamp * strid * ElabEnv * BodyBuilderClos * IntBasis) * IntFunEnv -> IntFunEnv
	val lookup : IntFunEnv -> funid -> absprjid * funstamp * strid * ElabEnv * BodyBuilderClos * IntBasis  
	val restrict : IntFunEnv * funid list -> IntFunEnv
	val enrich : IntFunEnv * IntFunEnv -> bool  (* using funstamps *)
	val layout : IntFunEnv -> StringTree
(*	val pu : IntFunEnv Pickle.pu *)
      end

    type IntSigEnv and sigid
    structure IntSigEnv :
      sig
	val empty : IntSigEnv
	val initial : IntSigEnv
	val plus : IntSigEnv * IntSigEnv -> IntSigEnv
	val add : sigid * TyName.Set.Set * IntSigEnv -> IntSigEnv      (* tynames that occurs free in a signature *)
	val lookup : IntSigEnv -> sigid -> TyName.Set.Set              (* dies on failure *)
	val restrict : IntSigEnv * sigid list -> IntSigEnv
	val enrich : IntSigEnv * IntSigEnv -> bool
	val layout : IntSigEnv -> StringTree
(*	val pu : IntSigEnv Pickle.pu *)
      end

    type CEnv and CompileBasis and longtycon and longid and longstrid
    structure IntBasis :
      sig
	val mk : IntFunEnv * IntSigEnv * CEnv * CompileBasis -> IntBasis
	val un : IntBasis -> IntFunEnv * IntSigEnv * CEnv * CompileBasis
	val empty : IntBasis
	val plus : IntBasis * IntBasis -> IntBasis
	val match : IntBasis * IntBasis -> IntBasis
	val agree : longstrid list * IntBasis * IntBasis -> bool   (* structure agreement *)
	val layout : IntBasis -> StringTree

	val enrich : IntBasis * IntBasis -> bool

	val initial : unit -> IntBasis
	val restrict : IntBasis * {funids:funid list, sigids:sigid list, longstrids: longstrid list,
				   longvids: longid list, longtycons: longtycon list} -> IntBasis
(*	val pu : IntBasis Pickle.pu *)
      end

    type Basis 

    structure Basis :
      sig
	val empty   : Basis
	val mk      : InfixBasis * ElabBasis * opaq_env * IntBasis -> Basis
	val un      : Basis -> InfixBasis * ElabBasis * opaq_env * IntBasis
	val plus    : Basis * Basis -> Basis
	val layout  : Basis -> StringTree

	val agree   : longstrid list * Basis * (Basis * TyName.Set.Set) -> bool
	val enrich  : Basis * (Basis * TyName.Set.Set) -> bool

	val initial : unit -> Basis

	val pu      : Basis Pickle.pu
      end

    type name
    structure Repository :
      sig

	(* Repositories map pairs of an absolute project identifier and a
           functor identifier to a repository object. Thus, a functor
           identifier (and hence a source file name) can be
           declared only once in each project. However, different functors
           with the same functor identifier may co-exist in different
           projects (similarly, for source file names). *)

	val clear : unit -> unit
	val delete_entries : absprjid * funid -> unit

	  (* Repository lookup's return the first entry for a (absprjid,funid)
	   * that is reusable (i.e. where all export (ty-)names are
	   * marked generative.) In particular, entries that have been added, 
	   * cannot be returned by a lookup, prior to executing `recover().' 
	   * The integer provided by the lookup functions can be given to the
	   * overwrite functions for owerwriting a particular entry. *)

	  (* The elaboration environment in the interpretation
	   * repository is supposed to be the elaboration result of
	   * the functor application/ unit; the environment is necessary 
	   * for checking if reuse is allowed. *)

	type elab_entry = InfixBasis * ElabBasis * longstrid list * (opaq_env * TyName.Set.Set) * 
	  name list * InfixBasis * ElabBasis * opaq_env

	type int_entry = funstamp * ElabEnv * IntBasis * longstrid list * name list * 
	  modcode * IntBasis

	type int_entry' = funstamp * ElabEnv * IntBasis * longstrid list * name list * 
	  modcode * IntBasis
	  
	val lookup_elab : (absprjid * funid) -> (int * elab_entry) option
	val lookup_int : (absprjid * funid) -> (int * int_entry) option    (* IntModules *) 
	val lookup_int' : (absprjid * funid) -> (int * int_entry') option  (* Manager *) 
	  
	val add_elab : (absprjid * funid) * elab_entry -> unit
	val add_int : (absprjid * funid) * int_entry -> unit          (* IntModules *) 
	val add_int' : (absprjid * funid) * int_entry' -> unit        (* Manager *)

	val owr_elab : (absprjid * funid) * int * elab_entry -> unit
	val owr_int : (absprjid * funid) * int * int_entry -> unit    (* IntModules *)

	val emitted_files : unit -> string list   (* returns the emitted files mentioned in the repository; *)
                                                  (* used for deleting files which are no longer mentioned. *)
	val recover : unit -> unit

          (* Before building a project the repository should be
	   * ``recovered'' meaning that all export names are marked
	   * generative (see NAME). Then, when an entry is reused,
	   * export names are marked non-generative; for an entry to
	   * be reused, all export names must be marked generative. *)

      end
    
  end