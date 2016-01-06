module M = [%csv "http://ichart.finance.yahoo.com/table.csv?s=MSFT"]
module N = [%csv "./test.csv"]

let _ =
  print_endline "Date | Open | High | Low | Close | Volume | Adj Close";
  ignore @@ List.map
    (function
      [d; o; h; l; c; v; a] ->
        Printf.printf "%s | %s | %s | %s | %s | %s | %s\n" d o h l c v a) N.embed;
  print_endline "\nShowing items 0...2";
  print_endline "Date | Open | High | Low | Close | Volume | Adj Close";
  ignore @@ List.map
    N.(function
      {date = d; open_ = o; high = h; low = l; close = c; volume = v; adjClose = a} ->
        Printf.printf "%s | %f | %f | %f | %f | %d | %f\n" d o h l c v a)
    (N.get_sample ~amount:3 N.embed);
  print_endline "\nShowing items 1...3";
  ignore @@ List.map
    N.(function
      {date = d; open_ = o; high = h; low = l; close = c; volume = v; adjClose = a} ->
        Printf.printf "%s | %f | %f | %f | %f | %d | %f\n" d o h l c v a)
    (N.range ~from:1 ~until:3 (N.rows N.embed))

