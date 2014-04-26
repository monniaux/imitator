(*****************************************************************
 *
 *                     IMITATOR II
 * 
 * Laboratoire Specification et Verification (ENS Cachan & CNRS, France)
 * Author:        Etienne Andre
 * Created:       2010/03/04
 * Last modified: 2014/04/26
 *
 ****************************************************************)

(**************************************************)
(* Type definition *)
(**************************************************)

open Gmp.Q.Infixes

(*type t =          *)
(*  | Mpq of Gmp.Q.t*)
type t = Gmp.Q.t

exception Unknown_numconst of string


(**************************************************)
(* Functions *)
(**************************************************)

let get_mpq a = a



(**************************************************)
(** {2 Arithmetic Functions} *)
(**************************************************)

(*let arithmetic_gen op a b =
	let a = get_mpq a in
	let b = get_mpq b in
	let result = Gmp.Q.create () in
	op result a b;
	result*)

let add = ( +/ ) 
(*	arithmetic_gen Gmp.Q.add*)

let sub = ( -/ ) 
(*	arithmetic_gen Gmp.Q.sub*)

let mul = ( */ ) 
(*	arithmetic_gen Gmp.Q.mul*)

let div = ( // ) 
(*	arithmetic_gen Gmp.Q.div*)

let neg a = Gmp.Q.neg a	
(*	let a = get_mpq a in           *)
(*	let result = Gmp.Q.create () in*)
(*	Gmp.Q.neg result a;            *)
(*	Mpq result                     *)

let abs a =
	if Gmp.Q.cmp (get_mpq a) (Gmp.Q.zero) >= 0 then a
	else neg a


(**************************************************)
(** {2 User Conversions} *)
(**************************************************)

let get_num = Gmp.Q.get_num

let get_den = Gmp.Q.get_den 

let numconst_of_int i = (Gmp.Q.from_int i)

let numconst_of_frac i j = (Gmp.Q.from_ints i j)

let numconst_of_zfrac i j = (Gmp.Q.from_zs i j)


(*** WARNING !!!!! 
	It seems that many functions were NOT tester for negative numbers !!!!!
***)


(*** NOTE: Cannot use string_of_int (can overflow) ; behavior unspecified if no integer string ****)
let numconst_of_int_string s =
	Gmp.Q.from_z (Gmp.Z.from_string s)


let numconst_of_float f = (* Mpq (Mpq.of_float i) DOES NOT WORK WELL *)
	(*** WARNING: numconst_of_float 0.4 gives 400000000001/1000000000000 due to the floating point representation!! ***)
	(* Split the float in integer and fractional part *)
	let (fractional, integer) = modf f in
	let integer = numconst_of_int (int_of_float integer) in
	(* Case of an integer *)
	if fractional = 0.0 then integer
	else(
		let fractional = string_of_float fractional in
		(* Remove the "0." in front of the fractional part *)
		let fractional = String.sub fractional 2 (String.length fractional -2) in
		(* Find the denominator *)
		let denominator = numconst_of_int_string ("1" ^ (String.make (String.length fractional) '0')) in
		let fractional = numconst_of_int_string fractional in
		(* Create the fraction *)
		 (integer */ denominator +/ fractional) // denominator
	)


let numconst_of_positive_string str =
	(* Case int *)
	if Str.string_match (Str.regexp "^[0-9]+$") str 0 then
		numconst_of_int_string str
	(* Case fraction *)
	else if Str.string_match (Str.regexp "^[0-9]+/[0-9]+$") str 0 then
		let parts = Str.split (Str.regexp_string "/") str in
		let denominator =  numconst_of_int_string (List.nth parts 0) in
		let fractional = numconst_of_int_string(List.nth parts 1) in
		denominator // fractional
	(* Case float *)
	else if Str.string_match (Str.regexp "^[0-9]+.[0-9]+$") str 0 then numconst_of_float (float_of_string str)
	(* Otherwise *)
	else raise (Unknown_numconst ("Impossible to cast the string '" ^ str ^ "' to a NumConst in function numconst_of_string. Unknown type."))
	(* 	Gmp.Q.from_z (Gmp.Z.from_string str) *)


let numconst_of_string str =
	let s = "^-\\(.+\\)$" in
	let r = Str.regexp s in
	
	let matched = try
		(*** NOTE: try could be safely removed ***)
		Str.string_match r str 0
		with Failure f -> raise (Failure("Failure while unserializing numconst '" ^ str ^ "'. Error: " ^ f));
	in
	
	(* Case negative *)
	if matched then(
		(* Retrieve the rest *)
		let rest = try
			(*** NOTE: try could be safely removed ***)
			Str.matched_group 1 str
			with Failure f -> raise (Failure("Failure while unserializing numconst '" ^ str ^ "' and accessign group 1. Error: " ^ f));
		in
		neg (numconst_of_positive_string rest)
	)
	(* Case positive *)
	else numconst_of_positive_string str

	
let numconst_of_mpq m = m

let numconst_of_mpz z = Gmp.Q.from_z z

let mpq_of_numconst = get_mpq

let string_of_numconst a =
	(* Avoid 0/1 *)
	if a =/ (Gmp.Q.zero) then "0" else(
		(* Avoid 1/1 *)
		let den = get_den a in 
		if den = (Gmp.Z.from_int 1) then
			Gmp.Z.to_string (get_num a)
		else
			(* Nice predefined function *)
			Gmp.Q.to_string (get_mpq a)
	)

(**************************************************)
(** {2 Constants} *)
(**************************************************)

let zero = Gmp.Q.zero
(*let zero = numconst_of_int 0*)
let one = numconst_of_int 1
let minus_one = numconst_of_int (-1)


(**************************************************)
(** {2 Comparison Functions} *)
(**************************************************)
let equal a b =
	Gmp.Q.equal (get_mpq a) (get_mpq b)

let neq a b =
	not (equal a b)

let l  = ( </ )
let le = ( <=/ )
let ge = ( >=/ )
let g  = ( >/ )


(**************************************************)
(** {2 Test Functions} *)
(**************************************************)
let is_integer n =
	(* Zero is an integer! *)
	(*** WARNING: added one as well, because the cmp test below did not work for one *)
	equal n zero || equal n one ||
	(* Then check denominator = 1 *)
	(
		(*print_string (Gmp.Z.to_string (get_num n));
		print_string "/";
		print_string (Gmp.Z.to_string (get_num n));
		print_string "\n";
		print_string ("  Check num = den: " ^ (string_of_bool ((get_num n) = (get_den n))));
		print_string "\n";
		print_string ("  Check cmp (num , den): " ^ (string_of_int (Gmp.Z.cmp (get_num n) (get_den n))));
		print_string "\n";*)
		(*** WARNING: should not use directly (get_num n) = (get_den n), because got strange results ***)
(* 		(Gmp.Z.cmp (get_num n) (get_den n)) > 0 *)
		(Gmp.Z.cmp (get_den n) (Gmp.Z.from_int 1)) = 0
	)


(**************************************************)
(** {2 More Elaborated Arithmetic Functions} *)
(**************************************************)

(** WARNING: not really tested !!! *)
let find_multiple_gen tcdiv_q base_number step number =
	(* 1) Compute m = number - base_number *)
	let m = sub number base_number in
	
	(* 2) Compute d = m / step (hence, m = n * step) *)
	let d = div m step in
	
	(* 3) Find the closest integer k below d *)
		(* 3a) Extract numerator and denominator (integers) *)
	let d_num = get_num d in
	let d_den = get_den d in
		(* 3b) Use integer division (rounded above/below) *)
	let k = tcdiv_q d_num d_den in
	
	(* 4) Return n = k * step + base_number *)
	add
		(mul 
			(Gmp.Q.from_z k)
			step
		)
		base_number

