# TokenBuilderで字句パターンを定義する

TokenBuilderは、数値・識別子・記号などの「一つの字句」を定義するための仕組みです。
文字列と文字クラスを並べ、`ChoiceOf`、`Optional`、`Sequence`、`Repeat`で組み合わせます。

字句APIは`SpelluLex`モジュールにあります。字句パターンだけを組み立てる場合は
`import SpelluLex`で利用できます。本書の構文例は`import Spellu`を使います。
`SpelluCore`と`Spellu`からも字句APIが再公開されるため、従来のimportを変更する必要はありません。

省略可能な部分を表すAPIの名前は **`Optional`** です。本書ではこの名前を使います。

本書の照合順と後戻りの説明は、Interpreterの`.v1`・`.v2`を対象とします。

## まずは符号付き整数を書いてみる

次の例は、`-`または`+`を省略できる整数です。

```swift
import Spellu

let integer: Syntax = Syntax {
    Token(label: "integer") {
        Optional {
            ChoiceOf {
                "+"
                "-"
            }
        }
        ASCII.digit.repeat(1...)
    }
}

let result = try "-123".wholeMatch(trivia: [], syntax: integer)
assert(result.string == "-123")
```

`Token { ... }`の中身は、上から順に、間を空けずに照合します。
この例では、符号を読むか省略した後、ASCIIの数字を1文字以上読みます。
`"123"`、`"+123"`、`"-123"`が一致し、`"-"`や`"- 123"`は一致しません。

`label:`は字句のノードに名前を付けます。`Optional`や`ChoiceOf`など、
Token内部の組み合わせごとにノードが作られるわけではありません。

`wholeMatch`は入力全体が文法に一致することを要求します。
字句の切り出しを調べるには、先頭部分だけを照合する`prefixMatch`も使えます。
本書の照合例は、空白の自動消費が結果に影響しないよう`trivia: []`を指定します。

## 何を組み合わせられるか

TokenBuilderには、次の三種類を記述できます。

- **文字列**: `"if"`や`"=="`など、文字列そのものに一致します。
- **文字クラス**: `ASCII.digit`や`CharacterClass.any("+-")`など、
  指定した集合のUnicodeScalarを一つ読みます。
- **字句パターン（`TokenIR`）**: `Sequence`などの戻り値や、変数へ保存したパターンです。

文字列は正規表現ではありません。例えば`"[0-9]+"`は、その文字列そのものを表します。
数字の反復を表すには`ASCII.digit.repeat(1...)`と書きます。

```swift
let identifierHead: TokenIR = CharacterClass.include(
    CharacterClass.range("a"..."z"),
    CharacterClass.range("A"..."Z"),
    CharacterClass.any("_"),
).asLexRule

let identifier: Syntax = Syntax {
    Token(label: "identifier") {
        identifierHead
        ASCII.word.repeat(0...)
    }
}

let result = try "name_123".wholeMatch(trivia: [], syntax: identifier)
assert(result.string == "name_123")
```

このように、よく使う部分を`TokenIR`の変数に保存して再利用できます。
`Rule(...)`や`$rule`などの構文ルール参照をTokenBuilderの内部に置くことはできません。
ルールを組み合わせる場合は、`Token`の外側の`Syntax { ... }`に記述します。

## Sequence：複数の要素を一つにまとめる

`Sequence`は、中の要素を順に照合する一つのパターンを作ります。
`Token { ... }`などの字句ブロック内では、`TokenIR`を返す字句用のSequenceになります。
構文用の`Sequence(label:)`と異なり、ラベルを指定する引数はありません。
次の例は、`"ab"`全体を2回読むため、`"abab"`に一致します。

```swift
let paired: Syntax = Syntax {
    Token {
        Sequence {
            "a"
            "b"
        }.repeat(2...2)
    }
}

let result = try "abab".wholeMatch(trivia: [], syntax: paired)
assert(result.string == "abab")
```

単に要素を並べるだけならSequenceで囲む必要はありません。
複数要素をまとめて反復する、大小文字設定を適用する、
ChoiceOfの一つの候補にする、といった場合に使います。

