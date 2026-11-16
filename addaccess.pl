% addaccess - adds accessibility to HTML pages automatically, using the
% mapping between native semantic HTML and its direct ARIA equivalent, and
% checks with the user where a human answer is needed (alt text, labels,
% page language).
%
% Background (see README): in Australia the Disability Discrimination Act
% 1992 covers public and private websites; government sites must meet WCAG
% 2.1, and AS EN 301 549:2020 recognises WCAG 2.1. New Zealand government
% pages must meet WCAG 2.1 up to Level AA.
%
% add_access(+html(HTML, Mode, Answers), -result(NewHTML, Questions, Log))
%   Mode    semantic : use native elements (<nav>, <button>, ...)
%           aria     : keep the element and add the ARIA role instead
%   Answers list of ans(Question, Value), e.g. ans(img_alt('logo.png'), 'Company logo'),
%           ans(img_alt('line.png'), decorative), ans(lang, 'en-AU'),
%           ans(input_label(email), 'Email address'), ans(button_label(1), 'Search')
%   Questions are what still needs the user's answer.
%
% Try:  ?- example(H), add_access(html(H, semantic, []), R), print_result(R).

% ---- the mapping table ------------------------------------------------------
% mapping(Platform/Medium, Accessibility technology, Direct ARIA equivalent)
mapping('Web (Native)', 'Semantic HTML (<nav>, <button>)', 'role="navigation", role="button"').

% landmark(Hint, NativeElement, AriaRole): a div whose id/class contains Hint.
landmark(nav,     nav,    navigation).
landmark(menu,    nav,    navigation).
landmark(header,  header, banner).
landmark(footer,  footer, contentinfo).
landmark(main,    main,   main).
landmark(content, main,   main).
landmark(sidebar, aside,  complementary).
landmark(search,  search, search).

void(img). void(input). void(br). void(hr). void(meta). void(link). void(area). void(source).

% ---- entry point ------------------------------------------------------------
add_access(html(H, Mode, Answers), result(Out, Questions, Log)) :-
    tokenize(H, Ts),
    transform(Ts, Mode, Answers, 1, [], Ts2, Qs0, Log),
    dedup(Qs0, [], Questions),
    serialize(Ts2, Out).

dedup([], _, []).
dedup([Q|Qs], Seen, R) :- ( memberchk(Q, Seen) -> R = R1 ; R = [Q|R1] ), dedup(Qs, [Q|Seen], R1).

% ---- tokenizer --------------------------------------------------------------
% Tokens: text(A), raw(A) (comments, doctype), open(Name, Attrs, SelfClosing),
% close(Name). Attrs is a list of Name=Value (Value '' for boolean attributes).
tokenize(H, Ts) :- atom_chars(H, Cs), toks(Cs, Ts).

toks([], []) :- !.
toks(['<', '!'|Cs], [raw(A)|Ts]) :- !, upto_gt(Cs, Body, Rest), atom_chars(B, Body),
    atom_concat('<!', B, A0), atom_concat(A0, '>', A), toks(Rest, Ts).
toks(['<', '/'|Cs], [close(N)|Ts]) :- !, name_chars(Cs, NCs, R1), atom_chars(N0, NCs),
    downcase_atom(N0, N), upto_gt(R1, _, Rest), toks(Rest, Ts).
toks(['<', C|Cs], [open(N, As, SC)|Ts]) :- is_alpha(C), !, name_chars([C|Cs], NCs, R1),
    atom_chars(N0, NCs), downcase_atom(N0, N), attrs(R1, As, SC, Rest), toks(Rest, Ts).
toks(Cs, [text(A)|Ts]) :- text_chars(Cs, T, Rest), T \== [], !, atom_chars(A, T), toks(Rest, Ts).
toks([C|Cs], [text(C)|Ts]) :- toks(Cs, Ts).

text_chars([], [], []).
text_chars(['<'|Cs], [], ['<'|Cs]) :- !.
text_chars([C|Cs], [C|T], R) :- text_chars(Cs, T, R).

upto_gt([], [], []).
upto_gt(['>'|Cs], [], Cs) :- !.
upto_gt([C|Cs], [C|B], R) :- upto_gt(Cs, B, R).

is_alpha(C) :- char_code(C, X), ( X >= 0'a, X =< 0'z ; X >= 0'A, X =< 0'Z ), !.
name_char(C) :- is_alpha(C), !.
name_char(C) :- char_code(C, X), ( X >= 0'0, X =< 0'9 ), !.
name_char('-'). name_char('_'). name_char(':').

name_chars([C|Cs], [C|N], R) :- name_char(C), !, name_chars(Cs, N, R).
name_chars(Cs, [], Cs).

attrs(Cs, As, SC, Rest) :- skip_ws(Cs, Cs1), attrs1(Cs1, As, SC, Rest).
attrs1([], [], no, []).
attrs1(['>'|R], [], no, R) :- !.
attrs1(['/', '>'|R], [], yes, R) :- !.
attrs1(Cs, [N=V|As], SC, Rest) :- name_chars(Cs, NCs, R1), NCs \== [], !,
    atom_chars(N0, NCs), downcase_atom(N0, N), skip_ws(R1, R2),
    (   R2 = ['='|R3] -> skip_ws(R3, R4), value(R4, V, R5) ; V = '', R5 = R2 ),
    attrs(R5, As, SC, Rest).
