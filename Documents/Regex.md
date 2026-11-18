# SpelluRegex

SpelluRegexは、ECMAScript 2026のuモードの構文・意味論を基準にした、
UnicodeScalar単位の正規表現です。フラグの指定は不要です。
正規表現文法はSpelluで定義し、Interpreter v2で解析します。
照合はSpelluRegex専用の命令配列VMで行います。

```swift
import SpelluRegex

let regex: SpelluRegex = try .init(
    #"([a-z]+)-(\d+)"#,
    options: .init(characterSemantics: .ecmaScript2026),
)
let match: Match? = try regex.wholeMatch(in: "item-123")
let prefix: Match? = try "item-123!".prefixMatch(of: regex)
let first: Match? = try "商品: item-123".firstMatch(of: regex)

if let match {
    print(match.substring) // item-123
    if let range = match.captures[0] {
        print(match.input[range]) // item
    }
}
```

SwiftPMからは、Spelluパッケージの`SpelluRegex`プロダクトを依存先に指定します。
`import Spellu`による再公開は行いません。

## 照合と結果

- `wholeMatch(in:)`: 入力範囲全体に一致する候補を探します。
- `prefixMatch(in:)`: 入力範囲の先頭から一致します。
- `firstMatch(in:)`: 左からScalar境界ごとに検索し、最初の一致を返します。

同じ操作をString／Substringの`wholeMatch(of:)`、`prefixMatch(of:)`、
`firstMatch(of:)`からも呼べます。不一致はnilです。
不正なパターンと資源上限の超過は、例外として返します。

全体一致では末尾条件も含めて後戻りします。
たとえば`a|ab`の`ab`への先頭一致は`a`、全体一致は`ab`です。
選択は記述順であり、全体の最長候補を無条件に選ぶ規則ではありません。

Matchは元のSubstring、全体のrange、捕捉番号1から順のcapturesを持ちます。
捕捉の範囲は元の入力上の`Range<String.Index>`です。
未参加の捕捉はnil、空文字の捕捉は空範囲で区別します。
正規表現は不変・Sendableであり、照合の実行状態を共有しません。

名前付き捕捉は`capture(named:)`で文字列、`range(ofCapture:)`で範囲を
取得できます。`captureNames`は初出順の復号済みの名前です。
名前が存在しない場合と、該当の捕捉が参加しなかった場合はnilになります。

```swift
let repeated: SpelluRegex = try .init(#"(?<word>\w+)\s+\k<word>"#)
if let match = try repeated.wholeMatch(in: "hello hello") {
    print(match.capture(named: "word")!) // hello
}
```

## 対応構文

- 文字、ドット、選択、連結、空パターンと空の選択肢。
- `*`、`+`、`?`、`{n}`、`{n,}`、`{n,m}`と、末尾`?`の非貪欲指定。
- 捕捉グループ`(...)`、非捕捉グループ`(?:...)`。
- 名前付き捕捉`(?<name>...)`、数値参照`\1`、名前による参照`\k<name>`。
- word境界`\b`、非word境界`\B`、肯定／否定の先読み`(?=...)`／`(?!...)`。
- 局所修飾子`(?i:...)`、`(?im-s:...)`。i／m／sの追加・削除に対応します。
- `^`、`$`。multilineオプションで行境界にも一致します。
- 通常の文字クラス、範囲、否定、空集合`[]`と`[^]`。
- `\d`／`\D`、`\w`／`\W`、`\s`／`\S`。
- `\n`、`\r`、`\t`、`\v`、`\f`、`\0`、`\cA`、`\xHH`、
  `\uHHHH`、`\u{...}`、構文記号のescape、文字クラス内の`\b`。
- `\p{...}`／`\P{...}`。General_Category、収録済みのBinary Property、
  `Any`、`ASCII`、`Assigned`。

OptionsのignoresCaseはUnicode Simple Case Folding、dotMatchesNewlinesは
改行を含むドット、multilineは行境界を有効にします。
パターンの空白・改行は読み飛ばしません。`/pattern/flags`形式の
リテラルを切り出す機能は提供せず、区切りのないパターンを渡します。

## 捕捉・先読み・局所修飾子

捕捉番号は名前の有無にかかわらず、開き括弧の順序で割り当てます。
前方の位置から後ろの捕捉を参照する構文も受理します。
未参加またはまだ完了していない捕捉への参照は、空文字に一致します。
存在しない番号・名前への参照は構築時のエラーです。
後方参照の比較には参照位置で有効なignoresCase設定を使います。

