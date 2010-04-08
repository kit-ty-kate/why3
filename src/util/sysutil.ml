(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-                                                   *)
(*    Francois Bobot                                                      *)
(*    Jean-Christophe Filliatre                                           *)
(*    Johannes Kanig                                                      *)
(*    Andrei Paskevich                                                    *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

let channel_contents_fmt cin fmt =
  let buff = String.make 1024 ' ' in
  let n = ref 0 in
  while n := input cin buff 0 1024; !n <> 0 do
    Format.pp_print_string fmt
      (if !n = 1024 then
         buff
       else
         String.sub buff 0 !n)
  done


let channel_contents_buf cin =
  let buf = Buffer.create 1024
  and buff = String.make 1024 ' ' in
  let n = ref 0 in
  while n := input cin buff 0 1024; !n <> 0 do 
    Buffer.add_substring buf buff 0 !n
  done;
  buf

let channel_contents cin = Buffer.contents (channel_contents_buf cin)

let file_contents_fmt f fmt =
  try
    let cin = open_in f in
    channel_contents_fmt cin fmt;
    close_in cin
  with _ -> 
    invalid_arg (Printf.sprintf "(cannot open %s)" f)

let file_contents_buf f =
  try 
    let cin = open_in f in
    let buf = channel_contents_buf cin in
    close_in cin;
    buf
  with _ -> 
    invalid_arg (Printf.sprintf "(cannot open %s)" f)


let file_contents f = Buffer.contents (file_contents_buf f)

let open_temp_file ?(debug=false) filesuffix usefile =
  let file,cout = Filename.open_temp_file "why" filesuffix in
  try
    let res = usefile file cout in
    if not debug then Sys.remove file;
    close_out cout;
    res
  with
    | e ->    
        if not debug then Sys.remove file;
        close_out cout;
        raise e


type 'a result =
  | Result of 'a
  | Exception of exn

open Unix

exception Bad_execution of process_status

let call_asynchronous (f : unit -> 'a) = 
  let cin,cout = pipe () in
  let cin = in_channel_of_descr cin in
  let cout = out_channel_of_descr cout in
  match fork () with
    | 0 -> 
        let result = 
          try
            Result (f ())
          with exn -> Exception exn in
        Marshal.to_channel cout (result : 'a result) [];
        close_out cout;
        exit 0
    | pid ->
        let f () =
          let result = (Marshal.from_channel cin: 'a result) in
          close_in cin;
          let _, ps = waitpid [] pid in
          match ps with
            | WEXITED 0 ->
                begin match result with
                  | Result res -> res
                  | Exception exn -> raise exn
                end
            | _ -> raise (Bad_execution ps) in
        f
