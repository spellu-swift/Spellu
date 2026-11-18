
# Spellu

Spelluは、Swiftで定義した文法に従って文字列やファイルを解析し、原文の範囲を持つ構文木を返すパッケージです。
入力全体の検証には`wholeMatch`、先頭の一部分を読み取るには`prefixMatch`を使います。

## 使い方

次の文法は、1桁以上の数字を読み取ります。

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

### Spelluクラスを使う

文法を登録しておくと、同じインスタンスで複数の入力を解析できます。
`parse`は既定で入力全体の一致を要求します。

```swift
let spellu = try Spellu()
    .input(NumberGrammar.default)

let first = try spellu.parse("123", as: NumberGrammar.$number)
let second = try spellu.parse("456", as: NumberGrammar.$number)

assert(first.string == "123")
assert(second.string == "456")
```

### 文字列のwholeMatchを使う

文字列から直接解析する場合は、文法と開始ルールへのキーパスを渡します。

```swift
let result = try "123".wholeMatch(
    on: NumberGrammar.default,
    as: \.$number,
)
assert(result.string == "123")
assert(result.label == "number")
```

成功すると`SourceNode`を返し、不一致や文法の問題があればエラーを投げます。
`string`で原文、`parts`で子ノード、`range`でUTF-8の範囲を取得できます。
既定のエンジンはInterpreter v2、構文木の形式は`.compact`です。

開始位置、ファイルや配列の解析、エンジン設定、エラー処理については、
[Spellu APIガイド](Documents/SpelluAPI.md)を参照してください。

## ドキュメント

- [Spellu APIの概略と使い方](Documents/SpelluAPI.md)
- [@Grammarと@Ruleで文法を定義する](Documents/GrammarDefinition.md)
- [TokenBuilderで字句パターンを定義する](Documents/TokenBuilder.md)
- [SyntaxBuilderで構文を定義する](Documents/SyntaxBuilder.md)
- [SpelluRegexで正規表現を解析・評価する](Documents/Regex.md)
- [TokenEngineのベンチマーク](Documents/Test/TokenEngineBenchmark.md)

## モジュール

- `SpelluLex`：TokenIR、字句Builder、文字集合、反復回数、TokenMatcher、TokenVM。
- `SpelluCore`：SourceStream、構文IR、Interpreter。
- `Spellu`：文法ライブラリと、SpelluCoreを再公開する窓口。

SpelluLexはSpelluCoreへ依存しません。SourceStreamは範囲付きSubstringと現在位置を持つTokenInputStreamへ変換して評価器へ渡します。
字句APIは`import SpelluLex`で利用できます。従来どおり`import SpelluCore`や`import Spellu`からも利用できます。
反復上限は入力ではなくTokenMatcher・TokenVMの設定です。評価器とTokenInputStreamはパッケージ内の実装として扱います。

## 謝辞
Momojiri（桃尻） — pronounced mo-mo-ji-ri in Japanese.
