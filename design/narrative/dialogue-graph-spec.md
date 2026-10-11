# Dialogue graph format

This document describes the format implemented by
`scripts/autoload/dialogue_manager.gd`, with `data/dialogue/keeper_intro.json`
as the working example.

## File structure

Store graphs as JSON files in `data/dialogue/`. The top-level object maps
unique node IDs directly to node objects. There is no `start` metadata field,
`nodes` wrapper, `lines` array, or `set` field.

A node ID named `start` is allowed: it is an ordinary node and the default
entry ID used by the caller API. Each node displays one `text` string;
chain nodes with `next` to display successive passages.

## Nodes and choices

| Field | Type | Meaning |
| --- | --- | --- |
| `speaker` | string | Speaker label; use `""` for narration. The runtime defaults an omitted label to `""`. |
| `text` | string | The passage displayed for this node. The runtime defaults omitted text to `""`. |
| `next` | node ID string or `null` | Linear-node destination. `null` ends dialogue when the player advances. |
| `choices` | nonempty array of choice objects | Choices offered after this passage; use instead of node-level `next`. |
| `set_flag` | object, optional | Flag-name/value assignments applied when the node is entered, before the line is shown. |

Author each node with either `next` or a nonempty `choices` array.
Write explicit string labels and text rather than relying on runtime coercion.

Each choice has:

| Field | Type | Meaning |
| --- | --- | --- |
| `text` | string | Choice label. |
| `next` | node ID string or `null` | Destination after selection; `null` ends dialogue immediately. |
| `set_flag` | object, optional | Assignments applied when this choice is selected, before entering its destination. |

Every non-null destination must exist in the same file. Use explicit
`"next": null` for termination. A terminal node still displays its passage;
a terminal choice ends after applying its assignments.

## Complete example

This abbreviated graph uses the reading-choice behavior in `keeper_intro.json`:

```json
{
  "logbook": {
    "speaker": "Keeper's Log",
    "text": "The ledger is open to Edith's last account.",
    "next": "reading"
  },
  "reading": {
    "speaker": "",
    "text": "What do you make of the answering light?",
    "choices": [
      {
        "text": "She was tired and seeing things.",
        "next": "skeptic_end",
        "set_flag": { "skeptic": true, "believer": false }
      },
      {
        "text": "Something was really out there.",
        "next": "believer_end",
        "set_flag": { "believer": true, "skeptic": false }
      }
    ]
  },
  "skeptic_end": {
    "speaker": "",
    "text": "You look for an ordinary explanation.",
    "next": null
  },
  "believer_end": {
    "speaker": "",
    "text": "You believe her account.",
    "next": null
  }
}
```

## Flags

`set_flag` is a dictionary, not a list of flag names. Each key is assigned
its supplied value through `GameState.set_flag(name, value)`. Values are
stored as supplied; the narrative flags here use JSON booleans.

Assignments overwrite previous values. Assigning `false` stores false; it
does not delete the key. Omitted keys keep their previous values. Node
assignments run on every visit, and choice assignments run on every selection.
Flags persist when GameState saves and loads; starting a new game clears them.

Both reading choices explicitly clear the opposite flag so rereading cannot
leave `believer` and `skeptic` true together. The logbook's second choice sets
`trusted_edith` true or false. Choosing to radio the mainland in the logbook
does not itself set `radioed_tom`; selecting either choice in the radio
conversation sets that flag.

The graph player does not evaluate conditions, filter choices by flags, or
interpret conditional destinations. Branch by offering choices or have
GDScript select an entry ID.

## Starting a graph

```gdscript
DialogueManager.start("res://data/dialogue/keeper_intro.json", "logbook")
```

`start(path, start_id = "start")` loads the graph and enters the requested
node. JSON key order does not choose the entry. The keeper graph has three
caller-selected entries: `logbook`, `radio`, and `door`.

Missing entry or destination IDs log an error and finish dialogue. The return
value of `start()` is not proof that the requested entry exists: it returns
true after loading a nonempty graph even if entering the requested node fails.

For endings, use the helper already present in GameState:

```gdscript
var entry := GameState.get_ending_entry()
if not entry.is_empty():
    DialogueManager.start("res://data/dialogue/endings.json", entry)
```

Exactly one of `believer` and `skeptic` must be true. Both or neither causes
the helper to report an error and return an empty string. Missing trust and
contact flags default to false. The helper selects an entry without mutating
flags or starting dialogue.

| Reading | `trusted_edith` | Base entry |
| --- | --- | --- |
| skeptic | false | `ending_skeptic_distrust` |
| skeptic | true | `ending_skeptic_trust` |
| believer | false | `ending_believer_distrust` |
| believer | true | `ending_believer_trust` |

When `radioed_tom` is true, append `_radioed_tom` to the base entry.
These eight routes represent four outcomes. The Tom variant changes one
epilogue passage within each outcome and rejoins its shared final node.
The JSON contains explicit routes; the graph player does not switch epilogues
automatically. The helper still needs a gameplay caller at the desired trigger.

## Validation

Run from the repository root:

```bash
python3 tests/validate_dialogue.py
```

The script checks every `data/dialogue/*.json` file for node structure,
referenced targets, and the presence of a terminal. It warns about nodes
unreachable from its known entries and files with no known entry.
Its known entries include `logbook`, `radio`, `door`, `start`, and the
eight ending entry IDs above. Add new caller-selected entries to
`KNOWN_ENTRIES` when adding content.

Each graph also prints a sorted, unique `flags set:` list from node and
choice `set_flag` dictionaries, including false assignments and assignments
on unreachable nodes. Graphs with no assignments print `flags set: (none)`.
This is an inventory of authored flag names, not a report of final flag values
or a flag-schema check.

Errors cause exit status 1; warnings alone do not fail validation.
The current checker does not prove that each entry or every route terminates,
reject cycles, enforce flag names/types, or fully validate field types.
Some malformed input can still raise an exception. Passing the checker is
not a substitute for testing the dialogue in Godot.

## Updating older drafts

Remove the old `nodes` wrapper and make its node map the top-level object.
Choose the entry in the GDScript `start()` call instead of JSON metadata.
Split `lines` passages into linked nodes with `text`, and replace `set`
with `set_flag` dictionaries on the node or choice where the assignment
should occur. Encode routing through explicit `next` links and choices.
