# SyntaxBuilderで構文を定義する

SyntaxBuilderは、字句やルールを組み合わせて、代入文・リスト・式などの構文を定義する仕組みです。
`Syntax { ... }`の中に、読む順序で要素を並べます。

一つの字句の内部は[TokenBuilder](TokenBuilder.md)、字句同士の組み合わせはSyntaxBuilderが担当します。
本書はInterpreterの`.v1`・`.v2`を対象にしています。既定のInterpreterは`.v2`です。

## まずは代入文を書いてみる

```swift
import Spellu

let assignment: Syntax = Syntax {
    Token(label: "name") {
        CharacterClass.range("a"..."z").repeat(1...)
    }
    "="
    Token(label: "number") {
        ASCII.digit.repeat(1...)
    }
    Optional { ";" }
}

let result = try "count = 123;".wholeMatch(
    trivia: [.space],
    syntax: assignment,
)
assert(result.parts.map(\.label) == ["name", "number"])
assert(result.parts.map(\.string) == ["count", "123"])
```

この構文は、名前、`=`、整数、あれば`;`を順に読みます。
`Token`と文字列リテラルの直前では、指定したtriviaを読み飛ばせます。
そのため`"count=123"`と`"count = 123;"`のどちらも受け付けます。

文字列リテラル`"="`は、ラベルを省略した`Token("=")`に相当します。
通常の`compact`出力では、このようなラベルなしの字句は省略され、
`label:`を付けた`name`と`number`のノードが残ります。

`wholeMatch`は入力全体との一致、`prefixMatch`は入力先頭からの部分一致です。
以下の例では、空白に関する例を除き、`trivia: []`で自動消費を無効にします。

## SyntaxBuilderに書けるもの

- `Token`、`Fragment`、`Word`：字句を読む要素。
- 文字列リテラル：固定文字列を読むTokenの省略形。
- `Sequence`、`AnyOf`、`ChoiceOf`、`Optional`、`Repeat`、`List`、`Enclosure`、`Capture`。
- `$rule`などの`RuleReference`：名前を付けたルールへの参照。
- `Inline(syntax)`または`[SyntaxIR]`：あらかじめ用意した構文要素の展開。
- `Trivia`：現在の文法のtriviaを明示的に要求する要素。

`Syntax`そのものをブロックへ直接置く代わりに、`Inline`で中身を展開するか、
`@Rule`で名前を付けて参照します。
文字クラスや`TokenIR`を構文側へ直接置く場合は、`Token { ... }`で包みます。

## Sequence：複数の要素をひとまとまりにする

要素を単に並べても、順に照合されます。
`Sequence`は、複数要素を選択の一候補にしたり、まとめてラベルを付けたりするときに使います。
字句側にも同名の`Sequence`があります。
`Token { ... }`などの内部では字句パターンをまとめ、
構文側では次のように子の構文要素をまとめます。

```swift
let pair: Syntax = Syntax {
    Sequence(label: "pair") {
        Token(label: "key", "x")
        ":"
        Token(label: "value", "1")
    }
}

let result = try "x:1".wholeMatch(trivia: [], syntax: pair)
assert(result.parts.first?.label == "pair")
assert(result.parts.first?.parts.map(\.label) == ["key", "value"])
```

`Sequence(label:)`は、その部分の構文木をまとめるノードを作ります。
ラベルを省略したSequenceには補助ラベルが付き、`compact`出力では通常畳み込まれます。
Sequenceで囲んでも、Token間のtriviaの扱いは変わりません。

## AnyOf：成功する候補を優先値で選ぶ

構文側の`AnyOf`は、**成功した候補のうち優先値が最も高いもの**を選びます。
候補内の要素がすべて成功した時点で、その候補は成功です。

```swift
let selected: Syntax = Syntax {
    AnyOf {
        Token(label: "ordinary", "if")
        Branch(.high) {
            Token(label: "preferred", "if")
        }
    }
}

let result = try "if".wholeMatch(trivia: [], syntax: selected)
assert(result.parts.first?.label == "preferred")
```

優先値を省略した候補は`.default`です。現在の定義は次のとおりです。

- `.low`と`.default`：0。
- `.middle`：50。
- `.high`：100。
- 整数での指定：0〜100。範囲外は文法検査でエラーになります。

