# /// script
# requires-python = ">=3.11"
# dependencies = ["textual>=1.0", "pyyaml>=6"]
# ///
"""Review the draft rule files: find what needs attention, answer rulings, mark rules reviewed,
flag a rule for another agent pass, or open the file in your editor.

    make rules-review              # the TUI
    make rules-review BY=@handle   # sign as someone else
    make rules-review SWEEP=boronmir   # only the rules that affect one hero (sweeps/)
    make rules-sweep SWEEP=boronmir    # those rules and what each needs, as text
    make rules-queue               # what waits for an agent, as text
    make rules-agent               # start Claude Code on that queue

Every change is written straight into the rule file (see rulefiles.py) and RULINGS.md is
regenerated after it, so `git diff` shows exactly what the review did.
"""

import argparse
import os
import shlex
import subprocess
import sys
import webbrowser
from pathlib import Path

import rulefiles as rf

from rich.console import Group
from rich.syntax import Syntax
from rich.text import Text
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import DataTable, Footer, Header, Input, OptionList, Static
from textual.widgets.option_list import Option

FILTERS = ["needs you", "all", "agent queue", "reviewed"]


# --- signing ----------------------------------------------------------------------------------

def reviewer(arg):
    if arg:
        return arg if arg.startswith("@") else "@" + arg
    if env := os.environ.get("HESINDION_REVIEWER"):
        return env if env.startswith("@") else "@" + env
    try:
        login = subprocess.run(["gh", "api", "user", "--jq", ".login"], capture_output=True,
                               text=True, timeout=5).stdout.strip()
        if login:
            return "@" + login
    except (OSError, subprocess.TimeoutExpired):
        pass
    sys.exit("Who is reviewing? Pass --by @handle or set HESINDION_REVIEWER.")


def regenerate_index():
    """Rewrite RULINGS.md the way rulings.py does, so --check stays green after an edit."""
    import rulings
    try:
        rulings.OUT.write_text(rulings.render(rulings.collect()), encoding="utf-8")
    except Exception as e:                               # a file that does not parse
        return str(e)
    return None


def editor_command(path, line):
    editor = os.environ.get("VISUAL") or os.environ.get("EDITOR") or "vi"
    argv = shlex.split(editor)
    name = Path(argv[0]).name
    if name in ("code", "cursor", "codium", "windsurf"):
        return argv + ["--wait", "-g", f"{path}:{line}"]
    if name in ("zed", "subl", "hx", "helix"):
        return argv + ([] if name in ("hx", "helix") else ["--wait"]) + [f"{path}:{line}"]
    return argv + [f"+{line}", str(path)]           # vi, vim, nvim, nano, emacs, micro, kak


# --- rendering --------------------------------------------------------------------------------

def one_line(text):
    return " ".join(str(text).split())


def status_cell(rule):
    if rule.error:
        return Text("✗ yaml", style="bold red")
    if rule.to_answer:
        return Text(f"? {len(rule.to_answer)}", style="bold yellow")
    if rule.needs_agent:
        return Text("⟳ agent", style="cyan")
    if rule.reviewed:
        return Text("✓", style="green")
    if rule.kind == "shared":
        return Text("")
    return Text("· review", style="dim")


def rule_header(rule):
    t = Text()
    t.append(f"{rule.id} · {rule.name}", style="bold")
    t.append(f"   {rule.kind}", style="dim")
    for key in ("group", "ruleset"):
        if rule.data.get(key):
            t.append(f" · {rule.data[key]}", style="dim")
    t.append(f"\n{rule.path}\n", style="dim")
    src = rule.data.get("source") or {}
    if src:
        t.append(f"{src.get('url', '')}", style="underline blue")
        t.append(f"\n{src.get('book', '')} S. {src.get('page', '?')}, checked {src.get('checked')}"
                 f"{'' if src.get('hash') else ', no hash'}\n", style="dim")
    if rule.error:
        t.append(f"\n{rule.error}\n", style="red")
    rv = rule.reviewed
    if rule.kind != "shared":
        if rv:
            t.append(f"Reviewed by {rv.get('by')} on {rv.get('date')}\n", style="green")
        else:
            t.append("Not reviewed — read every clause against the page, then press r\n",
                     style="yellow")
    if ap := rule.agent_pass:
        req = ap.get("requested") or {}
        t.append(f"Flagged for an agent pass by {req.get('by')} on {req.get('date')}", style="cyan")
        if ap.get("about"):
            t.append(f" about {', '.join(map(str, ap['about']))}", style="cyan")
        t.append(f": {one_line(ap.get('note', ''))}\n", style="cyan")
    todo = rule.needs_you + rule.needs_agent
    if todo:
        t.append("To do: " + "; ".join(todo), style="bold")
    return t


