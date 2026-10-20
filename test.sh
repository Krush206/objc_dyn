#!/bin/sh
# test.sh — end-to-end protocol tests for llmsh.
#
# Each session pipes a JSONL transcript through the shell and diffs
# the normalized replies against the expected output. Volatile
# fields (pids, sizes, mtimes, the temporary directory) are
# normalized before diffing. A sixth session greps the large
# describeSystem:/history: replies.

LLMSH=${LLMSH:-./llmsh}
fails=0
checks=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

[ -x "$LLMSH" ] || { echo "no $LLMSH; run make first"; exit 2; }

# fixtures with fixed metadata
printf 'hello world' > "$TMP/hello.txt"
: > "$TMP/empty.txt"
mkdir "$TMP/sub" "$TMP/sub2"
printf 'inner' > "$TMP/sub/inner.txt"
chmod 644 "$TMP/hello.txt" "$TMP/empty.txt" "$TMP/sub/inner.txt"
chmod 755 "$TMP/sub" "$TMP/sub2"
touch -d '@1000000000' "$TMP/hello.txt" "$TMP/empty.txt" \
	"$TMP/sub" "$TMP/sub2" "$TMP/sub/inner.txt" 2>/dev/null

normalize()
{
	sed -e "s|$TMP|__TMP__|g" \
	    -e 's/"pid":[0-9][0-9]*/"pid":N/g' \
	    -e 's/\$proc:[0-9][0-9]*/$proc:N/g' \
	    -e 's/"size":[0-9][0-9]*/"size":N/g' \
	    -e 's/"mtime":[0-9][0-9]*/"mtime":N/g'
}

ok()
{
	checks=$((checks+1))
	echo "PASS $1"
}

bad()
{
	checks=$((checks+1))
	fails=$((fails+1))
	echo "FAIL $1"
}

# session NAME — run NAME.in and diff against NAME.exp
session()
{
	name=$1

	"$LLMSH" < "$TMP/$name.in" | normalize > "$TMP/$name.got"
	checks=$((checks+1))
	if diff -u "$TMP/$name.exp" "$TMP/$name.got" > "$TMP/$name.diff"
	then
		echo "PASS $name"
	else
		fails=$((fails+1))
		echo "FAIL $name"
		sed 's/^/    /' "$TMP/$name.diff"
	fi
}

# expand NAME — turn the heredoc on stdin into NAME.in, __TMP__ filled
expand()
{
	sed "s|__TMP__|$TMP|g" > "$TMP/$1.in"
}

# --- basic protocol and variables -------------------------------

cat <<'EOF' | expand basic
{"id":"1","receiver":"$shell","selector":"setVariable:","arguments":["greeting","hello world"]}
{"id":"2","receiver":"$shell","selector":"getVariable:","arguments":["greeting"]}
{"id":"3","receiver":"$shell","selector":"sendTo:","arguments":["$var:greeting","value:"]}
{"id":"4","receiver":"$shell","selector":"setVariable:","arguments":["count",42]}
{"id":"5","receiver":"$shell","selector":"setVariable:","arguments":["flag",true]}
{"id":"6","receiver":"$shell","selector":"setVariable:","arguments":["list",[1,2,3]]}
{"id":"7","receiver":"$shell","selector":"setVariable:","arguments":["greeting","updated"]}
{"id":"8","receiver":"$shell","selector":"getVariable:","arguments":["greeting"]}
{"id":"9","receiver":"$shell","selector":"getVariable:","arguments":["missing"]}
{"id":"10","receiver":"$shell","selector":"listObjects:"}
{"id":"11","receiver":"$shell","selector":"describeObject:","arguments":["$shell"]}
{"id":"12","receiver":"$shell","selector":"quit:"}
EOF