高い候補が失敗した場合は、AnyOfの開始位置から次の候補を試します。
成功した優先値より低い候補は選択対象になりません。
内側のAnyOfの優先値が、外側のBranchへ加算されることもありません。

### 複数要素の候補にはBranchやSequenceを使う

```swift
let statement: Syntax = Syntax {
    AnyOf {
        Branch(.high) {
            "let"
            Token(label: "name", "x")
        }
        Sequence {
            "use"
            Token(label: "name", "x")
        }
    }
}

let result = try "let x".wholeMatch(trivia: [.space], syntax: statement)
assert(result.parts.first?.string == "x")
```

AnyOf直下の各要素が一候補です。`"let"`と`Token(...)`をまとめずに並べると、
二つの独立した候補になります。

一つの要素なら、`Token(...).precedence(.high)`の形でもBranchを作れます。
ルール参照にも`$rule.precedence(.high)`を使えます。

### 同じ最高順位で複数成功すると曖昧性エラー

```swift
let ambiguous: Syntax = Syntax {
    AnyOf {
        "a"
        "ab"
    }
}

do {
    _ = try "ab".prefixMatch(trivia: [], syntax: ambiguous)
    assertionFailure("曖昧性エラーになるはずです")
}
catch let error as SpelluError {
    assert(error == .ambiguousChoice(precedence: 0))
}
```

両方とも既定の優先値0で成功するため、長い`"ab"`を自動選択しません。
最高順位での複数成功は、結果の長さやラベルが違っても曖昧と判定します。
候補が同じ内容であっても、二つ成功すれば曖昧です。

このエラーは、`Optional`で省略したり、別の候補へ切り替えたりして回復する通常の不一致とは区別されます。
曖昧さを許す意図がなければ、候補を分離するか、Branchの優先値で解決してください。

## ChoiceOf：最初に成功した候補を選ぶ

記述順に候補を試したい場合は`ChoiceOf`を使います。
複数候補が成功可能でも、最初の成功を選び、同順位の曖昧性判定は行いません。

```swift
let ordered: Syntax = Syntax {
    ChoiceOf {
        Token(label: "first", "a")
        Token(label: "second", "ab")
    }
}

let result = try "ab".prefixMatch(trivia: [], syntax: ordered)
assert(result.string == "a")
assert(result.parts.first?.label == "first")
```

複数要素の一候補はSequenceでまとめます。
ChoiceOfの直下に`Branch`を置いて優先値を指定する形式はありません。

### 選択が成功した後は、外側の失敗で選び直さない

```swift
let syntax: Syntax = Syntax {
    ChoiceOf {
        "ab"
        "a"
    }
    "b"
}

let result = try? "ab".wholeMatch(trivia: [], syntax: syntax)
assert(result?.string == nil)
```

ChoiceOfが`"ab"`で成功した後、外側の`"b"`が失敗します。
ここで候補を`"a"`へ選び直すことはありません。優先値付きAnyOfも、選択確定後は同じです。

後続までを含めて候補の成否を決めたい場合は、必要な後続も候補へ含めます。
Token内のChoiceOfが、同じTokenの後続失敗時に戻れる仕様とは異なります。

## Optional：中身全体を省略可能にする

```swift
let syntax: Syntax = Syntax {
    "a"
    Optional {
        ":"
        Token(label: "value", "1")
    }
}

let result = try "a".wholeMatch(trivia: [], syntax: syntax)
assert(result.string == "a")
```

中身を一度試し、不一致になったらOptionalの開始位置へ戻して、省略した結果として成功します。
中身が途中まで読んでから失敗した場合も、Optional全体の読み取りを取り消します。

ただし、中身が一度成功した後、外側の要素が失敗しても省略し直しません。
例えば`Optional { "a" }`の後に`"a"`を置き、入力が`"a"`だけなら失敗します。

`Optional(Token("a"))`のように、一要素を引数で渡す形式もあります。
ルール参照には`$rule.optional()`も使えます。

省略時は`asis`出力に空の補助ノードが入ります。既定では`compact`出力で省略されます。
`nilLabel:`を指定すると、省略した位置に名前付きの空ノードを残せます。

## Repeat：構文のまとまりを繰り返す