class Card(Static, can_focus=True):
    """One focusable piece of a rule: a clause, a ruling or a situation."""

    DEFAULT_CSS = """
    Card { padding: 0 1; margin: 0 0 1 0; border-left: tall $panel; }
    Card:focus { border-left: tall $accent; background: $boost; }
    """

    def __init__(self, renderable, *, kind, target, path, line):
        super().__init__(renderable)
        self.kind, self.target, self.path, self.line = kind, target, path, line

    def on_mount(self):
        self.app.focus_if_pending(self)


def flag_line(rule, item_id):
    note = rule.flagged(item_id)
    return Text(f"⟳ sent back to the agent: {one_line(note)}", style="cyan") if note else None


def clause_card(rule, c):
    head = Text()
    head.append(f"{c.id} · ", style="bold")
    head.append("encoded" if c.encoded else "not encoded", style="green" if c.encoded else "yellow")
    if c.data.get("why"):
        head.append(f" — {one_line(c.data['why'])}", style="dim")
    if "# FORMAT:" in c.raw:
        head.append("  FORMAT note", style="magenta")
    body = Text(one_line(c.data.get("text", "")), style="italic")
    parts = [head, body]
    if flag := flag_line(rule, c.id):
        parts.append(flag)
    if c.encoded:
        parts.append(Syntax(c.raw, "yaml", theme="ansi_dark", background_color="default",
                            word_wrap=True))
    return Card(Group(*parts), kind="clause", target=c, path=rule.path, line=c.line)


RULING_STYLE = {"open": ("OPEN", "bold black on yellow"), "answered": ("ANSWERED · for the agent", "bold black on cyan"),
                "decided": ("DECIDED", "bold black on green")}


def ruling_card(rule, r):
    d = r.data
    label, style = RULING_STYLE[r.state]
    t = Text()
    t.append(f" {label} ", style=style)
    t.append(f"  {r.id}\n", style="bold")
    if flag := flag_line(rule, r.id):
        t.append_text(flag)
        t.append("\n")
    t.append(one_line(d.get("question", "")) + "\n", style="bold")
    if r.state == "decided":
        t.append(f"Answer: {one_line(d.get('answer', ''))}", style="green")
        dec = d.get("decided") or {}
        t.append(f"  — {dec.get('by')}, {dec.get('date')}\n", style="dim")
        return Card(t, kind="ruling", target=r, path=r.path, line=r.line)
    if d.get("context"):
        t.append(one_line(d["context"]) + "\n", style="dim")
    if d.get("situations"):
        t.append("Situations: " + ", ".join(map(str, d["situations"])) + "\n", style="dim")
    for key, opt in (d.get("options") or {}).items():
        rec = key == d.get("recommended")
        t.append(f"  {key}) ", style="bold")
        t.append(f"{one_line(opt.get('says', ''))}", style="bold" if rec else "")
        t.append(f"  → app: {one_line(opt.get('app', ''))}", style="dim")
        t.append("  ★ recommended\n" if rec else "\n", style="yellow")
    if d.get("why_recommended"):
        t.append(f"Why {d.get('recommended')}: {one_line(d['why_recommended'])}\n", style="dim")
    if r.state == "answered":
        t.append(f"Your answer: {one_line(d['answer'])} ", style="cyan")
        t.append("(enter to change)", style="dim")
    else:
        t.append("enter to choose an answer · a if the question or options are wrong", style="yellow")
    return Card(t, kind="ruling", target=r, path=r.path, line=r.line)


def situation_card(s):
    t = Text()
    t.append(f"{s.file} {s.id} · ", style="bold")
    t.append(s.name)
    if s.diverges:
        t.append(f"\n  app today: {s.app_today}", style="red" if "wrong" in str(s.app_today) else "yellow")
    return Card(t, kind="situation", target=s, path=Path("situations") / f"{s.file}.yaml",
                line=s.line)


# --- modals -----------------------------------------------------------------------------------

