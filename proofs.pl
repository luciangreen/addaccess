% proofs.pl - properties of addaccess.
:- ensure_loaded('addaccess.pl').
:- ensure_loaded('spec.pl').
:- ensure_loaded('tests/inputs.pl').

sample(html(H, M, An)) :- between(1, 60, Id), input(Id, add_access, html(H, M, An)).

% Round trip: tokenising and serialising a normalised page changes nothing.
% Proof: serialize/2 is the left inverse of tokenize/2 on its own output.
proof(round_trip, forall(sample(html(H, _, _)), ( tokenize(H, T), serialize(T, A), tokenize(A, T2),
      serialize(T2, A2), A == A2 ))).

% Text content is never changed (only tags and attributes).
proof(text_preserved, forall(sample(I), ( I = html(H, _, _), add_access(I, result(O, _, _)),
      texts(H, A), texts(O, B), A == B ))).
texts(H, Ts) :- tokenize(H, Tok), findall(X, member(text(X), Tok), Ts).

% Idempotence: running again with the same answers adds nothing new.
proof(idempotent, forall(sample(html(H, M, An)), ( add_access(html(H, M, An), result(O, _, _)),
      add_access(html(O, M, An), result(O2, _, _)), O == O2 ))).

% Tags stay balanced: every renamed open tag has its close tag renamed too.
proof(balanced, forall(sample(I), ( add_access(I, result(O, _, _)), tokenize(O, T),
      forall(member(N, [nav, header, footer, main, aside, button]),
             ( aggregate_all(count, member(open(N, _, no), T), A),
               aggregate_all(count, member(close(N), T), B), A =:= B )) ))).

% Every question is answered by supplying ans(Question, V): then no question remains.
proof(answers_close_questions, forall(sample(html(H, M, _)), ( add_access(html(H, M, []), result(_, Qs, _)),
      findall(ans(Q, x), member(Q, Qs), An), add_access(html(H, M, An), result(_, [], _)) ))).

% Semantic mode never adds a role that duplicates a native element.
proof(no_redundant_roles, forall(sample(html(H, _, An)), ( add_access(html(H, semantic, An), result(O, _, _)),
      \+ sub_atom(O, _, _, _, 'role="navigation"'), \+ sub_atom(O, _, _, _, 'role="button"') ))).

% The mapping table row from the brief is present.
proof(mapping_table, mapping('Web (Native)', 'Semantic HTML (<nav>, <button>)', 'role="navigation", role="button"')).

% Refinement: implementation equals the DCG-based spec on samples.
proof(implementation_equals_spec, forall(sample(I), ( add_access(I, A), spec_add_access(I, B), A == B ))).
