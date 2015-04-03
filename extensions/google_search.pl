
:- module(google_search, [google_search/1]).

:- use_module(dispatch).
:- use_module(submodules/html).
:- use_module(submodules/web).
:- use_module(library(sgml)).
:- use_module(library(http/http_open)).
:- use_module(library(xpath)).
:- use_module(library(uri)).


% TBD: Add support for other google search features such as google conversion,
% currency, wiki, translate, calculator, etc.

chan("##prolog").
google_start(`http://www.google.com/search?q=`).
google_end(`&btnI=I\'m+Feeling+Lucky`).


google_search(Msg) :-
  thread_create(ignore(google_search_(Msg)), _Id, [detached(true)]).


google_search_(Msg) :-
  chan(Chan),
  Msg = msg(_Prefix, "PRIVMSG", [Chan], Text),
  append(`?google `, Q0, Text),
  atom_codes(Atom, Q0),
  google_start(Start),
  google_end(End),
  append(atom_codes $ uri_encoded(query_value) $ Atom, Diff, Query),
  append(Start, Query, L),
  Diff = End,
  string_codes(Link, L),
  setup_call_cleanup(
    http_open(Link, Stream,
      [ final_url(URL)
       ,request_header(referer='http://www.google.com')
       ,header('Content-Type', Type)
       ,cert_verify_hook(cert_verify)
       ,timeout(20) ]),
    (
       content_type_opts(Type, Opts)
    ->
       (
	  URL \= Link
       ->
	  load_html(Stream, Structure, Opts),
	  (
	     xpath_chk(Structure, //title(normalize_space), T0),
	     string_codes(T0, T1),
	     unescape_title(T1, T2),
	     maplist(change, T2, Title)
	  ->
	     send_msg(priv_msg, Title, Chan)
	  ;
	     true
	  ),
	  send_msg(priv_msg, URL, Chan)
       ;
	  send_msg(priv_msg, "Result not valid", Chan)
       )
    ;
       send_msg(priv_msg, URL, Chan)
    ),
    close(Stream)
  ).