Sequenceは文字を追加したり、空白を読み飛ばしたりしません。
また、Sequenceが一度成功しても、その内部への後戻りは可能です。

## ChoiceOf：候補を記述順に試す

`ChoiceOf`の直下の各パターンが、一つずつの候補になります。
最初の候補から試し、同じTokenの末尾まで成功する組み合わせを返します。

```swift
let selected: Syntax = Syntax {
    Token {
        ChoiceOf {
            "ab"
            "a"
        }
        "b"
    }
}

let result = try "ab".wholeMatch(trivia: [], syntax: selected)
assert(result.string == "ab")
```

最初の候補`"ab"`は一度成功しますが、後続の`"b"`を読む文字が残っていません。
そこでChoiceOfの開始位置へ戻り、次の候補`"a"`を選び直します。
その後の`"b"`も成功するので、Token全体として`"ab"`に一致します。
Sequenceをまたいだ後続の失敗でも、この選び直しが行われます。

### 複数要素からなる候補にはSequenceを使う

```swift
let number: Syntax = Syntax {
    Token {
        ChoiceOf {
            Sequence {
                "0x"
                CharacterClass.any("0123456789abcdef").repeat(1...)
            }
            ASCII.digit.repeat(1...)
        }
    }
}

let result = try "0xff".wholeMatch(trivia: [], syntax: number)
assert(result.string == "0xff")
```

このChoiceOfには、「`0x`に続く16進数字」と「10進数字」の二つの候補があります。
Sequenceを外して`"0x"`と16進数字を別々に置くと、それぞれが独立した候補になります。

### 記述順と最長一致は異なる

```swift
let first: Syntax = Syntax {
    Token {
        ChoiceOf {
            "a"
            "ab"
        }
    }
}

let result = try "ab".prefixMatch(trivia: [], syntax: first)
assert(result.string == "a")
```

最初の`"a"`でToken全体が成功するため、`"ab"`の方が長くても選び直しません。
`"=="`と`"="`など、先頭が重なる固定文字列では、長い候補を先に書くと意図が明確です。

このChoiceOfには整数の優先値を指定する引数はありません。
構文側の`AnyOf`や`Branch`の優先順位とは別の仕組みです。

## Optional：ひとかたまりを省略可能にする

`Optional { ... }`は、中身全体を0回または1回読みます。
通常は、まず読む方を試し、同じTokenの後続が失敗したら省略する方へ戻れます。

```swift
let decimal: Syntax = Syntax {
    Token {
        ASCII.digit.repeat(1...)
        Optional {
            "."
            ASCII.digit.repeat(1...)
        }
    }
}

let whole = try "12.50".wholeMatch(trivia: [], syntax: decimal)
assert(whole.string == "12.50")

let prefix = try "12.".prefixMatch(trivia: [], syntax: decimal)
assert(prefix.string == "12")
```

入力`"12."`では、小数部分が途中で失敗するため、`.`も含めて読み取りを取り消します。
小数部分全体を省略し、`"12"`だけが字句になります。

`Optional`自身には`behavior:`引数はありません。
0回または1回の照合動作を指定する場合は、例えば次のように書きます。

```swift
let optionalSuffix: TokenIR = Sequence {
    "."
    ASCII.digit.repeat(1...)
}.repeat(0...1, behavior: .possessive)
```

## Repeatと.repeat：回数を指定する

`Repeat`は中身全体を、`.repeat`は直前のパターンを反復します。
次の二つは同じ字句パターンです。

```swift
let first: TokenIR = Repeat(1...3) {
    "ab"
}

let second: TokenIR = "ab".repeat(1...3)
assert(first.amount == second.amount)
```

文字列・文字クラス・SequenceやChoiceOfの結果に`.repeat`を使えます。
TokenBuilder用の`Repeat`では、回数の範囲を省略せずに書きます。

範囲の書き方は次のとおりです。

- `0...`：0回以上。
- `1...`：1回以上。
- `3...`：3回以上。
- `2...4`：2回以上、4回以下。
- `2..<4`：2回以上、4回未満、つまり2回または3回。
- `...3`：0回以上、3回以下。
- `..<3`：0回以上、3回未満。
- `3...3`：ちょうど3回。

