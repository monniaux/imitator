(************************************************************
 *
 *                       IMITATOR
 * 
 * LIPN, Université Paris 13 (France)
 * 
 * Module description: "EF optimized" algorithm: minimization or minimization of a parameter valuation for which there exists a run leading to some states
 * 
 * File contributors : Étienne André
 * Created           : 2017/05/02
 * Last modified     : 2017/05/02
 *
 ************************************************************)


(************************************************************)
(************************************************************)
(* Modules *)
(************************************************************)
(************************************************************)
open OCamlUtilities
open ImitatorUtilities
open Exceptions
open AbstractModel
open Result
open AlgoStateBased
open Statistics


(************************************************************)
(************************************************************)
(* Class definition *)
(************************************************************)
(************************************************************)
class virtual algoEFopt =
	object (self) inherit algoStateBased as super
	
	(************************************************************)
	(* Class variables *)
	(************************************************************)
	
	val mutable current_optimum : LinearConstraint.p_linear_constraint option = None
	
	val mutable negated_optimum  : LinearConstraint.p_linear_constraint option = None
	
	
	(*------------------------------------------------------------*)
	(* Shortcuts *)
	(*------------------------------------------------------------*)
	
	(* Retrieve the parameter to be projected onto *)
	val parameter_index = match (Input.get_model ()).optimized_parameter with
		(* Shortcut for both algorithms *)
		| Minimize parameter_index | Maximize parameter_index -> parameter_index
		| _ -> raise (InternalError("A minimized parameter should be defined in the model to run EFmin"))
		
	val parameters_to_hide =
		(* First retrieve the parameter index (OCaml does not let us use the 'parameter_index' variable *)
		let parameter_index =
		match (Input.get_model ()).optimized_parameter with
		(* Shortcut for both algorithms *)
		| Minimize parameter_index | Maximize parameter_index -> parameter_index
		| _ -> raise (InternalError("A minimized parameter should be defined in the model to run EFmin"))
		in
			OCamlUtilities.list_remove_first_occurence parameter_index (Input.get_model ()).parameters
	

	(*------------------------------------------------------------*)
	(* Counters *)
	(*------------------------------------------------------------*)
	
	(* State discarded because of a not interesting parameter constraint *)
	val counter_discarded_state = create_discrete_counter_and_register "EFopt:state discarded" PPL_counter Verbose_low

	
	(************************************************************)
	(* Class methods *)
	(************************************************************)
	(*------------------------------------------------------------*)
	(* Instantiating min/max *)
	(*------------------------------------------------------------*)
	(* Function to remove upper bounds (if minimum) or lower bounds (if maximum) *)
	method virtual remove_bounds : Automaton.parameter_index list -> Automaton.parameter_index list -> LinearConstraint.p_linear_constraint -> unit
	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Function to negate an inequality (to be defined in subclasses) *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method virtual negate_inequality : LinearConstraint.p_linear_constraint -> LinearConstraint.p_linear_constraint


	(* Various strings *)
	method virtual str_optimum : string
	method virtual str_upper_lower : string

	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Variable initialization *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)

	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Compute the p-constraint of a state, projected onto the parameter to be optimized *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private project_constraint px_constraint =
		(* Project the constraint onto that parameter *)
		let projected_constraint = LinearConstraint.px_hide_allclocks_and_someparameters_and_collapse parameters_to_hide px_constraint in
		
		(* Return result *)
		projected_constraint


	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Compute the p-constraint of a state, projected onto the parameter to be optimized *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private is_goal_state state_location =
		(* Retrieve the correctness condition *)
		match model.correctness_condition with
		| Some (Unreachable unreachable_global_locations) ->
			(* Check whether the current location matches one of the unreachable global locations *)
			State.match_unreachable_global_locations unreachable_global_locations state_location
		| _ -> raise (InternalError("A correctness property must be defined to perform EF-optimization. This should have been checked before."))


	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Update the current optimum *)
	(*** WARNING: side effect on projected_constraint ***)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private update_optimum projected_constraint =
		(* Print some information *)
		if verbose_mode_greater Verbose_low then(
			self#print_algo_message Verbose_medium "Associated constraint:";
			self#print_algo_message Verbose_medium (LinearConstraint.string_of_p_linear_constraint model.variable_names projected_constraint);
			self#print_algo_message Verbose_medium ("Removing " ^ self#str_upper_lower ^ " bound…");
		);

		(* Relax the constraint, i.e., grow to infinity (for minimization) or to zero (for maximization) *)
		self#remove_bounds [parameter_index] parameters_to_hide projected_constraint;
			
		(* Print some information *)
		if verbose_mode_greater Verbose_standard then(
			self#print_algo_message Verbose_low ("Updating the " ^ self#str_optimum ^ ":");
			self#print_algo_message Verbose_standard (LinearConstraint.string_of_p_linear_constraint model.variable_names projected_constraint);
		);
		
		(* Update the min *)
		current_optimum <- Some projected_constraint;
		
		let new_negated_optimum = self#negate_inequality projected_constraint in
		
		(* Print some information *)
		if verbose_mode_greater Verbose_low then(
			self#print_algo_message_newline Verbose_low ("New negated optimum: " ^ (LinearConstraint.string_of_p_linear_constraint model.variable_names new_negated_optimum));
		);
		
		(* Update the negated optimum too *)
		negated_optimum <- Some new_negated_optimum
	
	
	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Actions to perform when trying to minimize/maximize a parameter. Returns true if the same should be kept, false if discarded. *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private process_state state = 
		(* Retrieve the constraint *)
		let state_location, px_constraint = state in
		
		(* Check if an optimum constraint was defined *)
		match current_optimum with
		| None ->
			(* If goal state, update the constraint *)
			let is_goal_state = self#is_goal_state state_location in
			if is_goal_state then(
				(* Compute the projection *)
				let projected_constraint = self#project_constraint px_constraint in
				
				self#print_algo_message Verbose_standard ("Found a first " ^ self#str_optimum);
				
				self#update_optimum projected_constraint;
			);

			(* Keep the state only if not a goal state *)
			(*** NOTE: here, we cannot use the optimum to update the state ***)
			not is_goal_state

		| Some current_optimum_constraint ->
			(*** NOTE: this is an expensive test, as ALL states will be projected to the goal parameters and compared to the current optimum ***)
			let projected_constraint = self#project_constraint px_constraint in

			(* Test if the current optimum is already larger *)
			if LinearConstraint.p_is_leq projected_constraint current_optimum_constraint then(
				(* Statistics *)
				counter_discarded_state#increment;
				(* Discard state, i.e., do not keep it *)
				false
			(* Otherwise: keep it *)
			)else(
				(* If goal state, update the constraint *)
				if self#is_goal_state state_location then(
				
					(* Print some information *)
					if verbose_mode_greater Verbose_medium then(
						self#print_algo_message_newline Verbose_medium ("Current " ^ self#str_optimum ^ ": " ^ (LinearConstraint.string_of_p_linear_constraint model.variable_names current_optimum_constraint));
						self#print_algo_message_newline Verbose_medium ("New state projected constraint: " ^ (LinearConstraint.string_of_p_linear_constraint model.variable_names projected_constraint));
					);
				
					self#print_algo_message Verbose_standard ("Found a better " ^ self#str_optimum);
				
					self#update_optimum projected_constraint;

					(* Hack: discard the state! Since no better successor can be found *)
					false
				)else(
					(* Keep the state, but add the negation of the optimum to squeeze the state space! (no need to explore the part with parameters smaller/larger than the optimum) *)
					let negated_optimum = match negated_optimum with
						| Some negated_optimum -> negated_optimum
						| None -> raise (InternalError("A negated optimum should be defined at that point"))
					in
					
					(* Print some information *)
					if verbose_mode_greater Verbose_high then(
						self#print_algo_message_newline Verbose_high ("Intersecting state with: " ^ (LinearConstraint.string_of_p_linear_constraint model.variable_names negated_optimum));
					);
					
					(* Intersect with side-effects *)
					LinearConstraint.px_intersection_assign_p px_constraint [negated_optimum];
					(* Keep the state *)
					(*** NOTE: what if it becomes unsatisfiable? ***)
					true
				)
			)

	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Add a new state to the state_space (if indeed needed) *)
	(* Side-effects: modify new_states_indexes *)
	(*** TODO: move new_states_indexes to a variable of the class ***)
	(* Return true if the state is not discarded by the algorithm, i.e., if it is either added OR was already present before *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method add_a_new_state source_state_index new_states_indexes action_index location (current_constraint : LinearConstraint.px_linear_constraint) =
		(* Print some information *)
		if verbose_mode_greater Verbose_medium then(
			self#print_algo_message Verbose_medium "Entering add_a_new_state…";
		);
		
		(* Build the state *)
		let new_state = location, current_constraint in
		
		(* If we have to optimize a parameter, do that now *)
		let keep_processing = self#process_state new_state in

		(* Only process if we have to *)
		if keep_processing then(
			(* Try to add the new state to the state space *)
			let addition_result = StateSpace.add_state state_space (self#state_comparison_operator_of_options) new_state in
			
			begin
			match addition_result with
			(* If the state was present: do nothing *)
			| StateSpace.State_already_present _ -> ()
			(* If this is really a new state, or a state larger than a former state *)
			| StateSpace.New_state new_state_index | StateSpace.State_replacing new_state_index ->

				(* First check whether this is a bad tile according to the property and the nature of the state *)
				self#update_statespace_nature new_state;
				
				(* Will the state be added to the list of new states (the successors of which will be computed)? *)

				(* Add the state_index to the list of new states (used to compute their successors at the next iteration) *)
				if true then
					new_states_indexes := new_state_index :: !new_states_indexes;
				
			end (* end if new state *)
			;
			
			(*** TODO: move the rest to a higher level function? (post_from_one_state?) ***)
			
			(* Add the transition to the state space *)
			self#add_transition_to_state_space (source_state_index, action_index, (*** HACK ***) match addition_result with | StateSpace.State_already_present new_state_index | StateSpace.New_state new_state_index | StateSpace.State_replacing new_state_index -> new_state_index) addition_result;
		
			(* The state is kept in any case *)
			true
		)else(
			(* If state discarded after minimization: do not keep it *)
			false
		)
	

	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Actions to perform with the initial state; returns true unless the initial state cannot be kept (in which case the algorithm will stop immediately) *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method process_initial_state initial_state = self#process_state initial_state

	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Actions to perform when meeting a state with no successors: nothing to do for this algorithm *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method process_deadlock_state state_index = ()
	
	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Actions to perform at the end of the computation of the *successors* of post^n (i.e., when this method is called, the successors were just computed). Nothing to do for this algorithm. *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method process_post_n (post_n : State.state_index list) = ()

	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Check whether the algorithm should terminate at the end of some post, independently of the number of states to be processed (e.g., if the constraint is already true or false) *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(*** TODO: could be stopped when the bad constraints are equal to the initial p-constraint ***)
	method check_termination_at_post_n = false

	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Method packaging the result output by the algorithm *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method compute_result =
		(* Print some information *)
		self#print_algo_message_newline Verbose_standard (
			"Algorithm completed " ^ (after_seconds ()) ^ "."
		);
		
		
		(* Get the constraint *)
		let result = match current_optimum with
			| None -> LinearConstraint.false_p_nnconvex_constraint()
			| Some current_optimum -> LinearConstraint.p_nnconvex_constraint_of_p_linear_constraint current_optimum
		in
		
		(* Get the termination status *)
		 let termination_status = match termination_status with
			| None -> raise (InternalError "Termination status not set in EFopt.compute_result")
			| Some status -> status
		in

		(* Constraint is exact if termination is normal, possibly under-approximated otherwise *)
		let soundness = if termination_status = Regular_termination then Constraint_exact else Constraint_maybe_under in

		(* Return the result *)
		Single_synthesis_result
		{
			(* Non-necessarily convex constraint guaranteeing the non-reachability of the bad location *)
			result				= Good_constraint (result, soundness);
			
			(* Explored state space *)
			state_space			= state_space;
			
			(* Total computation time of the algorithm *)
			computation_time	= time_from start_time;
			
			(* Termination *)
			termination			= termination_status;
		}


	
(************************************************************)
(************************************************************)
end;;
(************************************************************)
(************************************************************)