class Ask(ModalScreen):
    """A question with one text field. Dismisses with the text, or None on escape."""

    DEFAULT_CSS = """
    Ask { align: center middle; }
    Ask > Vertical { width: 90%; max-width: 110; height: auto; max-height: 90%;
                     border: thick $accent; background: $surface; padding: 1 2; }
    Ask VerticalScroll { height: auto; max-height: 30; }
    Ask Input { margin-top: 1; }
    """
    BINDINGS = [Binding("escape", "cancel", "Cancel")]
    AUTO_FOCUS = "Input"

    def __init__(self, title, body, fields):
        super().__init__()
        self.title_, self.body, self.fields = title, body, fields   # [(placeholder, value)]

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static(Text(self.title_, style="bold"))
            with VerticalScroll():
                yield Static(self.body)
            for placeholder, value in self.fields:
                yield Input(value=value, placeholder=placeholder)

    def on_input_submitted(self, event):
        inputs = list(self.query(Input))
        i = inputs.index(event.input)
        if i + 1 < len(inputs):
            inputs[i + 1].focus()
        else:
            self.dismiss([x.value for x in inputs])

    def action_cancel(self):
        self.dismiss(None)


class Choose(ModalScreen):
    """Answer a ruling by picking one of its options. Dismisses with ("answer", text),
    ("flag", None) or None on escape. Writing your own answer is one of the choices, and only
    then does a text field appear."""

    DEFAULT_CSS = """
    Choose { align: center middle; }
    Choose > Vertical { width: 90%; max-width: 110; height: auto; max-height: 90%;
                        border: thick $accent; background: $surface; padding: 1 2; }
    Choose #context { height: auto; max-height: 12; }
    Choose OptionList { height: auto; max-height: 24; margin-top: 1; }
    Choose Input { margin-top: 1; display: none; }
    Choose Input.shown { display: block; }
    Choose .hint { margin-top: 1; color: $text-muted; }
    """
    BINDINGS = [Binding("escape", "back", "Cancel")]
    AUTO_FOCUS = "OptionList"

    def __init__(self, r, can_flag=True):
        super().__init__()
        self.r, self.can_flag = r, can_flag
        self.options = r.data.get("options") or {}

    def compose(self) -> ComposeResult:
        d = self.r.data
        answer = one_line(d.get("answer") or "")
        with Vertical():
            yield Static(Text(one_line(d.get("question", self.r.id)), style="bold"))
            if d.get("context"):
                with VerticalScroll(id="context"):
                    yield Static(Text(one_line(d["context"]), style="dim"))
            choices = []
            for key, opt in self.options.items():
                t = Text()
                t.append(f"{key}) ", style="bold")
                t.append(one_line(opt.get("says", "")))
                if key == d.get("recommended"):
                    t.append("  ★ recommended", style="yellow")
                    if d.get("why_recommended"):
                        t.append(f"\n   why: {one_line(d['why_recommended'])}", style="dim yellow")
                t.append(f"\n   app: {one_line(opt.get('app', ''))}", style="dim")
                choices.append(Option(t, id=f"opt:{key}"))
            own = "None of these fits: write my own answer"
            if answer and answer not in self.options:
                own = f"Change my own answer: {answer}"
            choices.append(Option(Text(own, style="italic"), id="own"))
            if self.can_flag:
                choices.append(Option(Text("The question or the options are wrong: send it back "
                                           "to the agent", style="italic"), id="flag"))
            if answer:
                choices.append(Option(Text("Clear my answer and reopen the ruling",
                                           style="italic"), id="clear"))
            yield OptionList(*choices)
            yield Input(value="" if answer in self.options else answer,
                        placeholder="your answer; enter saves, escape goes back to the choices")
            keys = "/".join(self.options)
            yield Static(f"↑↓ and enter, or press {keys} to pick an option · escape cancels",
                         classes="hint")

    def on_mount(self):
        d = self.r.data
        start = d.get("answer") if d.get("answer") in self.options else d.get("recommended")
        ids = [f"opt:{k}" for k in self.options]
        if f"opt:{start}" in ids:
            self.query_one(OptionList).highlighted = ids.index(f"opt:{start}")

    def on_key(self, event):
        if self.focused is not self.query_one(Input) and event.character in self.options:
            event.stop()
            self.dismiss(("answer", event.character))

    def on_option_list_option_selected(self, event):
        kind, _, key = event.option.id.partition(":")
        if kind == "opt":
            self.dismiss(("answer", key))
        elif kind == "flag":
            self.dismiss(("flag", None))
        elif kind == "clear":
            self.dismiss(("answer", ""))
        else:
            field = self.query_one(Input)
            field.add_class("shown")
            field.focus()

    def on_input_submitted(self, event):
        if event.value.strip():
            self.dismiss(("answer", event.value))

    def action_back(self):
        field = self.query_one(Input)
        if field.has_class("shown"):
            field.remove_class("shown")
            self.query_one(OptionList).focus()
        else:
            self.dismiss(None)


