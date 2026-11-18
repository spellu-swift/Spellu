# @Grammarと@Ruleで文法を定義する

`@Grammar`と`@Rule`を使うと、構文を名前付きのルールに分け、
ルール同士を参照しながら文法を組み立てられます。
文法ごとに空白やコメントの読み飛ばし方を指定でき、別の文法のルールも利用できます。

本書は、`import Spellu`で利用する文法定義と、
Interpreterの`.v1`・`.v2`による解析を対象にしています。
既定のInterpreterは`.v2`です。
それ以外の対応範囲は[SyntaxBuilder](SyntaxBuilder.md)を参照してください。

字句の書き方は[TokenBuilder](TokenBuilder.md)、
構文の選択や繰り返しは[SyntaxBuilder](SyntaxBuilder.md)を参照してください。

## 最小の文法を定義して解析する

```swift
import Spellu

@Grammar(spaces: [.space])
struct NumberGrammar {
    @Rule
    public let number: Syntax = Syntax {
        Token {
            ASCII.digit.repeat(1...)
        }
    }
}

let result: SourceNode = try " 123 ".wholeMatch(
    on: NumberGrammar.default,
    of: \.$number,
)
assert(result.label == "number")
assert(result.grammar == "Number")
assert(result.string == "123")
```

この例には、次の三つの役割があります。

- `@Grammar(spaces:)`：ルールをまとめ、読み飛ばす空白などを指定する。
- `@Rule`：`Syntax`に名前を付け、他のルールから参照できるようにする。
- `wholeMatch(on:of:)`：文法のインスタンスと開始ルールを指定して解析する。

ルール名はプロパティ名の`number`です。
`of: \.$number`は、このルールを解析の開始点として選びます。
最初に宣言したルールが自動的に開始ルールになるわけではありません。

`@Grammar`の`trivia:`は省略せずに指定します。
読み飛ばしが不要なら`@Grammar(spaces: [])`とします。
`.space`は改行を含まない空白です。改行も読み飛ばすなら`.newline`を追加します。

## 文法名と、マクロが用意するもの

文法名には、型名の末尾の`Grammar`を取り除いた名前を使います。
`NumberGrammar`なら`"Number"`です。
型名が`Grammar`で終わらなければ、その型名をそのまま使います。

```swift
let declaration: NumberGrammar = .default
let grammar: SpelluGrammar = declaration.grammar()
let reference: RuleReference = NumberGrammar.$number

assert(NumberGrammar.id == "Number")
assert(grammar.name == "Number")
assert(grammar.rule(name: "number") != nil)
assert(reference.grammar == "Number")
assert(reference.rule == "number")
```

`@Grammar`は、その型を`GrammarDeclaration`に準拠させ、次を用意します。

- `型名.default`：引数なしの初期化で作った文法インスタンス。
- `型名.id`：文法名。
- `インスタンス.grammar()`：定義を`SpelluGrammar`として取り出すメソッド。

`@Rule`は、元のプロパティとは別に、`$`を付けた`RuleReference`を用意します。
`$number`はインスタンスからも型からも取得できます。

`number`はルールの中身である`Syntax`、`$number`は文法名とルール名による参照です。
両者は用途が異なります。
ルールを呼び出すときは`$number`、中身だけを展開するときは`Inline(number)`を使います。
`Inline`はルール呼び出しの境界や、そのルール名のノードを作りません。

生成される`.default`が`.init()`を使うため、文法型は引数なしで初期化できるようにします。
初めは、本書のように`struct`の中に`Syntax`のプロパティを置く形で十分です。

## 一つの文法を複数のルールに分ける

```swift
@Grammar(spaces: [.space])
struct AssignmentGrammar {
    @Rule
    let identifier: Syntax = Syntax {
        Token {
            CharacterClass.range("a"..."z").repeat(1...)
        }
    }

    @Rule
    let integer: Syntax = Syntax {
        Token {
            ASCII.digit.repeat(1...)
        }
    }

    @Rule
    public var assignment: Syntax {
        Syntax {
            $identifier
            "="
            $integer
            Optional { ";" }
        }
    }
}

let result: SourceNode = try "count = 123;".wholeMatch(
    on: AssignmentGrammar.default,
    of: \.$assignment,
)
assert(result.label == "assignment")
assert(result.parts.map(\.label) == ["identifier", "integer"])
assert(result.parts.map(\.string) == ["count", "123"])
```

