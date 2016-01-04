open Ast_mapper
open Ast_helper
open Asttypes
open Parsetree
open Longident

open Lwt
open Cohttp
open Cohttp_lwt_unix

let get_csv url =
  let is_web =
    let r = Re_pcre.regexp "^https?://.*" in
    Re.execp r url in
  if is_web then
    Client.get (Uri.of_string url) >>= fun (resp, body) ->
    body |> Cohttp_lwt_body.to_string >|= fun body -> body
  else
    let fd = Lwt_unix.run @@ Lwt_io.open_file Input url in
    Lwt_io.read fd

let infer s =
  begin try (float_of_string s; "float") with
    | _ ->
      begin try (int_of_string s; "int") with
        | _ -> "string"
      end
  end

let record_of_list loc list example =
  let fields = List.map2 (fun i e ->
                           Type.field ~loc {txt = i; loc = loc}
                             (Typ.constr {txt = Lident (infer e); loc = loc} []))
      list example in
  Str.type_ ~loc [Type.mk {txt = "t"; loc = loc} ~kind:(Ptype_record fields)]

let struct_of_url ?(sep=',') url loc =
  get_csv url >>= fun text ->
  let data = Csv.of_string ~separator:sep text |> Csv.input_all in
  let format = List.hd data
  and rows = List.tl data in
  let embed = [%stri let embed = [%e Exp.constant (Const_string (text, None))]]
  and type_ = record_of_list loc format (List.hd rows) in
  return @@ Mod.structure ~loc [embed; type_]

let csv_mapper argv =
  {default_mapper with
   module_expr = begin fun mapper mod_expr ->
     match mod_expr with
     | { pmod_attributes; pmod_loc; pmod_desc = Pmod_extension ({txt = "csv"; loc}, pstr) } ->
       begin match pstr with
         | PStr [{ pstr_desc =
                     Pstr_eval ({ pexp_loc = loc;
                                  pexp_desc = Pexp_constant (Const_string (sym, None))}, _)}] ->
           Lwt_unix.run @@ struct_of_url sym loc
         | PStr [{ pstr_desc =
                     Pstr_eval ({ pexp_loc = loc;
                                  pexp_desc = Pexp_tuple
                                      [{ pexp_desc = Pexp_constant (Const_string (sym, None)); _ };
                                       { pexp_desc = Pexp_constant (Const_char sep); _ }]}, _)}] ->
           Lwt_unix.run @@ struct_of_url ~sep sym loc
         | _ ->
           raise (Location.Error
                    (Location.error ~loc "[%csv ...] accepts a string, e.g. [%csv \"https://google.com\"]"))
       end
     | x -> default_mapper.module_expr mapper x
   end
  }

let _ = register "csv_provider" csv_mapper