class Confirm(ModalScreen):
    DEFAULT_CSS = """
    Confirm { align: center middle; }
    Confirm > Static { width: 80; height: auto; border: thick $accent; background: $surface;
                       padding: 1 2; }
    """
    BINDINGS = [Binding("y", "yes", "Yes"), Binding("n,escape", "no", "No")]

    def __init__(self, text):
        super().__init__()
        self.text = text

    def compose(self) -> ComposeResult:
        yield Static(self.text)

    def action_yes(self):
        self.dismiss(True)

    def action_no(self):
        self.dismiss(False)


def welcome_text(by, you, unrev, agent, sweep=None, missing=()):
    t = Text()
    t.append("Rule review\n\n", style="bold")
    if sweep:
        t.append(f"Only the rules that affect {sweep.name} (sweeps/, without SWEEP= all of them). ")
        if missing:
            t.append(f"Not drafted yet, so not in the list: {', '.join(i for i, _ in missing)}.")
        t.append("\n\n")
    t.append(f"Signing as {by}. Right now: {you} open ruling{'s' * (you != 1)} for you, "
             f"{unrev} rule{'s' * (unrev != 1)} not reviewed, {agent} for the agent.\n\n")
    t.append("How a review goes\n", style="bold")
    for step in (
        "Press n. It jumps to the next thing that needs you: an open ruling first, then a rule "
        "nobody has reviewed yet. If n would leave a rule with rulings still open, it asks first.",
        "On a ruling, press enter and pick one of its options, or type its letter. If none "
        "fits, the last choices let you write your own answer instead. The answer goes into the "
        "rule file; the next agent pass acts on it.",
        "If the question or its options are wrong, pick \"send it back to the agent\" (or press "
        "a on the ruling): write what is wrong, and the ruling stays open until the agent has "
        "redone it. p takes you back to where n came from, to look again or change an answer.",
        "To review a rule, press o to open its page, read every clause against it, then press r. "
        "A clause that is wrong: a on it to send it back, or e to fix it yourself.",
        "When you are done, run `make rules-agent` for the agent pass, and look at `git diff`: "
        "every change you made is there.",
    ):
        t.append("  • ", style="bold")
        t.append(step + "\n")
    t.append("\nKeys\n", style="bold")
    for key, what in (
        ("n", "next thing that needs you"),
        ("p", "back to where n came from"),
        ("j / k, tab", "next / previous card (ruling, clause, situation)"),
        ("↑ / ↓", "move between rules in the list"),
        ("enter", "choose an answer for the focused ruling; on anything else, open the editor"),
        ("r", "mark the rule reviewed (again to withdraw)"),
        ("a", "send the rule, or the focused clause or ruling, back to the agent"),
        ("e", "open the file in $VISUAL / $EDITOR at the focused line"),
        ("o", "open the rule's page in the browser"),
        ("f", "filter: needs you → all → agent queue → reviewed"),
        ("/", "search by id, name or kind"),
        ("?", "this help"),
        ("q", "quit"),
    ):
        t.append(f"  {key:<12}", style="bold yellow")
        t.append(what + "\n")
    t.append("\nIn the list: ? n open rulings · ⟳ waits for the agent · ✓ reviewed · "
             "· review not yet reviewed.\n", style="dim")
    t.append("\nEnter or escape to start.", style="dim")
    return t


class Welcome(ModalScreen):
    """The usage flow and the keys, shown at start and on ?."""

    DEFAULT_CSS = """
    Welcome { align: center middle; }
    Welcome > VerticalScroll { width: 90%; max-width: 100; height: auto; max-height: 90%;
                               border: thick $accent; background: $surface; padding: 1 2; }
    """
    BINDINGS = [Binding("enter,escape,space,question_mark", "close", "Close")]

    def __init__(self, text):
        super().__init__()
        self.text = text

    def compose(self) -> ComposeResult:
        with VerticalScroll():
            yield Static(self.text)

    def action_close(self):
        self.dismiss(None)


# --- the app ----------------------------------------------------------------------------------