`assignment`から、同じ文法の`identifier`と`integer`を呼び出しています。
`$identifier`と書くことで、そのルールを一つの構文要素として使えます。
ルール参照は、Sequence・AnyOf・Optional・Repeatなどの中にも置けます。

固定の構文には`let`を使えます。
インスタンスの`$rule`を参照する構文は、例のように計算プロパティの`var`で書けます。
`@Rule`はインスタンスの`let`または`var`に付けます。`static`は付けられません。

### publicと、文法内部のルール

`public`を付けたルールは、文法の外部へ提供するルールとして登録されます。
外から使う開始ルールや、他文法へ提供するルールに付けてください。

`public`を付けない通常のルールも文法には登録され、内部の部品として参照できます。
上の例では`identifier`と`integer`が内部のルールです。

`private`や`fileprivate`を付けたプロパティは、`@Rule`が付いていても、
`@Grammar`が作る文法のルール一覧から除外されます。
文法内部の補助ルールを登録したい場合は、これらを付けずに宣言してください。

文法検査では、少なくとも一つの公開ルールが必要です。
一つもなければ`SpelluError.noExposedRule`になります。
なお、Interpreterの名前解決自体は`expose`を検査していないため、
`public`を実行時のアクセス制限として利用することはできません。

Swiftの別モジュールから文法を利用させる場合は、文法型自体のアクセス範囲も
`public struct ...`などで公開してください。

## 全体一致と先頭一致を使い分ける

```swift
let prefix: SourceNode = try "123abc".prefixMatch(
    on: NumberGrammar.default,
    of: \.$number,
)
assert(prefix.string == "123")

let whole: SourceNode? = try? "123abc".wholeMatch(
    on: NumberGrammar.default,
    of: \.$number,
)
assert(whole == nil)
```

`prefixMatch`は開始ルールが成功すれば結果を返し、残りの入力を要求しません。
`wholeMatch`は開始ルールの後に文法のtriviaを消費し、入力末尾まで到達することを要求します。
そのため`"123 "`はNumberGrammarの全体一致に成功し、`"123abc"`は失敗します。

入力末尾までの一致が必要な場合は、解析の呼び出し側で`wholeMatch`を選びます。
`SyntaxIR._eos`はエンジン内部用の命令で、通常の文法定義には使いません。

## ルールのラベルとエラー表示を指定する

```swift
@Grammar(spaces: [.space])
struct IntegerGrammar {
    @Rule(expect: "整数", label: "integer")
    public let number: Syntax = Syntax {
        Token {
            ASCII.digit.repeat(1...)
        }
    }
}

let result: SourceNode = try "42".wholeMatch(
    on: IntegerGrammar.default,
    of: \.$number,
)
assert(result.label == "integer")
assert(IntegerGrammar.$number.rule == "number")
```

`label:`は、成功したルールが作る`SourceNode`のラベルです。
省略するとルール名がラベルになります。
ラベルを変更しても、呼び出しに使うルール名や`$number`の名前は変わりません。

文字列解析の既定の`treeStrategy`は`.compact`です。
ラベルなしの字句や内部的な補助ノードを畳み込み、通常のルール名や指定したラベルのノードを残します。
`#`で始まるラベルは補助ラベルとして扱われます。

`expect:`は、通常の不一致がこのルールを抜けるとき、期待していたものの表示を置き換えます。
指定方法は次のとおりです。

- 省略または`nil`：内部から伝わる期待値を使う。
- `.ruleName`：ルール名を使う。
- `.string("整数")`または`"整数"`：指定した文字列を使う。

```swift
do {
    _ = try "abc".wholeMatch(
        on: IntegerGrammar.default,
        of: \.$number,
    )
    assertionFailure("整数ではないので失敗するはずです")
}
catch let error as SpelluError {
    guard case let .unexpected(_, _, _, _, expects) = error else {
        throw error
    }
    assert(expects.contains(.rule("整数")))
}
```