cat <<'EOF' > "$TMP/basic.exp"
{"id":"1","ok":true,"ref":"$var:greeting","result":{"kind":"LLMVariable","name":"greeting","value":"hello world"}}
{"id":"2","ok":true,"ref":"$var:greeting","result":{"kind":"LLMVariable","name":"greeting","value":"hello world"}}
{"id":"3","ok":true,"result":"hello world"}
{"id":"4","ok":true,"ref":"$var:count","result":{"kind":"LLMVariable","name":"count","value":42}}
{"id":"5","ok":true,"ref":"$var:flag","result":{"kind":"LLMVariable","name":"flag","value":true}}
{"id":"6","ok":true,"ref":"$var:list","result":{"kind":"LLMVariable","name":"list","value":[1,2,3]}}
{"id":"7","ok":true,"ref":"$var:greeting","result":{"kind":"LLMVariable","name":"greeting","value":"updated"}}
{"id":"8","ok":true,"ref":"$var:greeting","result":{"kind":"LLMVariable","name":"greeting","value":"updated"}}
{"id":"9","ok":false,"error":"not found"}
{"id":"10","ok":true,"result":["$shell","$var:greeting","$var:count","$var:flag","$var:list"]}
{"id":"11","ok":true,"result":{"name":"$shell","kind":"$shell","ref":"$shell","object":{"kind":"$shell","protocol":"llmsh/1"}}}
{"id":"12","ok":true,"result":null}
EOF

# --- errors and gating --------------------------------------------

cat <<'EOF' | expand errors
# comment line

not json at all
{"receiver":"$shell","selector":"listObjects:"}
{"id":"e1","receiver":"$nobody","selector":"listObjects:"}
{"id":"e2","receiver":"$shell","selector":"noSuchTool:"}
{"id":"e3","receiver":"$shell","selector":"fileAt:","arguments":[123]}
{"id":"e4","receiver":"$shell","selector":"fileAt:","arguments":["__TMP__/absent"]}
{"id":"e5","receiver":"$shell","selector":"listDirectory:","arguments":["__TMP__/absentdir"]}
{"id":"e6","receiver":"$shell","selector":"runCommand:"}
{"id":"e7","receiver":"$shell","selector":"pipeline:","arguments":["nope"]}
{"id":"e8","receiver":"$shell","selector":"pipeline:","arguments":[["bogus"]]}
{"id":"e9","receiver":"$shell","selector":"getVariable:"}
	{"id":"e10","receiver":"$shell","selector":"defineMethod:","arguments":["X","y:","str"]}
{"id":"e11","receiver":"$shell"}
EOF
cat <<'EOF' > "$TMP/errors.exp"
{"ok":false,"error":"unexpected character"}
{"ok":true,"result":["$shell"]}
{"id":"e1","ok":false,"error":"receiver not found"}
{"id":"e2","ok":false,"error":"no such method"}
{"id":"e3","ok":false,"error":"bad arguments"}
{"id":"e4","ok":false,"error":"not found"}
{"id":"e5","ok":false,"error":"not found"}
{"id":"e6","ok":false,"error":"bad arguments"}
{"id":"e7","ok":false,"error":"bad arguments"}
{"id":"e8","ok":false,"error":"bad message"}
{"id":"e9","ok":false,"error":"bad arguments"}
{"id":"e10","ok":false,"error":"bad arguments"}
{"id":"e11","ok":false,"error":"bad message"}
EOF

# --- files ---------------------------------------------------------

cat <<'EOF' | expand files
{"id":"f1","receiver":"$shell","selector":"fileAt:","arguments":["__TMP__/hello.txt"]}
{"id":"f2","receiver":"$shell","selector":"fileAt:","arguments":["__TMP__/hello.txt"]}
{"id":"f3","receiver":"$shell","selector":"sendTo:","arguments":["$file:__TMP__/hello.txt","contents:"]}
{"id":"f4","receiver":"$shell","selector":"sendTo:","arguments":["$file:__TMP__/hello.txt","children:"]}
{"id":"f5","receiver":"$shell","selector":"fileAt:","arguments":["__TMP__/sub"]}
{"id":"f6","receiver":"$shell","selector":"sendTo:","arguments":["$file:__TMP__/sub","children:"]}
{"id":"f7","receiver":"$shell","selector":"listDirectory:","arguments":["__TMP__/sub"]}
{"id":"f8","receiver":"$shell","selector":"listDirectory:","arguments":["__TMP__/sub2"]}
{"id":"f9","receiver":"$shell","selector":"fileAt:","arguments":["__TMP__/empty.txt"]}
{"id":"f10","receiver":"$shell","selector":"sendTo:","arguments":["$file:__TMP__/empty.txt","contents:"]}
{"id":"f11","receiver":"$shell","selector":"describeObject:","arguments":["$file:__TMP__/hello.txt"]}
EOF