(** WARNING: not really tested !!! *)
(** Find the closest multiple of step from base_number below (or equal to) number *)
(* That is: find the largest n s.t. n = k * step + base_number, with k integer, and n <= number *)
let find_multiple_below =
	find_multiple_gen Gmp.Z.tdiv_q
		

(** WARNING: not really tested !!! *)
(** Find the closest multiple of step from base_number above (or equal to) number *)
(* That is: find the smallest n s.t. n = k * step + base_number, with k integer, and n >= number *)
let find_multiple_above =
	find_multiple_gen Gmp.Z.cdiv_q
		

let state = 
	(*** HACK: should maybe not be there ***)
	Random.self_init();
	(* Initialize random *)
	(*** EXPLANATION: total HACK here, tried greater than 128 (e.g. 255) entails 'exception Invalid_argument("Gmp.Random.randinit")' ***)
	let random_value = Random.int (*max_int*)128 in
	(*** HACK: The 4 lines below are written to empirically try a good value ! ***)
(*	for i = 0 to 100000 do
		print_string ".";
		let _ = Gmp.RNG.randinit (Gmp.RNG.GMP_RAND_ALG_LC random_value) in ()
	done;*)
	(*** WARNING: not sure to understand what I did there (EA, 26/4/2014) ***)
	Gmp.RNG.randinit (Gmp.RNG.GMP_RAND_ALG_LC random_value)



(** Generates a random integer NumConst in the interval [min , max] *)
let random_integer min max =
	(* Preliminary check *)
	if not (is_integer min && is_integer max) then
		raise (Failure("Random integers must be in between integer bounds."));
	
	(* Compute the number of integers *)
	let nb = max -/ min +/ one in

	(* Convert to Z *)
	let nb = get_num nb in
	
	(* Compute random *)
	let random_number = Gmp.Z.urandomm state nb in
(* 	let plouf = Gmp.Q.mpz_urandomm in *)
	(* Convert back to Gmp.Q *)
	let random_number = Gmp.Q.from_z random_number in
	
	(* Go back to the specified interval *)
	random_number +/ min



