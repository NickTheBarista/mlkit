
structure Man :
    sig
	val gen : {cmd:unit->string,
		   date:string,
		   extraOptions: (string * string list * string list)list,
		   version:string,
		   smlserver:bool} 
	    -> string
    end = 
  struct
    val homepage = "http://www.itu.dk/research/mlkit"
    val homepage_smlserver = "http://www.smlserver.org"
    fun concatWith2 (s1,s2) l =
	let fun loop nil = ""
	      | loop [x,y] = x ^ s2 ^ y
	      | loop (x::xs) = x ^ s1 ^ loop xs
	in loop l
	end

    fun addBetween (_ : 'a) ([] : 'a list) = [] : 'a list
      | addBetween _ (x::[]) = [x]
      | addBetween s (x::y::zz) = x:: s :: (addBetween s (y :: zz))

    fun printDefs () = 
      let
        val formatDefaults = 
	    List.mapPartial (fn ({default,long,short,...} : Flags.options)
                                => Option.map (fn d => case List.getItem short
                                                        of NONE => 
                                                           Option.valOf(Option.map (fn (l,_) => {name = "--" ^ l, value = d}) (List.getItem long))
                                                         | SOME (s,_) => {name = "-" ^ s, value = d} )
                                              default)
        val opts = formatDefaults (Flags.getOptions ())
        fun printDef {name,value} = String.concat ["\\fB", name, "\\fR", " ", value]
      in
        String.concat (addBetween ",\n" (List.map printDef opts))
      end

    fun printOpts extra =
      let
        fun pLong (l,short,kind) = let 
                               val kk = case kind of NONE => "" | SOME a => " " ^ a
                             in 
                               String.concat (addBetween ", " ((List.map (fn x => "--" ^ x ^ kk) l) @ (List.map (fn x => "-" ^ x ^ kk) short)))
                             end
        fun printOps ({long,short,desc,kind,...} : Flags.options) =
               String.concat [".IP \"\\fB", pLong (long,short,kind), "\\fR\" 4\n",".IX Item \"", pLong (long,short,kind), "\"\n",
                              desc,"\n"] 
        fun genExtra (l,s,d) = {long = [l], short = s, desc = String.concat d, kind = NONE, default = NONE}
        val extra' = List.map genExtra extra

        fun cmp c ([],[]) = EQUAL
          | cmp c ([],_) = LESS
          | cmp c (_,[]) = GREATER
          | cmp c (x::xs,y::ys) = case c (x,y) 
                                  of EQUAL => cmp c (xs,ys)
                                   | GREATER => GREATER
                                   | LESS => LESS
        val sort = Listsort.sort (fn ({long = l1,...},{long = l2,...}) => cmp String.compare (l1,l2))
      in
        String.concat (List.map printOps (sort (Flags.getOptions () @ extra')))
      end

    val developers = ["Lars Birkedal",
		      "Martin Elsman",
		      "Niels Hallenberg",
		      "Tommy H. Olesen",
		      "Mads Tofte",
		      "Carsten Varming"]

    val smlserver_developers = ["Martin Elsman",
				"Niels Hallenberg",
				"Carsten Varming"]
		     
    val contributers = ["Peter Bertelsen",
			"Vesa Karvonen",
			"Ken Friis Larsen", 
			"Henning Niss",
			"Peter Sestoft"]

    fun files exe = 
	[("/etc/" ^ exe ^ "/mlb-path-map", "System-wide configuration of library and runtime system locations"),
	 ("~/." ^ exe ^ "/mlb-path-map", "User specific configuration of library and runtime system locations")]

    fun header smlserver exe date version = 
	let val title = 
		if smlserver then
		    "\"Standard ML compiler for SMLserver\""
		else "\"MLKit - a compiler for Standard ML\"\n"
	in
	    String.concat [".TH ", exe, " 1 \"", date, "\" \"version ", 
			   version, "\" ",title]
	end
    
    fun name smlserver exe = 
	let val text = 
		if smlserver then
		    "Standard ML compiler for SMLserver"
		else "A fullblown Standard ML compiler"
	in 
	    ".SH NAME\n" ^ exe ^ " \\- " ^ text ^ " \n"
	end

    fun defaults() = 
	String.concat [".SH DEFAULTS\n", 
		       printDefs(),
		       ".\n"]

    fun synopsis exe = 
	String.concat [".SH SYNOPSIS\n",
		       exe, " [OPTION]... [file.sml | file.sig | file.mlb]\n\n",
		       "All possible options are listed below.\n"]

    fun description smlserver exe = 
	let val (name, result, homepage) = 
		if smlserver then ("SMLserver", "loadable bytecode files ",     homepage_smlserver)
		else              ("MLKit",     "an executable file\n.B run\n", homepage)
	in
	    String.concat[".SH DESCRIPTION\n",
			  "When invoked, \n.B ", exe, "\nwill compile the specified sources into ", result, 
			  "through a series of translation phases. Various options (see below) can be used to control the ",
			  "printing of intermediate forms and to which degree various optimizations are performed. If source files ",
			  "are organised in ML Basis Files (files with extension .mlb), the compiler will memoize symbol table ",
			  "information and object code in the dedicated MLB directories located together with the source files, so ",
			  "as to minimize necessary recompilation upon changes of source code.\n\n",
			  "To learn more about programming with ", name, ", consult the ", name, " web page at\n\n",
			  ".B ", homepage, "\n"]
	end

    fun options extraOptions = 
	String.concat [".SH OPTIONS\n", printOpts extraOptions]
          
    val exit = 
	String.concat [".SH EXIT STATUS\nExits with status 0 on success and -1 on failure.\n"]

    fun environment exe = 
	String.concat [".SH ENVIRONMENT\n",
		       "A library install directory must be provided ",
		       "in an environment variable SML_LIB or as a path-definition ",
		       "in either the system wide path-map /etc/" ^ exe ^ "/mlb-path-map ",
		       "or in the user's personal path-map ~/." ^ exe ^ "/mlb-path-map.\n"]

    val files = fn exe => 
        String.concat [".SH FILES\n",
		       String.concat (List.map (fn (f,e) => ".IP " ^ f ^ "\n" ^ e ^ "\n" ) (files exe))]
(*
    val diag = String.concat [".SH DIAGNOSTICS\n",
                              "The following diagnostics may be issued on stderr:\n"]
*)
    fun examples smlserver = 
	let val (name, title) =
		if smlserver then
		    ("SMLserver", "book \"SMLserver, A Functional Approach to Web Publishing\"")
		else ("MLKit", "MLKit manual \"Programming with Regions in the MLKit\"")
	in
	    String.concat [".SH EXAMPLES\n",
			   "For examples, consult the ", title,
			   ", which is available from the ", name, " home page.\n"]
	end
			   

    fun standard smlserver = 
	let val smlserver_maybe =
		if smlserver then "SMLserver is based on the MLKit. "
		else ""
	in
	    String.concat [".SH STANDARDS\n", smlserver_maybe,
			   "The MLKit implements Standard ML (Revised 1997) and has almost full ",
			   "support for the Standard ML Basis Library (version of 2002). See the MLKit home page ",
			   "for a detailed overview of the support for the Standard ML Basis Library.\n"]
	end

    fun credits smlserver =
	let val smlserver_maybe =
		if smlserver then 
		    ("SMLserver was developed by " ^ concatWith2 (", ", ", and ") smlserver_developers ^ ". ")
		else ""
	in 
	    String.concat [".SH CREDITS\n", smlserver_maybe,
			   "The MLKit (version 2 and beyond) was developed by ",
			   concatWith2 (", ",", and ") developers,
			   ". People who have contributed with bug-fixes and improvements include ",
			   concatWith2 (", ", ", and ") contributers,
			   ". Nick Rothwell and David N. Turner took part in the development of the MLKit version 1.\n"]
	end

    fun seealso smlserver = 
	let val smlserver_maybe =
		if smlserver then 
		    ("See the book \"SMLserver, A Functional Approach to Web Publishing\", available from the " ^
		     "SMLserver home page, for an introduction to programming efficient Web applications with SMLserver. " ^
		     "For installation instructions, see the file README_SMLSERVER in the distribution. ")
		else ""
	in
	    String.concat [".SH SEE ALSO\n", smlserver_maybe,
			   "See the MLKit manual \"Programming with Regions in the MLKit\", available from the ",
			   "MLKit home page\n\n",
			   ".B ", homepage, "\n\nfor an in-depth introduction to programming with regions in the MLKit.\n\n",
			   "The home page also provides an overview of which parts of ",
			   "the Standard ML Basis Library the MLKit implements, along with download and installation instructions."]
	end

    fun gen {cmd:unit->string,date:string,
	     extraOptions : (string * string list * string list) list,
	     version:string,
	     smlserver:bool} : string =
      let val exe = cmd()
      in String.concat [header smlserver exe date version,
			name smlserver exe,
			synopsis exe,
			defaults(),
			description smlserver exe,
			standard smlserver,
			examples smlserver,
			options extraOptions,
			exit,
			environment exe,
			files exe,
(*			diag, *)
			credits smlserver,
			seealso smlserver
			]
      end
  end