cat <<'EOF' > "$TMP/files.exp"
{"id":"f1","ok":true,"ref":"$file:__TMP__/hello.txt","result":{"kind":"LLMFile","path":"__TMP__/hello.txt","name":"hello.txt","isDirectory":false,"size":N,"mtime":N,"permissions":"644"}}
{"id":"f2","ok":true,"ref":"$file:__TMP__/hello.txt","result":{"kind":"LLMFile","path":"__TMP__/hello.txt","name":"hello.txt","isDirectory":false,"size":N,"mtime":N,"permissions":"644"}}
{"id":"f3","ok":true,"result":"hello world"}
{"id":"f4","ok":true,"result":[]}
{"id":"f5","ok":true,"ref":"$file:__TMP__/sub","result":{"kind":"LLMFile","path":"__TMP__/sub","name":"sub","isDirectory":true,"size":N,"mtime":N,"permissions":"755"}}
{"id":"f6","ok":true,"result":[{"name":"inner.txt","path":"__TMP__/sub/inner.txt","isDirectory":false,"size":N}]}
{"id":"f7","ok":true,"result":[{"name":"inner.txt","path":"__TMP__/sub/inner.txt","isDirectory":false,"size":N}]}
{"id":"f8","ok":true,"result":[]}
{"id":"f9","ok":true,"ref":"$file:__TMP__/empty.txt","result":{"kind":"LLMFile","path":"__TMP__/empty.txt","name":"empty.txt","isDirectory":false,"size":N,"mtime":N,"permissions":"644"}}
{"id":"f10","ok":true,"result":""}
{"id":"f11","ok":true,"result":{"name":"$file:__TMP__/hello.txt","kind":"LLMFile","ref":"$file:__TMP__/hello.txt","object":{"kind":"LLMFile","path":"__TMP__/hello.txt","name":"hello.txt","isDirectory":false,"size":N,"mtime":N,"permissions":"644"}}}
EOF

# --- processes ------------------------------------------------------

cat <<'EOF' | expand procs
{"id":"p1","receiver":"$shell","selector":"runCommand:","arguments":["echo","one","two"]}
{"id":"p2","receiver":"$shell","selector":"runCommand:","arguments":["sh","-c","echo err 1>&2"]}
{"id":"p3","receiver":"$shell","selector":"runCommand:","arguments":["/no/such/binary"]}
{"id":"p4","receiver":"$shell","selector":"runCommand:","arguments":["false"]}
{"id":"p5","receiver":"$shell","selector":"runCommand:","arguments":["printf","%d-%s",7,"x"]}
{"id":"p6","receiver":"$shell","selector":"runCommand:","arguments":["echo",5,true]}
EOF