### 後から.repeatを付けると回数を置き換える

```swift
let three: TokenIR = "a".repeat(2...2).repeat(3...3)
let six: TokenIR = Sequence {
    "a".repeat(2...2)
}.repeat(3...3)
```

`three`は`"a"`を3回読みます。既存の2回指定を3回へ置き換えるためです。
`six`は2回読むパターン全体を3回読むため、合計6回になります。
反復の指定を重ねるときは、Sequenceで囲む位置に注意してください。

## 反復の動作：eager・reluctant・possessive

`Repeat(..., behavior: ...)`または`.repeat(..., behavior: ...)`で指定します。
省略時は **`.eager`** です。いずれも指定された最小回数・最大回数の範囲内で動きます。

### eager：多い回数から試し、必要なら戻る

```swift
let eager: Syntax = Syntax {
    Token {
        "a".repeat(0..., behavior: .eager)
        "a"
    }
}

let result = try "aaa".prefixMatch(trivia: [], syntax: eager)
assert(result.string == "aaa")
```

反復は最初に`"aaa"`を読みます。後続の`"a"`が失敗すると反復を1回減らし、
その1文字を後続が読むことで成功します。

### reluctant：少ない回数から試し、必要なら増やす

```swift
let reluctant: Syntax = Syntax {
    Token {
        "a".repeat(0..., behavior: .reluctant)
        "a"
    }
}

let result = try "aaa".prefixMatch(trivia: [], syntax: reluctant)
assert(result.string == "a")
```

反復0回で後続が成功するため、先頭の1文字だけに一致します。

閉じ区切りが最初に成立するところまで読みたい場合にも使えます。

```swift
let comment: Syntax = Syntax {
    Token(label: "comment") {
        "/*"
        CharacterClass.all.repeat(0..., behavior: .reluctant)
        "*/"
    }
}

let result = try "/* one */ /* two */".prefixMatch(
    trivia: [],
    syntax: comment,
)
assert(result.string == "/* one */")
```

`CharacterClass.all`は改行も含みます。閉じ区切りがなければToken全体が失敗します。
この例のコメントはネストしません。

### possessive：多く読んで確定し、後続のために戻らない

```swift
let possessive: Syntax = Syntax {
    Token {
        "a".repeat(0..., behavior: .possessive)
        "a"
    }
}

let result = try? "aaa".prefixMatch(trivia: [], syntax: possessive)
assert(result?.string == nil)
```

反復が`"aaa"`を読み切って確定するため、後続の`"a"`を読めず失敗します。
反復が成功して確定すると、本体の内部にあるChoiceOfなどの再試行候補も破棄します。
反復そのものを成立させるための候補選びは行いますが、確定後は選び直しません。

この指定で、外側のChoiceOfまで確定するわけではありません。
外側に別の候補があれば、その候補を試すことはできます。

### behaviorは指定した反復だけに作用する

外側のRepeatに`.reluctant`を付けても、内側の反復の既定値は`.eager`のままです。
`.repeat`をもう一度呼ぶ場合も、新しい呼び出しの`behavior:`を使います。
省略すれば`.eager`になります。

また、eager・reluctantは「反復回数を試す順序」です。
ChoiceOfの候補全体を長さ順に並べ替えたり、Token全体の最長・最短を保証したりはしません。

## 後戻りは、同じTokenの中で行われる

次の二つは異なります。

```swift
let inside: Syntax = Syntax {
    Token {
        ChoiceOf { "ab"; "a" }
        "b"
    }
}

let outside: Syntax = Syntax {
    Token { ChoiceOf { "ab"; "a" } }
    Token("b")
}

let success = try "ab".wholeMatch(trivia: [], syntax: inside)
assert(success.string == "ab")

let failure = try? "ab".wholeMatch(trivia: [], syntax: outside)
assert(failure?.string == nil)
```

`inside`では、一つのTokenを成立させるためにChoiceOfへ戻れます。
`outside`では、最初のTokenが`"ab"`で確定してから次のTokenを読みます。
次のTokenが失敗しても、前のToken内部の候補は再試行しません。

