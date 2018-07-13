module Test

module B = LowStar.Buffer
module U32 = FStar.UInt32

module T = LowStar.ToFStarBuffer

inline_for_extraction noextract
let (!!) = T.new_to_old_st

open FStar.HyperStack.ST
open FStar.Bytes
open EverCrypt.Helpers

module AC = EverCrypt.AutoConfig
module H = EverCrypt.Hash

open Test.Vectors
open FStar.Integers
open LowStar.BufferOps

#set-options "--admit_smt_queries true"

/// Hash function (any of them)

val test_one_hash: v:hash_vector -> St unit
let test_one_hash v =
  push_frame();

  let output_len: UInt32.t =
    match v.hash_alg with
    | H.SHA256 -> 32ul
    | H.SHA384 -> 48ul
    //| H.SHA512 -> 64ul
  in
  let output = B.alloca 0uy output_len in

  let input_len = C.String.strlen v.input in
  let total_input_len = input_len * v.repeat in
  let input = B.alloca 0uy total_input_len in
  C.Loops.for 0ul v.repeat (fun _ _ -> True) (fun i ->
    C.String.memcpy (B.offset input (input_len * i)) v.input input_len
  );

  (* Allocate memory for state *)
  let ctx = EverCrypt.Hash.(create v.hash_alg) in

  (* Compute the number of blocks to process *)
  let size_block: UInt32.t =
    match v.hash_alg with
    | H.SHA256 -> 64ul
    | H.SHA384 -> 128ul
    //| SHA512 -> 128ul
  in
  let n = U32.div total_input_len size_block in
  let r = U32.rem total_input_len size_block in

  (* Get all full blocks and the last block *)
  let input_blocks = B.sub input 0ul (n * size_block) in
  let input_last   = B.sub input (n * size_block) r in

  (* Call the hash function incrementally *)
  EverCrypt.Hash.init ctx;
  EverCrypt.Hash.update_multi ctx input_blocks n;
  EverCrypt.Hash.update_last ctx input_last r;
  EverCrypt.Hash.finish ctx output;

  // Non-incrementally:
  // EverCrypt.sha256_hash output input len

  let str: C.String.t =
    match v.hash_alg with
    | H.SHA256 -> !$"of SHA256"
    | H.SHA384 -> !$"of SHA384"
  in

  (* Display the result *)
  TestLib.compare_and_print str !!v.output !!output output_len;

  pop_frame()

/// ChaCha20-Poly1305

val test_chacha20_poly1305: v:aead_vector{v.cipher == CHACHA20_POLY1305} -> St unit
let test_chacha20_poly1305 v =
  push_frame();

  let plaintext'    = B.alloca 0uy v.plaintext_len in
  let ciphertext'   = B.alloca 0uy v.plaintext_len in
  let tag'          = B.alloca 0uy 16ul in

  let s0 = TestLib.cpucycles () in
  EverCrypt.chacha20_poly1305_encrypt v.key v.iv v.aad v.aad_len v.plaintext v.plaintext_len ciphertext' tag';
  let s1 = TestLib.cpucycles () in
  TestLib.print_cycles_per_round s0 s1 1ul;
  TestLib.compare_and_print !$"of Chacha20-Poly1305 cipher" !!v.ciphertext !!ciphertext' v.plaintext_len;
  TestLib.compare_and_print !$"of Chacha20-Poly1305 tag" !!v.tag !!tag' 16ul;

  match EverCrypt.chacha20_poly1305_decrypt v.key v.iv v.aad v.aad_len plaintext' v.plaintext_len v.ciphertext v.tag with
  | 1ul ->
    TestLib.compare_and_print !$"of Chacha20-Poly1305 plaintext" !!v.plaintext !!plaintext' v.plaintext_len
  | _ ->
    C.String.print !$"Decryption failed!\n"; C.portable_exit 1l;

  pop_frame()

val test_aes128_gcm: v:aead_vector{v.cipher == AES_128_GCM} -> St unit
let test_aes128_gcm v =
  push_frame();

  let plaintext'    = B.alloca 0uy v.plaintext_len in
  let ciphertext'   = B.alloca 0uy v.plaintext_len in
  let tag'          = B.alloca 0uy 16ul in

  let s0 = TestLib.cpucycles () in
  EverCrypt.aes128_gcm_encrypt v.key v.iv v.aad v.aad_len v.plaintext v.plaintext_len ciphertext' tag';
  let s1 = TestLib.cpucycles () in
  TestLib.print_cycles_per_round s0 s1 1ul;
  TestLib.compare_and_print !$"of AES-GCM 128 cipher" !!v.ciphertext !!ciphertext' v.plaintext_len;
  TestLib.compare_and_print !$"of AES-GCM 128 tag" !!v.tag !!tag' 16ul;

  match EverCrypt.aes128_gcm_decrypt v.key v.iv v.aad v.aad_len plaintext' v.plaintext_len v.ciphertext v.tag with
  | 1ul ->
    TestLib.compare_and_print !$"of AES-GCM 128 plaintext" !!v.plaintext !!plaintext' v.plaintext_len
  | _ ->
    C.String.print !$"Decryption failed!\n"; C.portable_exit 1l;

  pop_frame()