attrs1([_|Cs], As, SC, Rest) :- attrs(Cs, As, SC, Rest).

value(['"'|Cs], V, R) :- !, upto(Cs, '"', VCs, R), atom_chars(V, VCs).
value(['\''|Cs], V, R) :- !, upto(Cs, '\'', VCs, R), atom_chars(V, VCs).
value(Cs, V, R) :- bare(Cs, VCs, R), atom_chars(V, VCs).
upto([], _, [], []).
upto([Q|Cs], Q, [], Cs) :- !.
upto([C|Cs], Q, [C|V], R) :- upto(Cs, Q, V, R).
bare([], [], []).
bare([C|Cs], [], [C|Cs]) :- ( C == '>' ; C == ' ' ; C == '/' ), !.
bare([C|Cs], [C|V], R) :- bare(Cs, V, R).

skip_ws([C|Cs], R) :- ( C == ' ' ; C == '\n' ; C == '\t' ; C == '\r' ), !, skip_ws(Cs, R).
skip_ws(Cs, Cs).

% ---- serializer -------------------------------------------------------------
serialize(Ts, Out) :- maplist(tok_atom, Ts, As), atomic_list_concat(As, Out).

tok_atom(text(A), A).
tok_atom(raw(A), A).
tok_atom(close(N), A) :- atomic_list_concat(['</', N, '>'], A).
tok_atom(open(N, As, SC), A) :-
    maplist(attr_atom, As, AAs), atomic_list_concat(AAs, Attrs),
    ( SC == yes -> End = ' />' ; End = '>' ),
    atomic_list_concat(['<', N, Attrs, End], A).
attr_atom(N='', A) :- !, atomic_list_concat([' ', N], A).
attr_atom(N=V, A) :- atomic_list_concat([' ', N, '="', V, '"'], A).

% ---- transformation ---------------------------------------------------------
% transform(Tokens, Mode, Answers, ButtonNo, Stack, Out, Questions, Log)
% Stack holds Original-New names of open elements that were renamed.
transform([], _, _, _, _, [], [], []).
transform([close(N)|Ts], M, An, B, St, [close(N2)|Os], Qs, Log) :- !,
    ( select_first(N-N2, St, St2) -> true ; N2 = N, St2 = St ),
    transform(Ts, M, An, B, St2, Os, Qs, Log).
transform([open(N, As, SC)|Ts], M, An, B, St, [open(N2, As2, SC)|Os], Qs, Log) :- !,
    next_text(Ts, Txt),
    fix_tag(N, As, Txt, M, An, B, N2, As2, Q1, L1),
    ( N == button -> B1 is B + 1 ; B1 = B ),
    ( ( void(N) ; SC == yes ) -> St2 = St ; St2 = [N-N2|St] ),
    transform(Ts, M, An, B1, St2, Os, Q2, L2),
    append(Q1, Q2, Qs), append(L1, L2, Log).
transform([T|Ts], M, An, B, St, [T|Os], Qs, Log) :- transform(Ts, M, An, B, St, Os, Qs, Log).

select_first(X, [Y|T], T) :- X = Y, !.
select_first(X, [Y|T], [Y|R]) :- select_first(X, T, R).

next_text([text(A)|_], A) :- !.
next_text(_, '').

% fix_tag(+Name, +Attrs, +FollowingText, +Mode, +Answers, +ButtonNo, -Name2, -Attrs2, -Questions, -Log)
fix_tag(N, As, Txt, M, An, B, N2, As2, Qs, Log) :-
    rule_landmark(N, As, M, Na, Aa, La),
    rule_clickable(Na, Aa, M, Nb, Ab, Lb),
    rule_img(Nb, Ab, An, Ac, Qc, Lc),
    rule_lang(Nb, Ac, An, Ad, Qd, Ld),
    rule_input(Nb, Ad, An, Ae, Qe, Le),
    rule_button(Nb, Ae, Txt, An, B, Af, Qf, Lf),
    rule_th(Nb, Af, Ag, Lg),
    rule_icon(Nb, Ag, As2, Lh),
    N2 = Nb,
    append([Qc, Qd, Qe, Qf], Qs),
    append([La, Lb, Lc, Ld, Le, Lf, Lg, Lh], Log).

has(As, K) :- memberchk(K=_, As).
get(As, K, V) :- memberchk(K=V, As).
add(As, K, V, As2) :- append(As, [K=V], As2).

hint_of(As, Hint, Native, Role) :-
    ( get(As, id, I) -> true ; I = '' ), ( get(As, class, C) -> true ; C = '' ),
    downcase_atom(I, LI), downcase_atom(C, LC),
    landmark(Hint, Native, Role),
    ( sub_atom(LI, _, _, _, Hint) ; sub_atom(LC, _, _, _, Hint) ), !.

