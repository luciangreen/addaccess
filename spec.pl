% spec.pl - independent oracle for addaccess: a DCG tokenizer, a per-tag
% attribute pipeline computed in a first pass, and close-tag renaming with an
% explicit stack in a second pass.

spec_for(add_access, spec_add_access).

spec_add_access(html(H, M, An), result(Out, Qs, Log)) :-
    atom_chars(H, Cs), phrase(s_tokens(Ts), Cs),
    s_pass1(Ts, M, An, 1, Ts1, QL),
    s_pass2(Ts1, [], Ts2),
    findall(Q, member(q(Q), QL), Q0), s_uniq(Q0, Qs),
    findall(L, member(l(L), QL), Log),
    findall(A, ( member(T, Ts2), s_out(T, A) ), As), atomic_list_concat(As, Out).

s_uniq([], []).
s_uniq([X|Xs], [X|Ys]) :- exclude(==(X), Xs, Zs), s_uniq(Zs, Ys).

% ---- DCG tokenizer ----------------------------------------------------------
s_tokens([T|Ts]) --> s_token(T), !, s_tokens(Ts).
s_tokens([]) --> [].

s_token(raw(A)) --> ['<', '!'], s_until_gt(B), { atom_chars(BA, B), atomic_list_concat(['<!', BA, '>'], A) }.
s_token(close(N)) --> ['<', '/'], s_name(NC), s_until_gt(_), { atom_chars(N0, NC), downcase_atom(N0, N) }.
s_token(open(N, As, SC)) --> ['<', C], { s_alpha(C) }, s_name(NC0), { atom_chars(N0, [C|NC0]), downcase_atom(N0, N) },
    s_attrs(As, SC).
s_token(text(A)) --> [C], { C \== '<' }, s_text(T), { atom_chars(A, [C|T]) }.
s_token(text('<')) --> ['<'].

s_text([C|T]) --> [C], { C \== '<' }, !, s_text(T).
s_text([]) --> [].

s_until_gt([]) --> ['>'], !.
s_until_gt([C|T]) --> [C], !, s_until_gt(T).
s_until_gt([]) --> [].

s_name([C|T]) --> [C], { s_namec(C) }, !, s_name(T).
s_name([]) --> [].

s_alpha(C) :- char_type(C, alpha), C \== '_', \+ char_type(C, digit(_)).
s_namec(C) :- ( s_alpha(C) ; char_type(C, digit(_)) ; memberchk(C, ['-', '_', ':']) ), !.

s_ws --> [C], { memberchk(C, [' ', '\n', '\t', '\r']) }, !, s_ws.
s_ws --> [].

s_attrs(As, SC) --> s_ws, s_attrs1(As, SC).
s_attrs1([], yes) --> ['/', '>'], !.
s_attrs1([], no) --> ['>'], !.
s_attrs1([N=V|As], SC) --> [C], { s_namec(C) }, !, s_name(NC), { atom_chars(N0, [C|NC]), downcase_atom(N0, N) },
    s_ws, s_value(V), s_attrs(As, SC).
s_attrs1(As, SC) --> [_], !, s_attrs(As, SC).
s_attrs1([], no) --> [].

s_value(V) --> ['='], !, s_ws, s_val(V).
s_value('') --> [].
s_val(V) --> ['"'], !, s_upto('"', Cs), { atom_chars(V, Cs) }.
s_val(V) --> ['\''], !, s_upto('\'', Cs), { atom_chars(V, Cs) }.
s_val(V) --> s_bare(Cs), { atom_chars(V, Cs) }.
s_upto(Q, []) --> [Q], !.
s_upto(Q, [C|T]) --> [C], !, s_upto(Q, T).
s_upto(_, []) --> [].
s_bare([C|T]) --> [C], { \+ memberchk(C, ['>', ' ', '/']) }, !, s_bare(T).
s_bare([]) --> [].

% ---- pass 1: per-tag pipeline -----------------------------------------------
s_pass1([], _, _, _, [], []).
s_pass1([open(N, As, SC)|Ts], M, An, B, [open(N, N2, As2, SC)|Os], QL) :- !,
    ( Ts = [text(Tx)|_] -> true ; Tx = '' ),
    s_pipeline(N, As, Tx, M, An, B, N2, As2, Q1),
    ( N == button -> B1 is B + 1 ; B1 = B ),
    s_pass1(Ts, M, An, B1, Os, Q2), append(Q1, Q2, QL).
s_pass1([T|Ts], M, An, B, [T|Os], QL) :- s_pass1(Ts, M, An, B, Os, QL).

s_attr(As, K, V) :- member(K=V, As), !.

s_pipeline(N0, A0, Tx, M, An, B, N, A, Notes) :-
    s_land(N0, A0, M, N1, A1, X1), s_click(N1, A1, M, N, A2, X2),
    s_img(N, A2, An, A3, X3), s_lang(N, A3, An, A4, X4), s_inp(N, A4, An, A5, X5),
    s_btn(N, A5, Tx, An, B, A6, X6), s_th(N, A6, A7, X7), s_icon(N, A7, A, X8),
    findall(q(Q), ( member(X, [X3, X4, X5, X6]), member(q(Q), X) ), Qs),
    findall(l(L), ( member(X, [X1, X2, X3, X4, X5, X6, X7, X8]), member(l(L), X) ), Ls),
    append(Qs, Ls, Notes).