val test_aes256_gcm: v:aead_vector{v.cipher == AES_256_GCM} -> St unit
let test_aes256_gcm v =
  push_frame();

  let plaintext'    = B.alloca 0uy v.plaintext_len in
  let ciphertext'   = B.alloca 0uy v.plaintext_len in
  let tag'          = B.alloca 0uy 16ul in

  EverCrypt.aes256_gcm_encrypt v.key v.iv v.aad v.aad_len v.plaintext v.plaintext_len ciphertext' tag';
  TestLib.compare_and_print !$"of AES-GCM 256 cipher" !!v.ciphertext !!ciphertext' v.plaintext_len;
  TestLib.compare_and_print !$"of AES-GCM 256 tag" !!v.tag !!tag' 16ul;

  let s0 = TestLib.cpucycles () in
  EverCrypt.aes256_gcm_encrypt v.key v.iv v.aad v.aad_len v.plaintext v.plaintext_len ciphertext' tag';
  let s1 = TestLib.cpucycles () in

  TestLib.print_cycles_per_round s0 s1 1ul;
  TestLib.compare_and_print !$"of AES-GCM 256 cipher" !!v.ciphertext !!ciphertext' v.plaintext_len;
  TestLib.compare_and_print !$"of AES-GCM 256 tag" !!v.tag !!tag' 16ul;

  match EverCrypt.aes256_gcm_decrypt v.key v.iv v.aad v.aad_len plaintext' v.plaintext_len v.ciphertext v.tag with
  | 1ul ->
    TestLib.compare_and_print !$"of AES-GCM 256 plaintext" !!v.plaintext !!plaintext' v.plaintext_len
  | _ ->
    C.String.print !$"Decryption failed!\n"; C.portable_exit 1l;

  pop_frame()

// let test_aes_ecb (v: block_cipher_vector) : St unit =
  // push_frame();
  // let key = buffer_of_hex v.rkey in
  // let plain = buffer_of_hex v.plain in
  // let cipher = buffer_of_hex v.enc in
  // let cipher' = B.create 0uy 16ul in
  // let s0 = T.cpucycles () in
  // let () =
  //   match v.block with
  //   | AES128 ->
  //     let k = EverCrypt.aes128_create key in
  //     EverCrypt.aes128_compute k plain cipher';
  //     EverCrypt.aes128_free k
  //   | AES256 ->
  //     let k = EverCrypt.aes256_create key in
  //     EverCrypt.aes256_compute k plain cipher';
  //     EverCrypt.aes256_free k
  //   in
  // let s1 = T.cpucycles () in
  // T.print_cycles_per_round s0 s1 1ul;
  // T.compare_and_print !$"of AES128 block" cipher cipher' 16ul;
  // pop_frame()

/// Test drivers

(* val test_cipher: list block_cipher_vector -> St unit *)
(* let rec test_cipher v = *)
(*   match v with *)
(*   | [] -> () *)
(*   | v :: vs -> *)
(*     match v.block with *)
(*     | AES128 *)
(*     | AES256 -> *)
(*       let this = test_aes_ecb v in *)
(*       let rest = test_cipher vs in *)
(*       () *)
(*     | _ -> test_cipher vs *)

(* val test_chacha20: list chacha20_vector -> St unit *)
(* let rec test_chacha20 v = *)
(*   match v with *)
(*   | [] -> () *)
(*   | v :: vs -> *)
(*     let key = buffer_of_hex v.c20_key in *)
(*     let iv  = buffer_of_hex v.c20_iv in *)
(*     let plain = buffer_of_hex v.c20_plain in *)
(*     let len = Bytes.len (bytes_of_hex v.c20_plain) in *)
(*     let cipher = buffer_of_hex v.c20_cipher in *)
(*     let cipher' = B.create 0uy len in *)
(*     EverCrypt.chacha20 key iv v.c20_ctr plain len cipher'; *)
(*     TestLib.compare_and_print !$"of ChaCha20 message" cipher cipher' len; *)
(*     test_chacha20 vs *)

val test_aead: len:U32.t -> vs: B.buffer aead_vector {B.len vs = len }-> St unit
let rec test_aead len vs =
  if len = 0ul then
    ()
  else
    let v = vs.(0ul) in
    begin match v.cipher with
    | CHACHA20_POLY1305 ->
        test_chacha20_poly1305 v
    | AES_128_GCM ->
        test_aes128_gcm v
    | AES_256_GCM ->
        test_aes256_gcm v
    | _ ->
        ()
    end;
    test_aead (len - 1ul) (B.offset vs 1ul)

val test_hash: len:U32.t -> vs: B.buffer hash_vector {B.len vs = len }-> St unit
let rec test_hash len vs =
  if len > 0ul then
    let v = vs.(0ul) in
    test_one_hash v;
    test_hash (len - 1ul) (B.offset vs 1ul)

let main (): St C.exit_code =
  let open EverCrypt in
  let open C.String in
  push_frame ();

  print !$"===========Hacl===========";
  AC.(init (Prefer Hacl));
  test_hash hash_vectors_len hash_vectors;
  test_aead aead_vectors_len aead_vectors;
  Test.Hash.main ();
  Test.Bytes.main ();
  
  print !$"===========Vale===========";
  AC.(init (Prefer Vale));
  test_aead aead_vectors_len aead_vectors;
  test_hash hash_vectors_len hash_vectors;
  Test.Hash.main ();
  
  print !$"==========OpenSSL=========";
  AC.(init (Prefer OpenSSL));
  test_aead aead_vectors_len aead_vectors;

  print !$"==========BCrypt==========";
  AC.(init (Prefer BCrypt));
  test_aead aead_vectors_len aead_vectors;
  Test.Hash.main ();
  pop_frame ();
  C.EXIT_SUCCESS