rule_landmark(div, As, M, N2, As2, [landmark(Native, Role)]) :-
    \+ has(As, role), hint_of(As, _, Native, Role), !,
    ( M == semantic -> N2 = Native, As2 = As ; N2 = div, add(As, role, Role, As2) ).
rule_landmark(N, As, _, N, As, []).

rule_clickable(N, As, M, N2, As2, [clickable(N, To)]) :-
    memberchk(N, [div, span, a]), has(As, onclick), \+ has(As, role),
    \+ ( N == a, has(As, href) ), !,
    (   M == semantic -> N2 = button, To = button, exclude(is_attr(tabindex), As, As1), add(As1, type, button, As2)
    ;   N2 = N, To = role(button), add(As, role, button, As3),
        ( has(As3, tabindex) -> As2 = As3 ; add(As3, tabindex, '0', As2) )
    ).
rule_clickable(N, As, _, N, As, []).

is_attr(K, K=_).

rule_img(img, As, An, As2, Qs, Log) :- \+ has(As, alt), !,
    ( get(As, src, Src) -> true ; Src = unknown ),
    (   memberchk(ans(img_alt(Src), V), An)
    ->  Qs = [], ( V == decorative -> add(As, alt, '', As2), Log = [alt(Src, decorative)]
                                   ; add(As, alt, V, As2), Log = [alt(Src, V)] )
    ;   As2 = As, Qs = [img_alt(Src)], Log = [asked(img_alt(Src))]
    ).
rule_img(_, As, _, As, [], []).

rule_lang(html, As, An, As2, Qs, Log) :- \+ has(As, lang), !,
    (   memberchk(ans(lang, L), An) -> add(As, lang, L, As2), Qs = [], Log = [lang(L)]
    ;   As2 = As, Qs = [lang], Log = [asked(lang)]
    ).
rule_lang(_, As, _, As, [], []).

rule_input(input, As, An, As2, Qs, Log) :-
    \+ has(As, 'aria-label'), \+ has(As, 'aria-labelledby'), \+ has(As, id),
    \+ ( get(As, type, T), memberchk(T, [hidden, submit, button, reset, image]) ), !,
    ( get(As, name, Nm) -> true ; Nm = unnamed ),
    (   memberchk(ans(input_label(Nm), V), An) -> add(As, 'aria-label', V, As2), Qs = [], Log = [label(Nm, V)]
    ;   As2 = As, Qs = [input_label(Nm)], Log = [asked(input_label(Nm))]
    ).
rule_input(_, As, _, As, [], []).

rule_button(button, As, Txt, An, B, As2, Qs, Log) :-
    \+ has(As, 'aria-label'), blank(Txt), !,
    (   memberchk(ans(button_label(B), V), An) -> add(As, 'aria-label', V, As2), Qs = [], Log = [button_label(B, V)]
    ;   As2 = As, Qs = [button_label(B)], Log = [asked(button_label(B))]
    ).
rule_button(_, As, _, _, _, As, [], []).

blank(T) :- atom_chars(T, Cs), forall(member(C, Cs), memberchk(C, [' ', '\n', '\t', '\r'])).

rule_th(th, As, As2, [scope(col)]) :- \+ has(As, scope), !, add(As, scope, col, As2).
rule_th(_, As, As, []).

rule_icon(N, As, As2, [hidden_icon]) :-
    memberchk(N, [i, span]), get(As, class, C), sub_atom(C, _, _, _, icon),
    \+ has(As, 'aria-hidden'), \+ has(As, 'aria-label'), !, add(As, 'aria-hidden', true, As2).
rule_icon(_, As, As, []).

% ---- interaction ------------------------------------------------------------
print_result(result(H, Qs, Log)) :-
    format("Accessible HTML:~n~w~n~nChanges: ~w~n", [H, Log]),
    ( Qs == [] -> writeln('Nothing left to check with you.')
    ; writeln('Please check these with me (answer with ans(Question, Value)):'),
      forall(member(Q, Qs), ( question_text(Q, T), format("  ~w  - ~w~n", [Q, T]) )) ).

question_text(img_alt(S), T) :- format(atom(T), 'What does image ~w show? (or decorative)', [S]).
question_text(lang, 'What language is the page in? (e.g. en-AU)').
question_text(input_label(N), T) :- format(atom(T), 'What is the label for input ~w?', [N]).
question_text(button_label(B), T) :- format(atom(T), 'What does icon button ~w do?', [B]).

% interactive/1: asks each question on the terminal and applies the answers.
interactive(H) :-
    add_access(html(H, semantic, []), result(_, Qs, _)),
    findall(ans(Q, V), ( member(Q, Qs), question_text(Q, T), format("~w ", [T]),
                         read_term(V0, []), ( V0 == decorative -> V = decorative ; V = V0 ) ), An),
    add_access(html(H, semantic, An), R), print_result(R).

example('<html><body><div id="main-nav"><a href="/">Home</a></div><div class="header">Shop</div><img src="logo.png"><div onclick="buy()">Buy</div><button><i class="icon-search"></i></button><input name="email"><table><tr><th>Item</th></tr></table></body></html>').