```swift
let repeated: Syntax = Syntax {
    Repeat(1...3) {
        Token(label: "item", "a")
    }
}

let result = try "aaa".wholeMatch(trivia: [], syntax: repeated)
assert(result.parts.map(\.string) == ["a", "a", "a"])
```

一回分はブロックの中身全体です。`Repeat { ... }`と範囲を省略すると`0...`になります。
`0...`、`1...`、`2...4`、`2..<4`、`3...3`など、TokenBuilderと同じ回数表記を使えます。
構文の反復では、各Tokenの前でtriviaを読めます。

### eager：可能な限り読む（既定値）

`behavior: .eager`は、本体が一致しなくなるか指定上限に達するまで読みます。
途中で失敗した一回分は取り消しますが、成功した反復を後続のために減らすことはありません。

```swift
let maximum: Syntax = Syntax {
    Repeat(behavior: .eager) { "a" }
    "a"
}

let result = try? "aaa".wholeMatch(trivia: [], syntax: maximum)
assert(result?.string == nil)
```

この例では反復がすべての`a`を読んでしまい、後続が失敗します。
字句反復の`.eager`のように成功済み反復を短く戻す動作ではありません。

### reluctant：直後の要素が読める位置で止める

`behavior: .reluctant`は、最小回数を満たした後、直後の構文要素を先読みします。
その要素が成功する位置なら反復を終え、成功しなければ本体をもう一回読みます。
先読みそのものでは入力を消費しません。

```swift
let minimum: Syntax = Syntax {
    Repeat(behavior: .reluctant) { "a" }
    "a"
}

let result = try "aaa".prefixMatch(trivia: [], syntax: minimum)
assert(result.string == "a")
```

最初から後続の`"a"`を読めるため、反復は0回で終了します。
後続要素がない場所では、この方法で早く止めるための先読み対象もありません。

### 先読みするのは直後の一要素

```swift
let untilSuffix: Syntax = Syntax {
    Repeat(behavior: .reluctant) { Fragment("a") }
    Sequence {
        Fragment("a")
        Fragment("b")
    }
}

let result = try "aaab".wholeMatch(trivia: [], syntax: untilSuffix)
assert(result.string == "aaab")
```

この例では、後続のSequence全体を先読みし、`"ab"`が読める位置で止まります。
Sequenceを外して`"a"`と`"b"`を別々に並べると、先読み対象は`"a"`だけです。
最初の位置で止まった後、`"b"`が失敗しても反復を増やし直しません。

## Capture：後方参照の記録を一時的に変更する

`Token`や`Fragment`の`tag:`に名前を付けると、一致した入力文字列が記録されます。
`Fragment(tag: "name")`や`Token(tag: "name")`で同じ名前を参照できます。
参照はUnicode Scalar単位で大文字・小文字を区別せずに照合し、
未記録の名前の参照は一致に失敗します。空文字列も記録できます。

`Capture { ... }`の中では外側の記録を参照できます。同じ名前を記録すると、
内部では新しい値が使われます。Captureを抜けると、入力位置と構文木を保持したまま、
記録が進入前の状態に戻ります。

```swift
let scoped: Syntax = Syntax {
    Fragment(tag: "mark", "a")
    Capture {
        Fragment(tag: "mark")       // 外側の "a"
        Fragment(tag: "mark", "b")  // 内側で "b" に上書き
        Fragment(tag: "mark")       // 内側の "b"
    }
    Fragment(tag: "mark")           // 外側の "a" に戻る
}

let result = try "aabba".wholeMatch(trivia: [], syntax: scoped)
assert(result.string == "aabba")
```

Captureは入れ子にでき、失敗した選択肢や先読みでの記録は巻き戻されます。
tagの名前空間は文法ごとに分かれています。Capture自体は構文木にノードを追加せず、
本文のノードを返します。同じ文法のルール呼び出しでは、Captureで囲まない限り
記録は引き継がれます。

## List：区切り付きの並びを読む

```swift
let names: Syntax = Syntax {
    List(1..., lastSeparator: .deny) {
        Token(label: "name") {
            CharacterClass.range("a"..."z").repeat(1...)
        }
    } separator: {
        ","
    }
}

let result = try "alice,bob".wholeMatch(trivia: [], syntax: names)
assert(result.parts.map(\.string) == ["alice", "bob"])

let failure = try? "alice,".wholeMatch(trivia: [], syntax: names)
assert(failure?.string == nil)
```