class Review(App):
    TITLE = "Rule review"
    CSS = """
    #left { width: 62; }
    #search { dock: top; }
    #table { height: 1fr; }
    #detail { padding: 0 1; }
    .header { margin-bottom: 1; }
    .section { color: $text-muted; text-style: bold; margin: 1 0 0 0; }
    """
    BINDINGS = [
        Binding("n", "next", "Next to do"),
        Binding("p", "back", "Back"),
        Binding("f", "cycle_filter", "Filter"),
        Binding("slash", "search", "Search"),
        Binding("enter", "activate", "Answer / open", show=False),
        Binding("r", "review", "Reviewed"),
        Binding("a", "flag", "Send back to agent"),
        Binding("e", "edit", "Edit"),
        Binding("o", "open_page", "Page"),
        Binding("j", "focus_next_card", "", show=False),
        Binding("k", "focus_prev_card", "", show=False),
        Binding("question_mark", "help", "Help"),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self, by, sweep=None):
        super().__init__()
        self.by = by
        self.sweep = sweep         # only the rules that affect one hero
        self.missing = []          # the sweep's rules without a file yet
        self.filter = 0
        self.query_text = ""
        self.rules = []
        self.current = None
        self.pending_focus = None  # which card to focus once it mounts
        self.history = []          # where n jumped from: (rule id, card kind, card id)

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(id="left"):
                yield Input(placeholder="/ search id, name, kind", id="search")
                yield DataTable(id="table", cursor_type="row", zebra_stripes=True)
            yield VerticalScroll(id="detail")
        yield Footer()

    def on_mount(self):
        table = self.query_one("#table", DataTable)
        table.add_columns("", "Rule", "Name")
        self.reload()
        table.focus()
        self.action_help()

    def action_help(self):
        you = sum(len(r.to_answer) for r in self.rules)
        unrev = sum(1 for r in self.rules if not r.reviewed and r.kind != "shared")
        agent = sum(bool(r.needs_agent) for r in self.rules)
        self.push_screen(Welcome(welcome_text(self.by, you, unrev, agent, self.sweep, self.missing)))

    # data

    def reload(self, keep=None):
        self.rules = rf.load()
        if self.sweep:
            self.missing = self.sweep.missing(self.rules)
            self.rules = self.sweep.of(self.rules)
        self.refresh_table(keep or (self.current.id if self.current else None))

    def visible(self):
        f = FILTERS[self.filter]
        q = self.query_text.lower()
        out = []
        for r in self.rules:
            if self.current and r.id == self.current.id:   # stays put until you move on
                out.append(r)
                continue
            if f == "needs you" and not r.needs_you:
                continue
            if f == "agent queue" and not r.needs_agent:
                continue
            if f == "reviewed" and not r.reviewed:
                continue
            if q and q not in f"{r.id} {r.name} {r.kind} {r.path}".lower():
                continue
            out.append(r)
        return out

    def refresh_table(self, keep=None):
        table = self.query_one("#table", DataTable)
        table.clear()
        rows = self.visible()
        for r in rows:
            table.add_row(status_cell(r), r.id, r.name, key=r.id)
        you = sum(len(r.to_answer) for r in self.rules)
        unrev = sum(1 for r in self.rules if not r.reviewed and r.kind != "shared")
        agent = sum(bool(r.needs_agent) for r in self.rules)
        scope = f"{self.sweep.name}'s rules · " if self.sweep else ""
        if self.missing:
            scope += f"{len(self.missing)} not drafted · "
        self.sub_title = (f"{scope}{FILTERS[self.filter]} · {you} open rulings · {unrev} unreviewed · "
                          f"{agent} for the agent · signing as {self.by}")
        ids = [r.id for r in rows]
        if keep in ids:
            table.move_cursor(row=ids.index(keep))
        if rows:
            self.show(rows[ids.index(keep)] if keep in ids else rows[0])
        else:
            self.current = None
            self.query_one("#detail").remove_children()

    def show(self, rule, focus=None):
        self.current = rule
        detail = self.query_one("#detail", VerticalScroll)
        detail.remove_children()
        widgets = [Static(rule_header(rule), classes="header")]
        if rule.rulings:
            order = {"open": 0, "answered": 1, "decided": 2}
            widgets.append(Static("RULINGS", classes="section"))
            widgets += [ruling_card(rule, r) for r in sorted(rule.rulings, key=lambda r: order[r.state])]
        if rule.clauses:
            widgets.append(Static(f"CLAUSES ({sum(c.encoded for c in rule.clauses)} of "
                                  f"{len(rule.clauses)} encoded)", classes="section"))
            widgets += [clause_card(rule, c) for c in rule.clauses]
        if rule.situations:
            wrong = sum(s.diverges for s in rule.situations)
            widgets.append(Static(f"SITUATIONS ({len(rule.situations)}, {wrong} where the app "
                                  f"differs)", classes="section"))
            widgets += [situation_card(s) for s in rule.situations]
        self.pending_focus = focus
        detail.mount_all(widgets)
        detail.scroll_home(animate=False)

    def _focus_card(self, match):
        for card in self.query(Card):
            if match(card):
                card.focus()
                card.scroll_visible(top=True, animate=False)
                return

    def check_action(self, action, parameters):
        return action == "quit" or not isinstance(self.screen, ModalScreen)

    def on_data_table_row_selected(self, event):
        self._step_card(1)

    def on_data_table_row_highlighted(self, event):
        if event.cursor_row != event.data_table.cursor_row:   # stale: the table was rebuilt since
            return
        rule = next((r for r in self.rules if r.id == event.row_key.value), None)
        if rule and rule is not self.current:
            self.show(rule)

    def on_input_changed(self, event):
        if event.input.id == "search":
            self.query_text = event.value
            self.refresh_table(self.current.id if self.current else None)

    def on_input_submitted(self, event):
        if event.input.id == "search":
            self.query_one("#table").focus()

    # actions

    def focused_card(self):
        return self.focused if isinstance(self.focused, Card) else None

    def action_search(self):
        self.query_one("#search", Input).focus()

    def action_cycle_filter(self):
        self.filter = (self.filter + 1) % len(FILTERS)
        self.refresh_table(self.current.id if self.current else None)

    def action_next(self):
        """The next thing that needs you: an open ruling first, then a rule to review."""
        pushed = False
        if self.current:
            card = self.focused_card()
            here = (self.current.id, card.kind if card else None, card.target.id if card else None)
            if not self.history or self.history[-1] != here:
                self.history.append(here)
                pushed = True
        todo = [r for r in self.rules if r.to_answer] + \
               [r for r in self.rules if r.needs_you and not r.to_answer]
        if not todo:
            self.notify("Nothing waits for you. Press f for the agent queue.")
            return
        ids = [r.id for r in todo]
        at = ids.index(self.current.id) if self.current and self.current.id in ids else -1
        card = self.focused_card()
        # stay on this rule while it still has an open ruling after the focused one
        if self.current and self.current.to_answer:
            opens = self.current.to_answer
            if card and card.kind == "ruling" and card.target in opens:
                later = opens[opens.index(card.target) + 1:]
                if later:
                    self._focus_card(lambda c: c.target is later[0])
                    return
            elif not (card and card.kind == "ruling"):
                self._focus_card(lambda c: c.target is opens[0])
                return
        rule = todo[(at + 1) % len(todo)]
        left = self.current.to_answer if self.current and rule is not self.current else []
        if not left:
            return self._jump(rule)
        text = Text()
        text.append(f"{self.current.id} still has {len(left)} open ruling{'s' * (len(left) > 1)}:"
                    "\n\n", style="bold")
        for r in left:
            text.append(f"  • {r.id}: ", style="bold")
            text.append(one_line(r.data.get("question", "")) + "\n")
        text.append(f"\nMove on to {rule.id} anyway? They stay open, and n comes back to them "
                    "later.\n\n")
        text.append("y moves on · n or escape stays and goes to the first of them", style="dim")

        def done(yes):
            if yes:
                self._jump(rule)
            else:
                if pushed:
                    self.history.pop()
                self._focus_card(lambda c: c.target is left[0])
        self.push_screen(Confirm(text), done)

    def _jump(self, rule):
        if FILTERS[self.filter] not in ("needs you", "all") or rule not in self.visible():
            self.filter, self.query_text = 0, ""
            self.query_one("#search", Input).value = ""
        self.refresh_table(rule.id)
        opens = rule.to_answer
        self._focus_after(lambda c: c.target is opens[0] if opens else c.kind == "clause")

    def action_back(self):
        """Back to where n came from, answered or not: to look again, or change an answer."""
        if not self.history:
            self.notify("Nothing to go back to: p retraces the jumps n made.")
            return
        rule_id, kind, item_id = self.history.pop()
        rule = next((r for r in self.rules if r.id == rule_id), None)
        if rule is None:
            return
        self.current = rule                   # visible() keeps the current rule, whatever the filter
        self.refresh_table(rule.id)
        self.query_one("#table").focus()
        if kind:
            self._focus_after(lambda c: c.kind == kind and c.target.id == item_id)

    def _focus_after(self, match):
        """Focus the matching card among those show() is mounting, as it mounts."""
        self.pending_focus = match

    def focus_if_pending(self, card):
        if self.pending_focus and self.pending_focus(card):
            self.pending_focus = None
            card.focus()
            card.scroll_visible(top=True, animate=False)

    def action_focus_next_card(self):
        self._step_card(1)

    def action_focus_prev_card(self):
        self._step_card(-1)

    def _step_card(self, step):
        cards = list(self.query(Card))
        if not cards:
            return
        card = self.focused_card()
        i = cards.index(card) + step if card in cards else (0 if step > 0 else -1)
        target = cards[max(0, min(i, len(cards) - 1))]
        target.focus()
        target.scroll_visible(animate=False)

    def action_activate(self):
        card = self.focused_card()
        if card is None:
            if self.focused is self.query_one("#table"):
                self._step_card(1)
            return
        if card.kind == "ruling" and card.target.state != "decided":
            self.answer(card.target)
        else:
            self.action_edit()

    def answer(self, r):
        def done(result):
            if result is None:
                return
            kind, value = result
            if kind == "flag":
                self.flag(self.current, r)
                return
            self.save(lambda: rf.set_answer(r.path, r.id, value),
                      f"{r.id}: answer saved — it now waits for the agent pass"
                      if value.strip() else f"{r.id}: reopened",
                      focus=lambda c: c.kind == "ruling" and c.target.id == r.id)

        if not r.data.get("options"):
            return self.answer_in_words(r, done)
        self.push_screen(Choose(r, can_flag=self.current.kind != "shared"), done)

    def answer_in_words(self, r, done):
        """A ruling without options can only be answered in words."""
        d = r.data
        body = Text(one_line(d.get("context", "")), style="dim")
        self.push_screen(Ask(one_line(d.get("question", r.id)), body,
                             [("your answer; empty reopens the ruling",
                               one_line(d.get("answer") or ""))]),
                         lambda v: done(None if v is None else ("answer", v[0])))

    def action_review(self):
        rule = self.current
        if not rule or rule.kind in ("shared", "error"):
            return
        if rule.reviewed:
            def undo(yes):
                if yes:
                    self.save(lambda: rf.set_reviewed(rule.path, None), f"{rule.id}: review withdrawn")
            self.push_screen(Confirm(Text(f"Withdraw the review of {rule.id}? (y/n)")), undo)
            return
        text = Text()
        text.append(f"Mark {rule.id} {rule.name} reviewed by {self.by}?\n\n", style="bold")
        text.append("That says you read every clause against the page and the effects match it.\n")
        if n := len(rule.rulings_in("open")):
            text.append(f"\n{n} ruling{'s' * (n > 1)} still open: they stay open.\n", style="yellow")
        if not (rule.data.get("source") or {}).get("hash"):
            text.append("The page has no hash yet, so a later change to it will not show.\n",
                        style="dim")
        text.append("\n(y/n)", style="dim")

        def done(yes):
            if yes:
                self.save(lambda: rf.set_reviewed(rule.path, self.by), f"{rule.id}: reviewed")
        self.push_screen(Confirm(text), done)

    def action_flag(self):
        card = self.focused_card()
        self.flag(self.current, card.target if card and card.kind in ("clause", "ruling") else None)

    def flag(self, rule, item=None):
        """Send the rule back to the agent, about `item` (a clause or ruling) if given."""
        if not rule or rule.kind == "error":
            return
        if rule.kind == "shared":
            self.notify("A shared ruling has no rule file to flag: write your objection as its "
                        "answer (enter), the agent reads it.", timeout=8)
            return
        ap = rule.agent_pass or {}
        about = list(map(str, ap.get("about") or []))
        if item is not None and item.id not in about:
            about.append(item.id)
        kind = "ruling" if isinstance(item, rf.Ruling) else "clause"
        body = Text()
        body.append("What is wrong, and what should the agent do? The note is what it reads "
                    "first: e.g. \"option b misreads the page, the SF only halves; redo the "
                    "options\".\n", style="dim")
        body.append("About: clause and ruling ids, comma-separated, prefilled with the focused "
                    "one; empty for the whole rule. An empty note removes the flag.\n", style="dim")
        body.append("Then run `make rules-agent` to start the pass.", style="dim")

        def done(values):
            if values is None:
                return
            note, ids = values[0].strip(), [x.strip() for x in values[1].split(",") if x.strip()]
            if not note:
                if ap:
                    self.save(lambda: rf.clear_agent_pass(rule.path), f"{rule.id}: flag removed")
                return
            known = {c.id for c in rule.clauses} | {r.id for r in rule.rulings}
            if unknown := [x for x in ids if x not in known]:
                self.notify(f"No clause or ruling {', '.join(unknown)} in {rule.id}",
                            severity="error")
                return
            self.save(lambda: rf.set_agent_pass(rule.path, self.by, note, ids),
                      f"{rule.id}: sent back to the agent — `make rules-agent` starts the pass",
                      focus=(lambda c: c.kind == kind and c.target.id == item.id)
                      if item is not None else None)

        self.push_screen(Ask(f"Send {rule.id} {rule.name} back to the agent", body,
                             [("what is wrong / what to do", one_line(ap.get("note", ""))),
                              ("about (optional)", ", ".join(about))]), done)

    def action_edit(self):
        card = self.focused_card()
        if card:
            path, line = card.path, card.line
        elif self.current:
            path, line = self.current.path, 1
        else:
            return
        with self.suspend():
            subprocess.run(editor_command(rf.HERE / path, line))
        self.after_write("reloaded after the edit")

    def action_open_page(self):
        url = ((self.current.data.get("source") or {}).get("url")) if self.current else None
        if url:
            webbrowser.open(url)

    # writing

    def save(self, edit, message, focus=None):
        try:
            edit()
        except rf.EditRefused as e:
            self.notify(str(e), severity="error", timeout=10)
            return
        self.after_write(message, focus)

    def after_write(self, message, focus=None):
        err = regenerate_index()
        self.reload()
        if focus:
            self._focus_after(focus)
        if err:
            self.notify(f"RULINGS.md not regenerated: {err}", severity="warning", timeout=10)
        else:
            self.notify(message)


