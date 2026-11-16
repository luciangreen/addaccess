# Addaccess

Adds accessibility to HTML pages automatically, using this mapping:

| Platform / Medium | Accessibility Technology | Direct ARIA Equivalent |
|---|---|---|
| Web (Native) | Semantic HTML (`<nav>`, `<button>`) | `role="navigation"`, `role="button"` |

- **semantic** mode uses native elements (`<nav>`, `<header>`, `<main>`, `<footer>`, `<aside>`, `<button>`). **aria** mode keeps the element and adds the role, plus `tabindex` for clickable elements.
- Automatic fixes: landmarks from id/class hints, clickable divs/spans/links, `th scope`, and `aria-hidden` on icons.
- **Checks with you where needed:** image alt text (or "decorative"), page language, input labels and icon-button labels. Unanswered items are returned as questions. Answer with `ans(Question, Value)`, or use `interactive/1` to be asked on the terminal.

Legal background (from the Siteimprove summary you linked): in Australia, the Disability Discrimination Act 1992 covers public and private sectors. Government agencies must meet WCAG 2.1, and AS EN 301 549:2020 recognises WCAG 2.1. New Zealand government pages must meet WCAG 2.1 up to Level AA. This tool helps with those checks but does not by itself make a site compliant.

```
?- example(H), add_access(html(H, semantic, []), R), print_result(R).
```

Proved properties: tokenising and serialising round-trip, text is never changed, the transformation is idempotent, tags stay balanced, answering every question leaves none open, semantic mode adds no redundant roles, the mapping table is present, and the implementation equals the DCG-based spec.

## Tests and proofs

```
swipl run_tests.pl        # runs the 200 saved I/O pairs and checks every proof
swipl tests/gen_io.pl     # regenerates tests/io_pairs.pl from spec.pl
```

- `tests/io_pairs.pl` has 200 saved `io(Id, Predicate, Input, ExpectedOutput)` facts.
- The expected outputs come from `spec.pl`, an independent specification written in a different style from the implementation (with a DCG tokenizer and two-pass transformer). Because the implementation is checked against a separate oracle, a pass is real evidence and not the program checking itself.
- `proofs.pl` has machine-checked `proof(Name, Goal)` theorems. Each one is checked exhaustively on a bounded domain or over sample inputs, and its comment gives the general (usually inductive) argument.

All files are plain, portable SWI-Prolog, with no packs needed.