捕捉名はUnicode識別子として検証し、Unicode escapeも復号します。
名前の比較では正規等価な別の符号列を統合しません。
同名捕捉は、共通の選択規則の別Alternativeに属する場合に限り許可します。
たとえば`(?<x>a)|(?<x>b)`は受理し、`(?<x>a)(?<x>b)`は拒否します。
同名のグループはcaptureNamesでは一つにまとめ、参加した捕捉を返します。

word境界は選択したCharacterSemanticsのword集合と、その位置で有効な
ignoresCase設定に従います。文字クラス内の`\b`は従来どおりbackspaceです。

先読みは外側の入力位置を進めません。肯定先読みは捕捉を外側へ引き継ぎ、
成功後にその内部へ後戻りしません。否定先読みの捕捉は外側へ残しません。
肯定先読みの捕捉範囲は、全体の一致範囲より先に及ぶことがあります。
uモードでは先読みやword境界へ量指定子を付けることはできません。

局所修飾子はグループ内だけの変更です。入れ子・後戻り・先読みを含め、
グループの外では元の設定を使います。同じ文字の重複、追加と削除の衝突、
空の変更指定、i／m／s以外の指定は拒否します。
文字クラスのプロファイル、uモード、Unicodeデータ版は変更しません。

## 文字クラスのセット

`Options.characterSemantics`で、構文を変えずに解釈を選びます。

- `.spellu`（既定）: `\d`はUnicode Nd、`\w`はSpelluのword集合、
  `\s`はSpelluのspaceとnewlineの和集合です。
  プロパティ名には既存UnicodeCharacterDatabaseの便宜的な名前も使えます。
- `.ecmaScript2026`: `\d`はASCII数字、`\w`はASCII英数字とunderscoreを
  基礎に、ignoresCase時のUnicode foldingを考慮します。
  `\s`はECMAScriptのWhiteSpaceとLineTerminatorです。
  プロパティ名はECMAScriptの許可する名前・別名から解決します。

`\u{...}`等の数値escapeは、どちらのセットでも同じScalarを表します。
これらを文字クラスのセットによって別のコードポイントへ再解釈しません。
短縮文字クラスのマッピングはVMがOptionsから選び、プロパティ名は
構築時に同じOptionsで解決します。

Unicodeデータは依存するUnicodeCharacterDatabaseの17.0.0を使用します。
General_Categoryは略称・正式名と、cntrl／digit／punct／Combining_Markに対応します。
Binary Propertyは収録済みデータに限られます。Script／Script_Extensionsと、
Emoji_Component等の未収録プロパティは未対応エラーになります。
ECMAScriptセットは、ECMAScriptエンジン全体への完全準拠を表す名前ではありません。

## Scalarとしての境界

入力は常にUnicodeScalar単位です。絵文字一つは一Scalarとして扱い、
`e`と結合アクセントは二Scalarとして扱います。
正規等価な別の符号列を統合しません。UTF-16インデックスは返しません。

文字集合の母集合はU+0000…U+D7FFとU+E000…U+10FFFFです。
サロゲートのプロパティは空集合、その否定はScalar全体になります。
サロゲート領域をまたぐ範囲でも、入力へサロゲートを許すことはありません。

`\uD83D\uDE00`のようなuモードで一つのScalarを表すescape対は対応します。
孤立サロゲートは未対応エラーにし、置換文字へ変換しません。

## 上限と診断

RegexLimitsでpatternのScalar数、入れ子、ノード・命令数、捕捉数、
入力Scalar数、VMの実行ステップ数、再試行スタックを制限できます。
入れ子上限の設定範囲は1…256で、他の設定値は正の整数です。
実行ステップ予算は検索全体で共有し、開始位置ごとにリセットしません。
命令の実行に加えて後方参照のScalar比較もステップとして数えます。
先読みの実行と検索全体で同じ予算を共有します。
先読みの実行範囲は再試行スタックと合わせて制限します。
実行時間を一定にする保証ではありません。

構文不正はinvalidPattern、未対応機能はunsupportedFeature、
不正な上限設定はinvalidLimits、上限超過はresourceLimitです。
パターン内の診断範囲はUTF-8オフセットです。
量指定の整数がIntで保持できない場合もresourceLimitになります。
回数を上限で切り詰めて別のパターンとして評価することはありません。

## 初期版の対象外

vモード、lookbehind、文字列のUnicode Property、Annex B、
JavaScriptのRegExpオブジェクト・
lastIndex・g／y／d、繰り返し検索・置換APIは対象外です。
未対応の構文を通常の文字列として実行することはありません。

原典: [ECMAScript 2026 PatternsとPattern Semantics](https://tc39.es/ecma262/2026/multipage/text-processing.html#sec-patterns)。