`expect:`は選択候補の優先値ではなく、受け付ける入力も変更しません。
また、AnyOfの内部で集約されたエラーなど、すべてのエラー表示を一括で置き換える指定ではありません。

## 別の文法のルールを利用する

文法を分けると、数値や文字列などの共通ルールを複数の文法から使えます。

```swift
@Grammar(spaces: [.space])
struct CommonGrammar {
    @Rule
    public let integer: Syntax = Syntax {
        Token {
            ASCII.digit.repeat(1...)
        }
    }
}

@Grammar(spaces: [.space])
struct SumGrammar {
    @Rule
    public let sum: Syntax = Syntax {
        CommonGrammar.$integer
        "+"
        CommonGrammar.$integer
    }
}

let result: SourceNode = try "12 + 34".wholeMatch(
    on: SumGrammar.default,
    CommonGrammar.default,
    of: \.$sum,
)
assert(result.parts.map(\.label) == ["integer", "integer"])
assert(result.parts.map(\.grammar) == ["Common", "Common"])
assert(result.parts.map(\.string) == ["12", "34"])
```

参照先は`CommonGrammar.$integer`の形で指定できます。
**解析時には、参照先の文法インスタンスも渡してください。**
`RuleReference`は文法名とルール名を保持しており、文法の中身を自動登録するものではありません。
必要な文法がなければ`SpelluError.grammarNotFound`になります。
文法はあるもののルールがなければ`SpelluError.ruleNotFound`になります。
参照がさらに別の文法を使う場合も、必要な文法をすべて渡します。
文法名は重複させないでください。

別文法のルールを実行している間は、その文法のtrivia設定が使われます。
呼び出し元へ戻ると、呼び出し元の設定に戻ります。

### 文法名とルール名で参照する

型を使わず、`Rule("文法名", "ルール名")`でも参照できます。

```swift
let result: SourceNode = try "56".wholeMatch(
    on: CommonGrammar.default,
    trivia: [],
    syntax: Syntax {
        Rule("Common", "integer")
    },
)
assert(result.parts.first?.label == "integer")
assert(result.parts.first?.string == "56")
```

ここでの`"Common"`は`CommonGrammar.id`の値であり、型名の`"CommonGrammar"`ではありません。
名前は解析時に解決されます。
型の参照を使える場所では、名前の書き間違いを避けるため`CommonGrammar.$integer`を使うと便利です。

## triviaで空白やコメントを読み飛ばす

`SourceTree.trivia` には、`SpelluGrammar.trivia` のルールが自動で消費した範囲が入力順に入ります。
一回の読み飛ばしの中で隣接した範囲は、一つの `#trivia` ノードにまとめます。
読み方が複数あるときは、先頭から順に各構文Triviaが最も長くなる読み方を採ります。この規則はエンジンによらず同じです。
`spaces` で消費した字句空白は読み飛ばしに使い、その範囲は収集しません。

`@Grammar(spaces:)`には`[TriviaPattern]`を指定します。
よく使う組み合わせは次のとおりです。

- `[]`：自動では何も読み飛ばさない。
- `[.space]`：改行以外の空白を読み飛ばす。
- `[.space, .newline]`：空白と改行を読み飛ばす。
- `.string("...")`：固定文字列を読み飛ばす。
- `.characters([...])`：指定したUnicodeスカラーを読み飛ばす。
- `.lex(...)`：`TokenIR`で表す字句パターンを読み飛ばす。
- `.syntax(...)`：参照先ルールに一致する入力を読み飛ばす。

triviaは通常、Token・Word・末尾判定の直前で自動消費されます。
ルール参照それ自体が無条件にtriviaを消費するわけではありません。
参照先のTokenなどで消費されます。
`Fragment`は自動消費を行わないため、空白の有無も構文の一部にしたい箇所で使えます。

### 同じ文法のコメントルールを指定する