`value`側が一つの値、`separator:`側が値同士の区切りです。
範囲は値の個数を指定します。省略時は`0...`です。

- `lastSeparator: .deny`：最後の値の後ろの区切りはListに含めません。
- `lastSeparator: .allow`：最後に区切りが一つあっても受け付けます。これが既定値です。

`.deny`で`"alice,"`をprefix matchすると、`"alice"`までを読み、`,`は残ります。
入力全体を受理するかを確認する例では`wholeMatch`を使ってください。
区切りも構文要素なので、ラベルを付ければ構文木へ残せます。

有限の個数上限を厳密に使う場合は、後述の現行実装の制限も参照してください。

## Enclosure：開始・終了の記号で囲む

```swift
let enclosed: Syntax = Syntax {
    Enclosure("[", "]") {
        Token(label: "item", "a")
    }
}

let result = try "[aa]".wholeMatch(trivia: [], syntax: enclosed)
assert(result.string == "[aa]")
```

開始記号、中身の0回以上の反復、終了記号を読みます。`"[]"`も受け付けます。
中身をちょうど一回だけ読む指定ではありません。
本体には、終了記号そのものを読み取らない要素を指定してください。

一回だけ、1回以上などの回数を明示したい場合は、
開始記号、通常の構文要素またはRepeat、終了記号を順に書きます。
囲み全体にラベルを付けるには、`Sequence(label:)`で包みます。

## ルールに名前を付けて参照する

小さな部品を`@Rule`で分け、`$rule`で参照できます。

```swift
@Grammar(spaces: [.space])
struct AssignmentGrammar {
    @Rule
    let number = Syntax {
        Token(label: "digits") { ASCII.digit.repeat(1...) }
    }

    @Rule
    public let assignment = Syntax {
        Token(label: "name", "count")
        "="
        $number
    }
}

let result = try "count = 123".wholeMatch(
    on: AssignmentGrammar.default,
    of: \.$assignment,
)
assert(result.string == "count = 123")
```

- `@Grammar(spaces:)`：文法と、その文法のtriviaを定義します。
- `@Rule let number = Syntax { ... }`：同じ文法から使える名前付きルールです。
- `$number`：ルールをその位置で呼び出す参照です。構文の初期化時に解析するわけではありません。
- `public`な`@Rule`：文法外から呼び出せるルールとして登録されます。

文法には少なくとも一つの公開ルールが必要です。
補助ルールを文法へ登録するには、`private`や`fileprivate`ではなく、上の`number`のように宣言します。
ルール参照には参照先のノードが作られるため、Inlineによる展開とは構文木の形も異なります。

### 別の文法のルールを参照する

`OtherGrammar.$rule`、または`Rule("文法名", "ルール名")`を使えます。
`@Grammar`が作る文法名は型名から末尾の`Grammar`を除いたものです。
上の例なら`"Assignment"`です。

参照先の文法は解析時に登録します。
例えば、上の定義がある場所では次のように呼べます。

```swift
let grammar = AssignmentGrammar.default
let syntax: Syntax = Syntax {
    Rule("Assignment", "assignment")
}

let result = try "count=123".wholeMatch(on: grammar, trivia: [], syntax: syntax)
assert(result.string == "count=123")
```

別文法のルールへ入ると、その文法のtrivia設定を使います。
元の文法へ戻ると呼び出し元の設定へ戻ります。
同じ入力位置で同じルールを再び呼ぶ再帰はエラーになります。
Interpreterで再帰的な文法を定義するときは、再帰呼び出し前に入力が進む形にします。

## Inline：構文の中身をその場へ展開する

```swift
let head: Syntax = Syntax {
    Token(label: "name", "x")
    "="
}

let assignment: Syntax = Syntax {
    Inline(head)
    Token(label: "number", "1")
}

let result = try "x=1".wholeMatch(trivia: [], syntax: assignment)
assert(result.parts.map(\.label) == ["name", "number"])
```

InlineはSyntaxの中身をそのまま展開します。呼び出すルールや新しい文法は作りません。
展開先の文法のtrivia設定を使い、部品名のノードも追加しません。