s_land(div, A, M, N, A2, [l(landmark(Nat, Role))]) :-
    \+ s_attr(A, role, _),
    ( s_attr(A, id, I0) -> true ; I0 = '' ), ( s_attr(A, class, C0) -> true ; C0 = '' ),
    downcase_atom(I0, I), downcase_atom(C0, C),
    member(H-Nat-Role, [nav-nav-navigation, menu-nav-navigation, header-header-banner, footer-footer-contentinfo,
                        main-main-main, content-main-main, sidebar-aside-complementary, search-search-search]),
    ( sub_atom(I, _, _, _, H) ; sub_atom(C, _, _, _, H) ), !,
    ( M == semantic -> N = Nat, A2 = A ; N = div, append(A, [role=Role], A2) ).
s_land(N, A, _, N, A, []).

s_click(N0, A, M, N, A2, [l(clickable(N0, To))]) :-
    member(N0, [div, span, a]), s_attr(A, onclick, _), \+ s_attr(A, role, _),
    \+ ( N0 == a, s_attr(A, href, _) ), !,
    (   M == semantic -> N = button, To = button, findall(K=V, ( member(K=V, A), K \== tabindex ), A1),
        append(A1, [type=button], A2)
    ;   N = N0, To = role(button), append(A, [role=button], A1),
        ( s_attr(A1, tabindex, _) -> A2 = A1 ; append(A1, [tabindex='0'], A2) )
    ).
s_click(N, A, _, N, A, []).

s_ans(An, Q, V) :- member(ans(Q0, V0), An), Q0 == Q, !, V = V0.

s_img(img, A, An, A2, X) :- \+ s_attr(A, alt, _), !,
    ( s_attr(A, src, S) -> true ; S = unknown ),
    (   s_ans(An, img_alt(S), V)
    ->  ( V == decorative -> append(A, [alt=''], A2), X = [l(alt(S, decorative))]
                          ; append(A, [alt=V], A2), X = [l(alt(S, V))] )
    ;   A2 = A, X = [q(img_alt(S)), l(asked(img_alt(S)))] ).
s_img(_, A, _, A, []).

s_lang(html, A, An, A2, X) :- \+ s_attr(A, lang, _), !,
    ( s_ans(An, lang, L) -> append(A, [lang=L], A2), X = [l(lang(L))] ; A2 = A, X = [q(lang), l(asked(lang))] ).
s_lang(_, A, _, A, []).

s_inp(input, A, An, A2, X) :-
    \+ s_attr(A, 'aria-label', _), \+ s_attr(A, 'aria-labelledby', _), \+ s_attr(A, id, _),
    \+ ( s_attr(A, type, T), member(T, [hidden, submit, button, reset, image]) ), !,
    ( s_attr(A, name, Nm) -> true ; Nm = unnamed ),
    (   s_ans(An, input_label(Nm), V) -> append(A, ['aria-label'=V], A2), X = [l(label(Nm, V))]
    ;   A2 = A, X = [q(input_label(Nm)), l(asked(input_label(Nm)))] ).
s_inp(_, A, _, A, []).

s_btn(button, A, Tx, An, B, A2, X) :-
    \+ s_attr(A, 'aria-label', _), atom_chars(Tx, TC), \+ ( member(Ch, TC), \+ memberchk(Ch, [' ', '\n', '\t', '\r']) ), !,
    (   s_ans(An, button_label(B), V) -> append(A, ['aria-label'=V], A2), X = [l(button_label(B, V))]
    ;   A2 = A, X = [q(button_label(B)), l(asked(button_label(B)))] ).
s_btn(_, A, _, _, _, A, []).

s_th(th, A, A2, [l(scope(col))]) :- \+ s_attr(A, scope, _), !, append(A, [scope=col], A2).
s_th(_, A, A, []).

s_icon(N, A, A2, [l(hidden_icon)]) :-
    member(N, [i, span]), s_attr(A, class, C), sub_atom(C, _, _, _, icon),
    \+ s_attr(A, 'aria-hidden', _), \+ s_attr(A, 'aria-label', _), !, append(A, ['aria-hidden'=true], A2).
s_icon(_, A, A, []).

% ---- pass 2: rename close tags ----------------------------------------------
s_pass2([], _, []).
s_pass2([open(N, N2, A, SC)|Ts], St, [open(N2, A, SC)|Os]) :- !,
    ( ( member(N, [img, input, br, hr, meta, link, area, source]) ; SC == yes ) -> St2 = St ; St2 = [N-N2|St] ),
    s_pass2(Ts, St2, Os).
s_pass2([close(N)|Ts], St, [close(N2)|Os]) :- !,
    ( append(Pre, [N-N2|Post], St), \+ memberchk(N-_, Pre) -> append(Pre, Post, St2) ; N2 = N, St2 = St ),
    s_pass2(Ts, St2, Os).
s_pass2([T|Ts], St, [T|Os]) :- s_pass2(Ts, St, Os).

s_out(text(A), A).
s_out(raw(A), A).
s_out(close(N), A) :- format(atom(A), '</~w>', [N]).
s_out(open(N, As, SC), A) :-
    findall(X, ( member(K=V, As), ( V == '' -> format(atom(X), ' ~w', [K]) ; format(atom(X), ' ~w="~w"', [K, V]) ) ), Xs),
    atomic_list_concat(Xs, AX), ( SC == yes -> E = ' />' ; E = '>' ),
    format(atom(A), '<~w~w~w', [N, AX, E]).
