% inputs.pl - 200 generated HTML pages, both modes, with and without answers.
input(Id, add_access, html(H, Mode, An)) :- between(1, 200, Id), gen_html(Id, H, Srcs),
    ( Id mod 2 =:= 0 -> Mode = semantic ; Mode = aria ),
    K is (Id // 2) mod 3, answers(K, Srcs, An).

lcg(S0, S) :- S is (S0 * 1103515245 + 12345) mod 2147483648.
rnd(M, S0, S, X) :- lcg(S0, S), X is (S >> 16) mod M.

gen_html(Id, H, Srcs) :-
    S0 is Id * 7727, rnd(3, S0, S1, L), rnd(5, S1, S2, N0), N is N0 + 2,
    frags(N, S2, Fs, Srcs),
    nth0(L, ['<html>', '<html lang="en">', '<!DOCTYPE html><HTML>'], Open),
    atomic_list_concat([Open, '<body>'|Fs], A0), atom_concat(A0, '</body></html>', H).

frags(0, _, [], []) :- !.
frags(N, S0, [F|Fs], Srcs) :- rnd(16, S0, S1, K), frag(K, N, F, Src),
    N1 is N - 1, frags(N1, S1, Fs, Srcs0), ( Src == none -> Srcs = Srcs0 ; Srcs = [Src|Srcs0] ).

frag(0, _, '<div id="nav"><a href="/">Home</a></div>', none).
frag(1, _, '<div class="site-header"><h1>Title</h1></div>', none).
frag(2, N, F, Src) :- format(atom(Src), 'pic~w.png', [N]), format(atom(F), '<img src="~w">', [Src]).
frag(3, N, F, Src) :- format(atom(Src), 'deco~w.gif', [N]), format(atom(F), '<IMG SRC=~w />', [Src]).
frag(4, _, '<img src="ok.png" alt="Fine">', none).
frag(5, _, '<div onclick="go()">Go</div>', none).
frag(6, _, '<span onclick=\'x()\' tabindex="1">Open</span>', none).
frag(7, _, '<a onclick="menu()">Menu</a>', none).
frag(8, _, '<button><i class="icon-close"></i></button>', none).
frag(9, _, '<button>Send</button>', none).
frag(10, N, F, none) :- format(atom(F), '<input name="field~w" type="text">', [N]).
frag(11, _, '<input type="hidden" name="t"><input id="q"><label for="q">Q</label>', none).
frag(12, _, '<table><tr><th>A</th><th scope="row">B</th></tr></table>', none).
frag(13, _, '<div class="footer">(c) 2026</div><div class="sidebar"><div class="menu">M</div></div>', none).
frag(14, _, '<span class="icon star" aria-hidden="true"></span><span class="icon">*</span>', none).
frag(15, _, '<!-- comment --><p>Text with <b>bold</b> &amp; 3 < 4</p><br>', none).

answers(0, _, []).
answers(1, Srcs, [ans(lang, 'en-AU'), ans(button_label(1), 'Close') | As]) :-
    findall(ans(img_alt(S), 'A picture'), member(S, Srcs), As).
answers(2, Srcs, [ans(input_label(field2), 'Name'), ans(input_label(field3), 'Phone') | As]) :-
    findall(ans(img_alt(S), decorative), member(S, Srcs), As).