# --- the agent queue, as text -----------------------------------------------------------------

def print_queue():
    rules = rf.load()
    flagged = [r for r in rules if r.agent_pass]
    answered = [x for r in rules for x in r.rulings_in("answered")]
    print(f"Agent queue: {len(flagged)} rule(s) flagged, {len(answered)} answered ruling(s) to "
          f"process.\n")
    for r in flagged:
        ap = r.agent_pass
        req = ap.get("requested") or {}
        scope = f" [{', '.join(map(str, ap['about']))}]" if ap.get("about") else ""
        print(f"- flagged  {r.path}  {r.id} {r.name}{scope} — {req.get('by')}, {req.get('date')}")
        print(f"           {one_line(ap.get('note', ''))}")
    for x in answered:
        print(f"- answered {x.path}:{x.line}  {x.owner} · {x.id} — {one_line(x.data['answer'])}")
    if not flagged and not answered:
        print("Nothing to do.")


def print_sweep(sweep):
    rules = rf.load()
    mine = [r for r in sweep.of(rules) if r.kind != "shared"]
    done = sum(1 for r in mine if r.reviewed and not r.needs_you)
    missing = sweep.missing(rules)
    print(f"{sweep.name}: {len(mine) + len(missing)} rules, {done} reviewed with nothing open, "
          f"{len(missing)} not drafted.\n")
    for r in sorted(mine, key=lambda r: (bool(r.reviewed and not r.needs_you), str(r.path))):
        todo = ", ".join(r.needs_you + r.needs_agent) or "done"
        print(f"  {r.id:<30} {r.name[:34]:<34} {todo:<28} {sweep.wanted.get(r.id, '')}")
    for rule_id, why in missing:
        print(f"  {rule_id:<30} {'':<34} {'not drafted':<28} {why}")
    if sweep.skipped:
        print(f"\nSkipped: {', '.join(sweep.skipped)} (sweeps/{sweep.name.lower()}.yaml says why).")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--by", help="GitHub handle to sign reviews and flags with")
    p.add_argument("--queue", action="store_true", help="print what waits for an agent and exit")
    p.add_argument("--sweep", help="only the rules that affect one hero: a file in sweeps/")
    p.add_argument("--list", action="store_true", help="with --sweep: print its rules and exit")
    args = p.parse_args()
    if args.queue:
        print_queue()
        return
    try:
        sweep = rf.load_sweep(args.sweep) if args.sweep else None
    except FileNotFoundError as e:
        sys.exit(str(e))
    if args.list:
        if not sweep:
            sys.exit("--list needs --sweep")
        print_sweep(sweep)
        return
    Review(reviewer(args.by), sweep).run()


if __name__ == "__main__":
    main()
