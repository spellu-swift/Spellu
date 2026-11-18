# Spellu APIガイド

Spelluは、定義した文法に従って文字列やファイルを解析し、原文の範囲を持つ構文木を返すAPIです。
全体が文法に一致するかの検証にも、先頭の一部分を読み取る用途にも使えます。

本書は、`Spellu`モジュールの`Spellu`型と、`Extensions`ディレクトリで提供する
`String`・`Source`・`File`・`[Source]`・`[File]`向けの解析APIを対象にします。
文法そのものの書き方は、[文法定義](GrammarDefinition.md)、
[TokenBuilder](TokenBuilder.md)、[SyntaxBuilder](SyntaxBuilder.md)を参照してください。

## APIの概略

使い方は大きく二つあります。

- `Spellu`クラス：文法を`input`で登録し、`parse`で解析します。同じ文法で複数の入力を解析したり、安全上限やログを設定したりする場合に使います。
- 入力型の便利メソッド：`"123".wholeMatch(...)`のように、入力から直接解析します。一度の呼び出しで文法と開始ルールを指定できます。

成功時には`SourceNode`を返します。一致しない場合は`nil`や`false`ではなくエラーを投げるため、
呼び出しには`try`が必要です。配列向けのメソッドは`[SourceNode]`を返します。

APIは`import Spellu`で利用できます。以下の例は、それぞれエラーを投げられる場所で実行してください。

## 最小の文法を用意する

本書では、1桁以上の数字を読む次の文法を使います。

```swift
import Spellu

@Grammar(spaces: [.space])
struct NumberGrammar {
    @Rule
    public let number = Syntax {
        Token {
            ASCII.digit.repeat(1...)
        }
    }
}
```

`NumberGrammar.default`は文法インスタンス、`NumberGrammar.$number`はルール参照です。
`public`なルールは外部へ提供する開始ルールになります。
`trivia: [.space]`は改行以外の空白を読み飛ばす指定です。
改行も読み飛ばすには`.newline`を追加し、何も読み飛ばさない場合は`[]`を指定します。

## Spelluクラスで解析する

```swift
let spellu = try Spellu()
    .input(NumberGrammar.default)

let first = try spellu.parse("123", as: NumberGrammar.$number)
let second = try spellu.parse("456", as: NumberGrammar.$number)

assert(first.string == "123")
assert(second.string == "456")
```

`input`は同じインスタンスを返すため、初期化から続けて呼べます。
`parse`を呼んでも文法は消費されません。同じインスタンスで繰り返し解析できます。
同一インスタンスへの呼び出しは、同じ隔離領域で直列に行ってください。

### 文法を登録する

`input`には次の形式があります。

- `input(grammar, others...)`：`GrammarDeclaration`に準拠した文法インスタンスを登録します。
- `input([grammar, ...])`：`[any GrammarDeclaration]`を登録します。
- `input(model, others...)`、`input([model, ...])`：`SpelluGrammar`を直接登録します。
- `input(trivia:label:syntax:)`：一つの`Syntax`を開始構文として登録します。
- `input(trivia:label:) { ... }`：`SyntaxBuilder`で開始構文を書きます。

別文法のルールを参照する場合は、参照先の文法も登録してください。
ルール参照だけでは文法は自動登録されません。必要な文法をまとめて渡せます。

```swift
let declarations: [any GrammarDeclaration] = [NumberGrammar.default]
let spelluFromArray = try Spellu().input(declarations)
let spelluFromModel = try Spellu().input(NumberGrammar.default.grammar())
```

現在の`input`は登録済み文法へ追加します。置換や初期化としては使わず、
文法の組み合わせを切り替える場合は新しい`Spellu`を作ってください。
一つの登録に同じ文法名やルール名を重複させず、追加する場合も既存文法と名前を重複させないでください。

### 名前付き文法を作らずに解析する

```swift
let literalParser = try Spellu().input(trivia: [], label: "greeting") {
    "hello"
}
let greeting = try literalParser.parse("hello")
assert(greeting.label == "greeting")
```

`Syntax`を先に用意する形式もあります。

```swift
let greetingSyntax = Syntax { "hello" }
let syntaxParser = try Spellu().input(
    trivia: [],
    label: "greeting",
    syntax: greetingSyntax,
)
```

これらの形式では`trivia`の既定値は`[.space]`、`label`の既定値は`.none`です。
`trivia: []`なら空白も自動では読み飛ばしません。