cat <<'EOF' > "$TMP/procs.exp"
{"id":"p1","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"echo","arguments":["echo","one","two"],"exitCode":0,"output":"one two\n","errorOutput":""}}
{"id":"p2","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"sh","arguments":["sh","-c","echo err 1>&2"],"exitCode":0,"output":"","errorOutput":"err\n"}}
{"id":"p3","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"/no/such/binary","arguments":["/no/such/binary"],"exitCode":127,"output":"","errorOutput":""}}
{"id":"p4","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"false","arguments":["false"],"exitCode":1,"output":"","errorOutput":""}}
{"id":"p5","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"printf","arguments":["printf","%d-%s","7","x"],"exitCode":0,"output":"7-x","errorOutput":""}}
{"id":"p6","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"echo","arguments":["echo","5","true"],"exitCode":0,"output":"5 true\n","errorOutput":""}}
EOF

# --- dynamic classes and methods ------------------------------------

cat <<'EOF' | expand dyn
{"id":"d1","receiver":"$shell","selector":"defineClass:","arguments":["Counter","Object"]}
{"id":"d2","receiver":"$shell","selector":"defineClass:","arguments":["Counter","Object"]}
{"id":"d3","receiver":"$shell","selector":"defineMethod:","arguments":["Nope","bump:",[{"receiver":"$shell","selector":"listObjects:"}]]}
{"id":"d4","receiver":"$shell","selector":"defineMethod:","arguments":["Counter","bump:",["bad"]]}
{"id":"d5","receiver":"$shell","selector":"defineMethod:","arguments":["Counter","bump:",[{"receiver":"$shell","selector":"listObjects:"}]]}
{"id":"d6","receiver":"$shell","selector":"newInstanceOfClass:","arguments":["Counter"]}
{"id":"d7","receiver":"$shell","selector":"newInstanceOfClass:","arguments":["Counter"]}
{"id":"d8","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","bump:"]}
{"id":"d9","receiver":"$shell","selector":"defineMethod:","arguments":["Counter","loop:",[{"receiver":"$self","selector":"loop:"}]]}
{"id":"d10","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","loop:"]}
{"id":"d11","receiver":"$shell","selector":"defineMethod:","arguments":["Counter","bump:",[{"receiver":"$shell","selector":"describeObject:","arguments":["$self"]}]]}
{"id":"d12","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","bump:"]}
{"id":"d13","receiver":"$shell","selector":"defineMethod:","arguments":["Counter","say:",[{"receiver":"$shell","selector":"runCommand:","arguments":["echo","hi","$arg:0"]}]]}
{"id":"d14","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","say:","there"]}
{"id":"d15","receiver":"$shell","selector":"defineMethod:","arguments":["Counter","call:",[{"receiver":"$arg:0","selector":"value:"}]]}
{"id":"d16","receiver":"$shell","selector":"setVariable:","arguments":["v","x"]}
{"id":"d17","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","call:","$var:v"]}
{"id":"d18","receiver":"$shell","selector":"sendTo:","arguments":["$inst:0","nope:"]}
EOF

cat <<'EOF' > "$TMP/dyn.exp"
{"id":"d1","ok":true,"result":{"class":"Counter","super":"Object"}}
{"id":"d2","ok":false,"error":"already defined"}
{"id":"d3","ok":false,"error":"not found"}
{"id":"d4","ok":false,"error":"bad message"}
{"id":"d5","ok":true,"result":{"class":"Counter","method":"bump:"}}
{"id":"d6","ok":true,"ref":"$inst:0","result":{"kind":"LLMInstance","class":"Counter","methods":["bump:"]}}
{"id":"d7","ok":true,"ref":"$inst:1","result":{"kind":"LLMInstance","class":"Counter","methods":["bump:"]}}
{"id":"d8","ok":true,"result":["$shell","$inst:0","$inst:1"]}
{"id":"d9","ok":true,"result":{"class":"Counter","method":"loop:"}}
{"id":"d10","ok":false,"error":"message nesting too deep"}
{"id":"d11","ok":true,"result":{"class":"Counter","method":"bump:"}}
{"id":"d12","ok":true,"result":{"name":"$inst:0","kind":"LLMInstance","ref":"$inst:0","object":{"kind":"LLMInstance","class":"Counter","methods":["bump:","loop:"]},"methods":["bump:","loop:"]}}
{"id":"d13","ok":true,"result":{"class":"Counter","method":"say:"}}
{"id":"d14","ok":true,"ref":"$proc:N","result":{"kind":"LLMProcess","pid":N,"command":"echo","arguments":["echo","hi","there"],"exitCode":0,"output":"hi there\n","errorOutput":""}}
{"id":"d15","ok":true,"result":{"class":"Counter","method":"call:"}}
{"id":"d16","ok":true,"ref":"$var:v","result":{"kind":"LLMVariable","name":"v","value":"x"}}
{"id":"d17","ok":true,"result":"x"}
{"id":"d18","ok":false,"error":"no such method"}
EOF

session basic
session errors
session files
session procs
session dyn

# --- describeSystem: and history: (grep, output too large to diff) --

cat <<'EOF' > "$TMP/grep.in"
{"id":"g1","receiver":"$shell","selector":"setVariable:","arguments":["a",1]}
{"id":"g2","receiver":"$shell","selector":"describeSystem:"}
{"id":"g3","receiver":"$shell","selector":"history:"}
EOF

"$LLMSH" < "$TMP/grep.in" > "$TMP/grep.got"
sysline=$(sed -n 2p "$TMP/grep.got")
hisline=$(sed -n 3p "$TMP/grep.got")

echo "$sysline" | grep -q '"protocol":"llmsh/1"' && ok "system protocol" || bad "system protocol"
echo "$sysline" | grep -q '"selector":"defineMethod:"' && ok "system tool catalog" || bad "system tool catalog"
echo "$sysline" | grep -q '"runtimeClasses":' && ok "system runtime classes" || bad "system runtime classes"
echo "$sysline" | grep -q '"Object"' && ok "system lists Object" || bad "system lists Object"
echo "$sysline" | grep -q '"\$shell"' && ok "system lists shell" || bad "system lists shell"
echo "$hisline" | grep -q '"id":"g1"' && ok "history records g1" || bad "history records g1"
echo "$hisline" | grep -q '"id":"g2"' && ok "history records g2" || bad "history records g2"

echo "$checks checks, $fails failed"
[ $fails -eq 0 ]