`[SyntaxIR]`を用意してブロック内へ置く形でも要素を展開できます。
SyntaxBuilderはSwiftの`if`や`for`をブロック内で使う形式には対応していないため、
条件分岐や配列の組み立てはブロックの外で行ってから渡します。

## 空白と入力末尾

### TokenとFragmentの違い

Tokenと文字列リテラルは、その直前に現在の文法のtriviaを読み飛ばします。
Fragmentは現在位置から直接読みます。
SequenceやAnyOfが要素間へ独立に空白を追加するわけではありません。

```swift
let requiredTrivia: Syntax = Syntax {
    Fragment("a")
    Trivia
    Fragment("b")
}

let result = try "a b".wholeMatch(trivia: [.space], syntax: requiredTrivia)
assert(result.string == "a b")

let failure = try? "ab".wholeMatch(trivia: [.space], syntax: requiredTrivia)
assert(failure?.string == nil)
```

`Trivia`は、現在の文法のtriviaを一つ以上読み取る要素です。
半角スペースという固定の文字を表すものではありません。
この例では両端の文字を直接読み、空白の消費をTriviaにだけ担当させています。
字句の内部に空白を要求する場合は、TokenBuilderで文字クラスなどを明示します。

`Trivia(repeat:)`という関数もありますが、現在は回数指定を反映しません。
空白の回数を指定するには、Fragment内で`CharacterClass.space.repeat(...)`などを使います。

### 入力末尾まで一致させる

`wholeMatch`は、構文の成功後に現在の文法のtriviaを消費し、入力末尾を確認します。
`prefixMatch`は入力末尾を要求しません。
用途に応じて呼び出し側で選択してください。

`SyntaxIR._eos`はエンジン内部用の命令です。
通常の文法定義で末尾確認のために指定する要素としては扱いません。

## 構文木のラベルと出力形式

- `Token(label:)`：一つの字句に名前を付けます。
- `Sequence(label:)`：複数の子をまとめた構造に名前を付けます。
- `@Rule(label:)`：ルールのノード名を指定します。未指定の場合はルール名が使われます。

Optionalを省略した位置には空ノードを出力しません。

`treeStrategy: .asis`では、ラベルなしの字句やSequenceの補助ノードなども含めて出力します。
`treeStrategy: .compact`では、ラベルなし・`#`から始まる補助ノードを畳み込み、
明示したラベルやルールのノードを中心に残します。
文字列の`wholeMatch`・`prefixMatch`では`compact`が既定です。

`SourceNode.string`でその部分の原文、`parts`で子ノードを取得できます。
原文はノードの範囲をそのまま切り出したもので、内部にある空白なども含みます。

## 内部用のSyntaxIR

`SyntaxIR._eos`、`._always`、`._never`、`._test`は内部用の命令です。
通常の文法定義では上記のBuilderとルール参照を使用します。
旧名の`SyntaxIR.eos`、`.always`、`.never`、`.test`は現在のAPIにはありません。

## 反復と再帰の上限

Interpreterの構文反復・ルール再帰には上限があります。
`Interpreter.Options(maxSyntaxRepetition:)`で指定し、既定値は1,000です。
Token内の字句反復上限`maxTokenRepetition`とは別の設定です。

最小回数が上限を超える反復や、入力を消費しない本体を繰り返し続ける文法は、
上限エラーになる場合があります。通常の反復本体は、成功時に入力が進むように定義します。
現実装の上限判定には返却ノード数も関係するため、上限を単純な字数制限として扱わないでください。

## 実行方式と現行実装の制限

本書の照合例はInterpreterの`.v1`・`.v2`を対象にしています。
主な構文Builderは共通ですが、次の境界には実装上の差があります。

- Listの有限範囲、特に末尾区切りを許可する場合の上限判定には両Interpreter間の差があります。
  例えば`List(1...2, lastSeparator: .allow)`に`"a,a,a"`を与えると、
  `.v1`は3値を受理し、`.v2`はwhole matchに失敗します。
  厳密な個数を必要とする場合は、利用するエンジンと境界の入力で確認してください。
- Enclosureで本体が終了記号も読める場合、内部の反復方針の違いにより結果が異なり得ます。
  本書のように終了記号を本体から分離する使い方をしてください。
- `Trivia(repeat:)`は回数指定が未実装です。
