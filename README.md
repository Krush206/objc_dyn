# objc_dyn

An object-oriented shell for classic GNU libobjc (`/usr/local/include/objc`
headers, `/usr/local/GNUstep/Local/Library/Libraries/libobjc.so.1` runtime),
written to be driven by LLMs.

`llmsh` is a message gateway, not a text shell: an LLM never writes command
strings. It sends JSON messages over stdin (one per line) and reads one JSON
reply per line. Because there is no string re-parsing stage, quoting,
escaping and injection pass through the whole design unheard.

## Build

	make

Links against the classic GNUstep libobjc, which provides `objc_next_class`,
`sel_get_uid`, `class_create_instance`, `objc_msg_lookup` and
`__objc_resolve_class_links` natively. `class_get_class_name` is a static
inline in `objc-api.h`.

## Protocol (`llmsh/1`)

Request — one JSON object per stdin line:

	{"id": "1", "receiver": "$shell", "selector": "fileAt:",
	 "arguments": ["/etc/hostname"]}

Reply — one JSON object per stdout line:

	{"id": "1", "ok": true, "ref": "$file:/etc/hostname", "result": {...}}
	{"id": "1", "ok": false, "error": "receiver not found"}

Receivers are registry names: `$shell`, `$file:<path>`, `$proc:<pid>`,
`$var:<name>`, `$inst:<n>`. Every object reports its own interface through
`describeSystem:` — the full tool catalog, registered objects, user-defined
classes and the runtime class list. That catalog is the tool schema an LLM
reads on session start.

## Tools

`$shell`: `describeSystem:`, `describeObject:`, `listObjects:`,
`getVariable:`, `setVariable:`, `fileAt:`, `listDirectory:`,
`runCommand:`, `sendTo:`, `pipeline:`, `defineClass:`, `defineMethod:`,
`newInstanceOfClass:`, `history:`, `quit:`.

`LLMFile`: `children:`, `contents:`. `LLMProcess`: `output:`,
`errorOutput:`, `exitCode:`, `pid:`. `LLMVariable` and `LLMResult`:
`value:`.

Dispatch is gated through the tool table in `llm.m`; selectors outside the
catalog (or outside a user class's defined methods) are refused with
`"no such method"`. `runCommand:` uses `execvp` directly — no shell, no
metacharacters.

## Declaring classes and methods at runtime

The original goal of this project, achieved without a compiler: method
bodies are JSON programs — arrays of message sends — interpreted by the
shell's gateway. Within a body, `$self` is the receiving instance and
`$arg:0` … are its arguments.

	{"id":"a","receiver":"$shell","selector":"defineClass:","arguments":["Greet","Object"]}
	{"id":"b","receiver":"$shell","selector":"defineMethod:","arguments":["Greet","say:",
	 [{"receiver":"$shell","selector":"runCommand:","arguments":["echo","hi from","$arg:0"]}]]}
	{"id":"c","receiver":"$shell","selector":"newInstanceOfClass:","arguments":["Greet"]}
	{"id":"d","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","say:","there"]}

## Files

- `json.h`, `json.m` — JSON parser and compact writer (no dependencies)
- `llm.h` — interfaces: shell, registry, tool table, object classes
- `llm.m` — gateway dispatch, interpreter, protocol loop, `$shell` tools
- `llmobj.m` — `LLMResult`, `LLMFile`, `LLMProcess`, `LLMVariable`, `LLMInstance`

## Known limits

- `runCommand:` blocks and has no timeout; output is capped at 256 KiB.
- User methods are interpreted programs, not compiled IMPS. Wiring real
  `IMP`s would need libffi or `class_addMethods`-style runtime support.
- User classes are shapes (`super` is recorded, not compiled); instances
  keep state through shell variables for now.
- `listDirectory:` of a large directory is not truncated.
