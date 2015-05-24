
%% Utilities module for anything that might be generally useful for Yesbot


:- module(utilities,
     [ run_det/1
      ,run_det/3
      ,init_timer/1
      ,add_new_extensions/1
      ,load_new_extensions/1 ]).

:- use_module(config).


%--------------------------------------------------------------------------------%
% Concurrency
%--------------------------------------------------------------------------------%


%% run_det(+Msg:compound, :Extension, -E:compound) is det.
%
% Concurrently call a list of extension predicates on the current message.
% The extension predicates can possibly be nondet, but will still execute
% concurrently without undue interruption.

run_det(Msg, Extension, E) :-
  E = ignore(((call(Extension:Extension, Msg), fail))).


%% run_det(:Goal) is det.
%
% Find all the solutions to an extensionized goal in order to precipitate the
% result as an unevaluated deterministic result. Used here for deterministically
% evaluating a possibly nondet or semidet prediciate concurrently.

run_det(Goal) :-
  ignore((Goal, fail)).


%--------------------------------------------------------------------------------%
% Connectivity/Timing
%--------------------------------------------------------------------------------%


%% init_timer(-Id:integer) is semidet.
%
% Initialize a message queue that stores one thread which acts as a timer that
% checks connectivity of the bot when established interval has passed.

init_timer(Id) :-
  message_queue_create(Id, [alias(tq)]),
  thread_create(check_pings(Id), _, [alias(ping_checker)]).


%% check_pings(+Id:integer) is failure.
% If Limit seconds has passed, then signal the connection threat to abort. If a
% ping has been detected and the corresponding message is sent before the time
% limit expires, then the goal will succeed and so will the rest of the predicate.
% The thread will then return to its queue, reset its timer, and wait for another
% ping signal.

check_pings(Id) :-
  time_limit(Limit),
  repeat,
    (  thread_get_message(Id, Goal, [timeout(Limit)])
    -> Goal
    ;  thread_signal(ct, throw(abort))
    ),
    fail.


%--------------------------------------------------------------------------------%
% Hot loading
%--------------------------------------------------------------------------------%


%% add_new_extensions(+New:list(atom)) is semidet.
%
% Adds new extensions on top of whatever extensions are currently loaded in the
% the bot at the moment. These settings will not persist on restart; persisting
% these settings must be done by preceding a save_settings/0 call with this call.

add_new_extensions(New) :-
  setting(config:extensions, Es),
  append(New, Es, Extensions),
  load_new_extensions(Extensions).


%% load_new_extensions(+Es:list(atom)) is semidet.
%
% Load a new set of extensions and initalize them into the current bot session.
% This will not save these settings on restart. To make them persistent, this
% predicate call must precede a call to save_settings/0.

load_new_extensions(Es) :-
  set_setting(config:extensions, Es),
  retractall(core:extensions(_,_)),
  init_extensions.