### 開始ルールを選ぶ

`parse(..., as:)`には`RuleReference`を渡します。
`as:`を省略すると、最初に登録した文法の、最初の公開ルールが選ばれます。
後から登録した文法の公開ルールを自動で探すことはありません。

複数の公開ルールがある文法では、`as: NumberGrammar.$number`のように明示すると意図が明確になります。
文法名とルール名で指定するには、`RuleReference(grammar: "Number", rule: "number")`も使えます。

Interpreterでは非公開ルールも明示的に指定できますが、利用者向けの入口は公開ルールとして定義してください。

## 文字列から直接解析する

```swift
let result = try "123".wholeMatch(
    on: NumberGrammar.default,
    as: \.$number,
)
assert(result.string == "123")
```

便利メソッドの`on:`は文法インスタンス、`as:`はその文法のルール参照へのキーパスです。
`Spellu.parse`の`as:`に渡すルール参照とは書き方が異なります。
参照先の文法を追加するときは、`on: mainGrammar, otherGrammar, as: ...`の順で渡します。

小さな構文はブロックで直接指定できます。

```swift
let direct = try "hello".wholeMatch(trivia: [], label: "greeting") {
    "hello"
}
let fromSyntax = try "hello".wholeMatch(trivia: [], as: greetingSyntax)
```

構文内で文法のルールを使う場合も、必要な文法は`on:`へ渡します。

```swift
let wrapped = try "[123]".wholeMatch(on: NumberGrammar.default, trivia: []) {
    "["
    NumberGrammar.$number
    "]"
}
```

## 全体一致と先頭一致

`wholeMatch`と`parse(method: .whole)`は、指定した開始位置から入力範囲の末尾までの一致を要求します。
構文の後ろに残る、文法で指定されたtriviaは読み飛ばせます。`parse`の既定値も`.whole`です。

`prefixMatch`と`parse(method: .prefix)`は、開始位置から構文に一致した部分だけを読み、
残りの入力があっても成功します。入力の途中を検索して一致箇所を探すメソッドではありません。

```swift
let prefix = try "123abc".prefixMatch(on: NumberGrammar.default, as: \.$number)
assert(prefix.string == "123")

let samePrefix = try spellu.parse("123abc", method: .prefix, as: NumberGrammar.$number)
assert(samePrefix.string == "123")

// 数字の後ろにabcが残るため、全体一致は失敗する。
let whole = try? "123abc".wholeMatch(on: NumberGrammar.default, as: \.$number)
assert(whole == nil)
```

## Sourceと開始位置を指定する

元の入力名や解析対象範囲を持たせたい場合は`Source`を使います。
`Source`にも`wholeMatch`と`prefixMatch`があり、文字列と同様に文法・キーパス、
`Syntax`、構文ブロックの三つの指定方法を使えます。

```swift
let source = Source.memory(name: "入力例", "前123", range: .utf8(3..<6))
let node = try source.wholeMatch(on: NumberGrammar.default, as: \.$number)
assert(node.string == "123")
assert(node.range == 3..<6)

let fromOffset = try spellu.parse("前123", from: 3, as: NumberGrammar.$number)
assert(fromOffset.string == "123")
```

`from:`は文字数ではなく、元の`Source.content`の先頭から数える**UTF-8の絶対位置**です。
`"前"`は3バイトなので、例の数字は位置3から始まります。
部分範囲の`Source`でも位置を0へ振り直しません。
指定位置は`source.range`内で、Unicodeスカラーの境界にある必要があります。
範囲外やUTF-8の途中の位置なら`SpelluError.invalidStartOffset`になります。

`Spellu.parse`と`Source`の便利メソッドで`from:`を省略すると、`source.range.lowerBound`から始まります。
文字列と単一ファイルの便利メソッドでは既定値が`0`です。
開始位置を指定した全体一致は、その位置から末尾までを対象とし、それより前の入力は検証しません。

## ファイルと複数の入力を解析する

`File`はBasisのファイル型です。`import Spellu`から利用できます。
ファイル向けの便利メソッドは全体一致の`wholeMatch`です。

```swift
let file = File(at: "number.txt")
let fileNode = try file.wholeMatch(
    tabIndentation: 4,
    on: NumberGrammar.default,
    as: \.$number,
)
```