```swift
@Grammar(spaces: [
    .space,
    .newline,
    .syntax(Rule("Commented", "comment")),
])
struct CommentedGrammar {
    @Rule
    let comment: Syntax = Syntax {
        Token {
            "/*"
            CharacterClass.all.repeat(0..., behavior: .reluctant)
            "*/"
        }
    }

    @Rule
    public let pair: Syntax = Syntax {
        Token(label: "left", "a")
        Token(label: "right", "b")
    }
}

let result: SourceNode = try " /*前*/ a /*間*/ b /*後*/ ".wholeMatch(
    on: CommentedGrammar.default,
    of: \.$pair,
)
assert(result.parts.map(\.label) == ["left", "right"])
assert(result.parts.map(\.string) == ["a", "b"])
```

このコメントは、最初の`*/`までを読む、入れ子を扱わないブロックコメントです。
`.reluctant`はToken内の繰り返しを短い方から試す指定です。
繰り返しの詳細は[TokenBuilder](TokenBuilder.md)を参照してください。

`@Grammar`の引数から、マクロが生成する`$comment`を参照すると、
マクロ展開の循環や、生成メンバーを解決できないエラーが起きることがあります。
例のように`Rule("Commented", "comment")`で名前参照を指定してください。
同一文法内のtrivia用ルールには`public`は不要です。

`.syntax(...)`には単純なルール参照を指定します。
OptionalやAnyOfなどを直接渡すのではなく、それらをルールの中に書いて、そのルールを参照します。
同一文法内の参照先の存在と無消費成功は、文法検査の対象になります。
空文字列で成功すると判定された同一文法のルールは、文法検査時に拒否されます。

読み飛ばしでは、まず字句triviaを消費し、続いてルール指定のtriviaを試します。
ルールが入力を消費して成功すれば、その後も同じ処理を繰り返します。
triviaのルールは先頭一致で実行され、その結果の構文木は本文の子ノードには加えません。
ただし、本文のノードの`string`は元の入力の範囲なので、子ノードの間のコメントを含むことがあります。

triviaルールの実行中は、内側のルール呼び出しも含め、自動的なtrivia消費が抑止されます。
コメント内の空白や改行は、そのルール自身のパターンで読めるようにしてください。
途中まで読んで通常の不一致になった場合は、試行前の位置に戻します。
そのため、閉じ忘れたコメント専用の診断が自動で出るとは限りません。

### Interpreterでの構文trivia

Interpreter v1・v2では、候補を`ChoiceOf`で選び、`Repeat`で繰り返します。
字句triviaを挟む部分も`Optional`として実行し、通常の構文ルール処理で
候補の途中失敗や読みかけた入力の巻き戻しを扱います。
解析結果のノードは本文へ追加せず、明示的な`Trivia`の場合だけ、
消費範囲を持つ`#trivia`ノードを生成します。

構文triviaの繰り返しにも`maxSyntaxRepetition`が適用されます。
静的検査で判定できない無消費成功が続く場合も、Trivia専用のエラーではなく、
通常の`Repeat`と同じ`overLimitsOfRepetition`で停止します。
候補内の期待値はTriviaの実行境界で復元し、本文の診断へ持ち出しません。

### 別文法のtriviaルールを指定する

```swift
@Grammar(spaces: [])
struct CommentsGrammar {
    @Rule
    public let lineComment: Syntax = Syntax {
        Token {
            "//"
            CharacterClass.notNewline.repeat(0...)
        }
    }
}

@Grammar(spaces: [
    .space,
    .newline,
    .syntax(Rule("Comments", "lineComment")),
])
struct TextGrammar {
    @Rule
    public let text: Syntax = Syntax {
        Token(label: "body", "hello")
    }
}

let result: SourceNode = try "//前の行\nhello //行末".wholeMatch(
    on: TextGrammar.default,
    CommentsGrammar.default,
    of: \.$text,
)
assert(result.parts.map(\.string) == ["hello"])
```

別文法のルールも、文法名とルール名で指定できます。
この場合も、解析時に参照先の文法を登録します。
行コメントは改行を消費しないので、TextGrammar側の`.newline`で読み飛ばしています。
他文法のtriviaについては、参照先を実行時に解決します。