(**************************************************)
(* Tests *)
(**************************************************)

(*;;
let a = numconst_of_float 0.4 in
let b = numconst_of_frac 1 3 in
let c = numconst_of_int 2 in
let d = numconst_of_float 2.00 in
let e = numconst_of_frac 306 153 in
let n1 = numconst_of_frac 153 153 in
let n2 = numconst_of_frac 7 3 in
(*** BUG HERE due to numconst_of_string (valid 26/04/2014) ***)
let n3 = numconst_of_string "0.4" in
let n4 = numconst_of_frac 2040 10 in

let numbers = [a ; b ; c ; d ; e ; n1 ; n2 ; n3 ; n4] in
List.iter (fun number -> 
	print_string ("\n n = " ^ (string_of_numconst number) ^ " ; Is it an integer ? " ^ (string_of_bool (is_integer number)));
) numbers ;
(*print_string ("\n b = " ^ (string_of_numconst b));
print_string ("\n c = " ^ (string_of_numconst c));
print_string ("\n d = " ^ (string_of_numconst d));
print_string ("\n e = " ^ (string_of_numconst e));
print_string ("\n n1 = " ^ (string_of_numconst n1));
print_string ("\n n2 = " ^ (string_of_numconst n2));
print_string ("\n n3 = " ^ (string_of_numconst n3));

print_string ("\n Is b an integer ? " ^ (string_of_bool (is_integer b)));
print_string ("\n Is c an integer ? " ^ (string_of_bool (is_integer c)));
print_string ("\n Is d an integer ? " ^ (string_of_bool (is_integer d)));
print_string ("\n Is e an integer ? " ^ (string_of_bool (is_integer e)));
print_string ("\n Is n1 an integer ? " ^ (string_of_bool (is_integer n1)));
print_string ("\n Is n2 an integer ? " ^ (string_of_bool (is_integer n2)));
print_string ("\n Is n3 an integer ? " ^ (string_of_bool (is_integer n3)));*)


print_string ("\n a + b = " ^ (string_of_numconst (add a b)));
print_string ("\n a + c = " ^ (string_of_numconst (add a c)));
print_string ("\n b + c = " ^ (string_of_numconst (add b c)));

print_string ("\n a - b = " ^ (string_of_numconst (sub a b)));
print_string ("\n a - c = " ^ (string_of_numconst (sub a c)));
print_string ("\n b - c = " ^ (string_of_numconst (sub b c)));

print_string ("\n a * b = " ^ (string_of_numconst (mul a b)));
print_string ("\n a * c = " ^ (string_of_numconst (mul a c)));
print_string ("\n b * c = " ^ (string_of_numconst (mul b c)));

print_string ("\n a / b = " ^ (string_of_numconst (div a b)));
print_string ("\n a / c = " ^ (string_of_numconst (div a c)));
print_string ("\n b / c = " ^ (string_of_numconst (div b c)));

print_string ("\n -a = " ^ (string_of_numconst (neg a)));
print_string ("\n -b = " ^ (string_of_numconst (neg b)));
print_string ("\n -c = " ^ (string_of_numconst (neg c)));

print_string ("\n |a| = " ^ (string_of_numconst (abs a)));
print_string ("\n |-a| = " ^ (string_of_numconst (abs (neg a))));

print_string ("\n a = b ? " ^ (string_of_bool (equal a b)));
print_string ("\n a <> b ? " ^ (string_of_bool (neq a b)));
print_string ("\n a < b ? " ^ (string_of_bool (l a b)));
print_string ("\n a <= b ? " ^ (string_of_bool (le a b)));
print_string ("\n a >= b ? " ^ (string_of_bool (ge a b)));
print_string ("\n a > b ? " ^ (string_of_bool (g a b)));

print_string ("\n d = e ? " ^ (string_of_bool (equal d e)));
print_string ("\n d <> e ? " ^ (string_of_bool (neq d e)));
print_string ("\n d < e ? " ^ (string_of_bool (l d e)));
print_string ("\n d <= e ? " ^ (string_of_bool (le d e)));
print_string ("\n d >= e ? " ^ (string_of_bool (ge d e)));
print_string ("\n d > e ? " ^ (string_of_bool (g d e)));


let occurrences = Array.make 150 0 in
print_string ("\n A bit of randomization: ");
for i = 0 to 100000 do
	let random = random_integer (numconst_of_int 4) (numconst_of_int 149) in
(* 	print_string ((string_of_numconst random) ^ " - "); *)
	(* Convert to an integer (only works because small enough) *)
	let inti = Gmp.Z.to_int (get_num random) in
	(* Increment table *)
	occurrences.(inti) <- occurrences.(inti) + 1;
done;
for i = 0 to 149 do
	print_string ("\n " ^ (string_of_int i)  ^" -> " ^ (string_of_int occurrences.(i)) ^ " occurrences");
done;


print_newline();


exit 0*)