`wholeMatch`による入力末尾の確認もTokenの外で行われます。
そのため、先ほどの`ChoiceOf { "a"; "ab" }`だけを持つTokenは、
入力`"ab"`の`wholeMatch`では失敗します。入力全体を覆うために
Token内の候補を自動的に`"ab"`へ選び直すわけではありません。

## 文字クラスとUnicode

よく使う文字クラスには次のものがあります。

- `ASCII.digit`：`0`〜`9`。
- `ASCII.word`：ASCIIの英数字と`_`。
- `CharacterClass.digit`：Unicodeの十進数字。全角数字なども含みます。
- `CharacterClass.any("+-")`：指定したUnicodeScalarのどれか一つ。
- `CharacterClass.range("a"..."z")`：指定した範囲のどれか一つ。
- `CharacterClass.include(a, b)`：文字クラスaまたはbに含まれるもの。
- `CharacterClass.exclude(a, b)`：文字クラスaにもbにも含まれないもの。
- `a.inverted`：文字クラスaに含まれないもの。
- `CharacterClass.all`：改行を含む任意のUnicodeScalar。
- `CharacterClass.space`：タブやUnicodeの空白区切り文字。改行は含みません。
- `CharacterClass.newline`：LF、CR、Unicodeの行区切り・段落区切り文字。
- `CharacterClass.notNewline`：上記の改行文字以外。

`Character.digit`や`Character.all`など、`Character`経由の別表記もあります。
本書では、文字クラスであることが分かりやすい`CharacterClass`表記を主に使っています。

照合の単位はSwiftの`Character`ではなく **UnicodeScalar** です。
結合文字や複数Scalarからなる絵文字では、`.repeat(1...1)`が
画面上の1文字と一致するとは限りません。`"\r\n"`も二つのScalarです。

ASCIIの数字だけを受け付ける文法には`ASCII.digit`を使ってください。

## ignoresCase：大小文字を区別しない

文字列・文字クラス・SequenceやChoiceOfに`.ignoresCase()`を付けられます。
省略時は大小文字を区別します。

```swift
let command: Syntax = Syntax {
    Token {
        Sequence {
            "get"
            "ID".ignoresCase(false)
        }.ignoresCase()
    }
}

let result = try "GETID".wholeMatch(trivia: [], syntax: command)
assert(result.string == "GETID")

let failure = try? "GETid".wholeMatch(trivia: [], syntax: command)
assert(failure?.string == nil)
```

外側の設定は、内部の設定が未指定の要素へ引き継がれます。
内部の`.ignoresCase(false)`は、その部分で区別を有効に戻します。
反復回数とbehaviorは`.ignoresCase()`を付けても保持されます。

照合にはUnicode Simple Case Foldingを使います。
例えば`Σ`・`σ`・`ς`は同じ扱いになりますが、`ß`と`ss`のような
複数Scalarへの展開は行いません。照合結果の文字列は入力の表記を保ちます。

## Token・Fragment・Wordの使い分け

いずれもTokenBuilderで内部の字句パターンを記述できます。

### Token：字句の前のtriviaを読み飛ばす

`Token`は、照合を始める前に文法で指定されたtriviaを読み飛ばします。
Token内部の各要素の間には、自動でtriviaを挿入しません。

例えば`Token { "a"; "b" }`は`"ab"`を読みます。
`Token("a")`と`Token("b")`を構文側に並べると、その間にもtriviaを読み飛ばせます。

### Fragment：現在位置から直接読む

`Fragment { ... }`は、先頭のtriviaを自動消費しません。
空白を含めて正確に読む部分や、直前の字句との間に空白を許さない部分に使います。
内部の組み合わせ方と照合規則はTokenと同じです。

### Word：読み取った語全体をキーワードの一覧と照合する

```swift
let keyword: Syntax = Syntax {
    Word("if", "else", caseInsensitive: true) {
        ASCII.word.repeat(1...)
    }
}

let result = try "IF".wholeMatch(trivia: [], syntax: keyword)
assert(result.string == "IF")

let failure = try? "iffy".prefixMatch(trivia: [], syntax: keyword)
assert(failure?.string == nil)
```