### triviaを明示的に要求する

```swift
@Grammar(spaces: [.space])
struct GapGrammar {
    @Rule
    public let pair: Syntax = Syntax {
        Fragment(label: "left", "a")
        Trivia
        Fragment(label: "right", "b")
    }
}

let result: SourceNode = try "a b".wholeMatch(
    on: GapGrammar.default,
    of: \.$pair,
)
assert(result.parts.map(\.string) == ["a", "b"])

let withoutGap: SourceNode? = try? "ab".wholeMatch(
    on: GapGrammar.default,
    of: \.$pair,
)
assert(withoutGap == nil)
```

この例はInterpreterを対象にしています。構文要素の`Trivia`は、
現在の文法のtriviaを少なくとも一つ消費することを要求します。
`SpelluGrammar.trivia`による自動読み飛ばしは引き続き利用できます。
`Token("a")`と`Token("b")`を並べるだけなら、間の空白は省略可能です。
この例ではFragmentとTriviaを組み合わせ、間の空白を必須にしています。

## 再帰するルールを定義する

`$rule`は名前参照なので、自分自身や別のルールを再帰的に呼び出せます。

```swift
@Grammar(spaces: [.space])
struct NestedGrammar {
    @Rule
    public var value: Syntax {
        Syntax {
            AnyOf {
                Token(label: "atom", "x")
                Sequence {
                    "("
                    $value
                    ")"
                }
            }
        }
    }
}

let result: SourceNode = try "((x))".wholeMatch(
    on: NestedGrammar.default,
    of: \.$value,
)
assert(result.label == "value")
assert(result.string == "((x))")
```

Interpreterでは、同じ入力位置で同じ文法・ルールへ再び入る再帰を検出し、
`SpelluError.recursiveRule`にします。
左再帰の形をそのまま書かず、先に入力を消費する形や繰り返しへ書き換えてください。
上の例は、再帰呼び出しの前に`(`を消費するので解析できます。
深さには上限もあり、Interpreterの既定値は1000です。

AnyOfやRepeatなどの照合規則は、ルールに分けても変わりません。
例えば、構文のAnyOfで同じ最高優先値の候補が複数成功した場合は、曖昧性エラーになります。
ルール化するだけで候補が記述順に確定するわけではありません。

## Interpreterで登録と解析を分ける

```swift
let interpreter: Interpreter = Interpreter(
    grammars: [SumGrammar.default, CommonGrammar.default],
    treeStrategy: .compact,
)

let result: SourceNode = try interpreter.match(
    source: .temporary("7 + 8"),
    method: .whole,
    rule: SumGrammar.$sum,
)
assert(result.parts.map(\.string) == ["7", "8"])
```

同じ文法で何度も解析する場合は、Interpreterに文法を登録して使えます。
`GrammarDeclaration`の配列を渡すこの初期化では、`treeStrategy:`を明示します。
開始ルールは解析ごとに`rule:`で指定します。

Stringの解析メソッドもInterpreterも、`engine: .v1`または`engine: .v2`で
Interpreterを明示的に選べます。省略時は`.v2`です。

## うまく動かないときの確認点

- `$rule`の参照先を解析時に登録しているか。参照の生成だけでは登録されません。
- `Rule("文法名", "ルール名")`の文法名に、`Grammar`を除いた名前を使っているか。
- 補助ルールに`private`や`fileprivate`を付けて、文法の登録対象から外していないか。
- 文法に少なくとも一つの`public`なルールがあるか。
- `@Grammar(spaces:)`に、改行を読み飛ばす必要があるなら`.newline`も含めているか。
- 空白を許したい箇所で、Fragmentを使っていないか。
- triviaには単純なルール参照を渡し、そのルールが必ず入力を消費するようにしているか。
- 全体一致が必要な場面で、先頭一致を使っていないか。
- 再帰呼び出しが、入力を消費せずに同じルールへ戻っていないか。

構文の分岐や繰り返しの問題は[SyntaxBuilder](SyntaxBuilder.md)、
Token内部のバックトラックや繰り返しの問題は[TokenBuilder](TokenBuilder.md)も参照してください。