`File.wholeMatch`は、文法とキーパスのほか、`as: greetingSyntax`や構文ブロックも受け付けます。
`tabIndentation`は位置表示で使うタブ幅で、省略時は4です。正の値を指定してください。
ファイル読取りエラーも呼び出し元へ投げられます。
先頭一致や入力範囲の指定が必要なら、`Source.file(path:)`で読み、`Spellu.parse`へ渡します。

配列の各要素を同じ文法で解析する場合は、次のように書けます。

```swift
let sources: [Source] = [.temporary("123"), .temporary("456")]
let nodes = try sources.wholeMatch(on: NumberGrammar.default, as: \.$number)
assert(nodes.map(\.string) == ["123", "456"])

let files = [File(at: "first.txt"), File(at: "second.txt")]
let fileNodes = try files.wholeMatch(on: NumberGrammar.default, as: \.$number)
```

`[Source].wholeMatch`は文法とキーパスを指定する形式を提供します。
`[File].wholeMatch`は、それに加えて`Syntax`と構文ブロックも指定できます。
配列向けAPIには`from:`はなく、各ソースの範囲の先頭、各ファイルの先頭から解析します。

返却順は入力順です。空配列なら結果も空配列です。
途中の入力でエラーが起きると呼び出し全体がエラーを投げ、途中までの結果配列は返しません。
入力ごとに成功・失敗を収集したい場合は、自分でループし、各`parse`を`do`・`catch`で囲みます。

## 解析結果と構文木の形

`SourceNode`では、主に次の情報を使えます。

- `string`：ノードが表す原文。
- `label`：ルール名や明示したラベル。
- `grammar`：所属する文法名。
- `parts`：子ノードの配列。
- `range`：元の入力に対するUTF-8の範囲。
- `source`：元の`Source`。

ノードの原文には、子ノードの間の空白やコメントが含まれる場合があります。
全体一致で読み飛ばした末尾のtriviaが、返却ノードの`string`へ含まれるとは限りません。

構文木の形式は各解析呼び出しの`strategy:`で指定します。

- `.compact`（既定値）：ラベルのないノードや補助ラベルのノードを畳み込み、名前付きの構造を中心に残します。
- `.asis`：補助的な構造も保持します。構文を確かめたい場合に使えます。

```swift
let detailed = try spellu.parse("123", strategy: .asis, as: NumberGrammar.$number)
```

エンジンによって補助構造が異なる場合があるため、`.asis`の木がすべてのエンジンで同じ形になるとは限りません。

## エンジンと安全上限を設定する

`Spellu()`と各便利メソッドは、既定でInterpreterを使います。
`engine: nil`も同じ意味です。

- `.interpreter`：SyntaxIRを評価するInterpreter。
- `.sakuya`：[専用モデルを準備して直接評価するSakuya](Sakuya.md)。
- `.hoori`：[Earley法をベースとするHoori](Hoori.md)。

安全上限はエンジンの `limits:` で指定します。

```swift
let configured = try Spellu(
    engine: .sakuya(limits: .init(maxSyntaxRepetition: 2_000, maxWork: 2_000_000)),
    on: NumberGrammar.default,
)
```

## エラーを扱う

不一致と、文法や設定の問題を区別したい場合は`SpelluError`を確認します。

```swift
do {
    _ = try "abc".wholeMatch(on: NumberGrammar.default, as: \.$number)
}
catch let error as SpelluError {
    switch error {
    case let .unexpected(_, offset, line, column, expects):
        print("不一致: UTF-8位置\(offset)、\(line)行\(column)列、期待値\(expects)")
    default:
        throw error
    }
}
```

主なエラーには、次のものがあります。

- `.unexpected`：入力が文法に一致しません。位置と期待値を取得できます。
- `.grammarNotFound`・`.ruleNotFound`：必要な文法やルールが見つかりません。
- `.noExposedRule`：公開ルールがありません。
- `.duplicateGrammar`・`.duplicateRule`：登録しようとした定義に名前の重複があります。
- `.invalidStartOffset`：開始位置が不正です。
- `.unsupportedSyntax`：選んだエンジンで扱えない構文があります。
- `.ambiguousPath`：解析経路の曖昧さがあります。
- `.recursiveCall`・`.safetyStop`：再帰や反復などの安全条件により停止しました。

`try?`は失敗理由が不要な簡単な判定には使えますが、文法の問題や安全停止も`nil`へ変換します。
利用者へ診断を返す場合は、エラーを捕捉して理由を保持してください。