Wordは、先頭のtriviaを読み飛ばし、まず本体のパターンで語全体を読みます。
次に、その結果全体が指定したキーワードのどれかと等しいかを確認します。
`"iffy"`を読み取って語条件に失敗しても、短い`"if"`へ戻して受理はしません。
キーワードは可変長引数でも`[String]`でも指定できます。

Wordの`caseInsensitive:`は、読み取った語とキーワードとの比較に使います。
本体パターンへ`.ignoresCase()`を付けたことにはなりません。
例えば本体を`CharacterClass.range("a"..."z").repeat(1...)`にすると、
`caseInsensitive: true`だけでは大文字を本体が読めません。
この例では大文字も含む`ASCII.word`を使っています。

## 回数の上限と空一致

Interpreterでは、字句反復に実行時の上限があります。既定値は65,535回です。
`1...`などの上限を省略した指定も、この上限までに制限されます。
有限の範囲を指定しても実行時上限を超えては反復しません。
必要な場合は、解析時の`Interpreter.Options(maxTokenRepetition: ...)`で変更します。

```swift
let interpreter = Interpreter(
    options: .init(maxTokenRepetition: 100_000),
)

let result = try interpreter.match(
    source: .temporary("123"),
    method: .whole,
    trivia: [],
    syntax: Syntax {
        Token { ASCII.digit.repeat(1...) }
    },
)
assert(result.string == "123")
```

最小回数が実行時上限を超える場合は不一致になります。
上限は字句の総文字数ではなく、個々のパターンの反復回数に適用されます。
後戻りの試行数を制限する設定ではありません。

0回を許すパターンは、入力を消費せずに成功する場合があります。
通常の数値や識別子のTokenでは、少なくともどこかで1文字以上読むように定義してください。

空の`Sequence {}`は空一致、空の`ChoiceOf {}`は不一致です。
現在の実装では文字列`""`を1回読むパターンも不一致になるため、
省略可能性を空文字列で表さず`Optional`を使ってください。
空一致する本体を反復しても、必須回数を満たした後は無消費の反復を続けません。

## TokenBuilderと構文Builderの区別

同じ名前の`ChoiceOf`、`Optional`、`Repeat`でも、置く場所で対象が異なります。

- `Token { ... }`、`Fragment { ... }`、`Word(...) { ... }`の内部：
  字句パターンを組み合わせるTokenBuilderです。本書の照合規則が適用されます。
- `Syntax { ... }`でTokenやルール参照を組み合わせる部分：
  構文側のBuilderです。構文用の選択、優先順位、反復の仕様が適用されます。

構文の`ChoiceOf`は、候補自体が成功した時点で選択を確定します。
字句の`ChoiceOf`は、同じTokenの後続が失敗したときに別候補へ戻れます。
優先値で候補を選ぶ構文の選択には`AnyOf`を使います。
詳しくは[SyntaxBuilderの選択規則](SyntaxBuilder.md)を参照してください。

構文用の`Repeat`にある`strategy:`と、字句用の`Repeat`の`behavior:`は別の設定です。
字句の候補へ構文用の`Branch`を入れて優先値を付けることはできません。

TokenBuilderはSwiftの`if`や`for`を使った条件分岐・展開には対応していません。
条件に応じてパターンを変える場合は、ブロックの外で`TokenIR`を用意して使います。

## 関連する公開API

文法定義で主に使うAPIは次のとおりです。

- `Token(label:) { ... }`、`Fragment(label:) { ... }`、`Word(...) { ... }`
- `Sequence { ... }`、`ChoiceOf { ... }`、`Optional { ... }`
- `Repeat(range, behavior:) { ... }`、`pattern.repeat(range, behavior:)`
- `pattern.ignoresCase()`、`pattern.ignoresCase(false)`
- `CharacterClass`、`ASCII`

さらに、組み立て済みのパターンを扱う場合は、`TokenIR`の
`string`・`character`・`sequence`・`alternative`の生成メソッド、
`amount`・`repetitionBehavior`・`caseInsensitive`のプロパティを利用できます。
