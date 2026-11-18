# Sakuyaエンジンの実装

Sakuyaは、文法を専用の `GrammarModel` に変換し、継続を使って評価する構文エンジンです。
`Spellu(engine: .sakuya)` で選択します。

```swift
import Spellu

let parser = try Spellu(engine: .sakuya).input(spaces: []) {
    Repeat { Fragment(label: "body", "a") }
    Fragment(label: "tail", "a")
}
let tree = try parser.parse("aaa", strategy: .asis)
```

この例では、反復を2回で終え、後続で最後の `a` を読みます。

## 文法の準備と解析の入口

`ModelBuilder` は `SyntaxIR` を読み、解決済みのルール・構文式・字句を ID で参照するモデルを作ります。
未定義の参照と外部ルールの公開制限は、この時点で検査します。
字句照合は SpelluLex の Momojiri を使い、準備済みのモデルと字句 `TokenProgram` を入力間で再利用します。
`input` で文法を追加すると、登録した文法全体からモデルを作り直します。
[モデルの生成](../Sources/SpelluSakuya/Model/ModelBuilder.swift)

`Parser.parse` は開始ルールと `Source` 上の絶対 UTF-8 位置を解決し、解析ごとに `Session` を作ります。
セッションはタグ環境、診断、木と Trivia の保存領域、作業予算を持ちます。

- `.whole` は `.whole(rule)` から始めます。開始ルールの各到達から末尾 Trivia と `Source` の範囲末尾を確認し、成立した導出を選択へ渡します。
- `.prefix` は `.rule(rule)` から始めます。開始ルールの到達がそのまま選択の入口になります。

木が表す範囲と、Trivia を含む解析の到達位置は別に保持します。
[解析の入口](../Sources/SpelluSakuya/Parser.swift)・[全体一致の継続](../Sources/SpelluSakuya/Runtime/Continuation.swift)

## 実行フレームと作業キュー

`Session.parse` は明示的なフレームスタックを持ちます。
各フレームの `Evaluation` は、セル、到達結果、ルール呼び出しの索引、作業キューを持ちます。

- `Cell` は評価対象 `Target` と `InputState`、評価モードをキーとし、到達結果と待ち継続を保持します。`InputState` は入力位置とタグ環境 ID、評価モードは Trivia 照合中か、診断を抑制するかを表します。
- `ArrivalResult` は一つの終了状態を表します。`Family` はそこに至る操作、子の結果 ID、Trivia への寄与を記録します。
- `Work.evaluate` は評価対象を進め、`Work.deliver` は結果を継続へ通知します。例えば連接では、`.sequence(expression, next)` がモデル内の構文式と次の要素を指します。先頭の各到達で後続を試し、両方の結果を一つの導出につなぎます。

通常ルールのセルは、ルール ID・開始位置・タグ環境・評価モードが同じ呼び出しで共有します。
連接や通常の構文式のセルは要求ごとに作り、反復の途中状態は反復の入口と `LoopState` で共有します。
到達結果と待ち継続は順序を配列で保持し、2件目から検索用の辞書や集合も使います。
キューが空になると `Evaluation.advance()` が出口の導出を選択へ渡します。
[実行ループとセル](../Sources/SpelluSakuya/Runtime/Evaluation.swift)・[継続](../Sources/SpelluSakuya/Runtime/Continuation.swift)

## 左再帰と導出の循環

1. `request()` は継続を登録し、すでに到達結果があれば配信します。同じキーのルールへ再入しても、本文の評価は追加しません。
2. `publish()` は新しい終了位置・タグ環境の組を登録し、待っている継続へ配信します。
3. 同じ到達に別の導出が増えた場合は、重複を除いて `Family` を追加します。継続は到達結果の ID を参照するので、追加分も後の選択でたどれます。

例えば `Expr = Expr "+" digit | digit` に `1+2+3` を与えると、位置0の `Expr` の再帰側は結果を待ちます。
基底の `1` が位置1に到達すると、その結果から `+2`、さらに `+3` を読み、位置3と5に到達します。
位置3も残るため、呼び出し元が `+3` を読む場合にも使えます。
間接左再帰では複数の呼び出しが互いの結果を待ち、空一致を基底にする場合は開始位置が最初の到達になります。

基底がなければ到達は生じません。`A = A | "a"` のように到達結果へ戻る導出は、`PackedPlan` を作る段階で循環する枝を落とします。
結果グラフを強連結成分（SCC）に分け、結果 ID と同じ循環成分内の祖先集合を組にしてテンプレートを共有します。
同じ結果を再訪した枝を打ち切り、兄弟の使用箇所では祖先集合を独立に扱います。
[呼び出しと配信](../Sources/SpelluSakuya/Runtime/Evaluation.swift)・[循環文脈と導出テンプレート](../Sources/SpelluSakuya/Runtime/SelectionPlan.swift)

## 確定範囲

`Atomic` に入ると、親の評価を保留し、同じ入力位置とタグ環境から本文を評価する子フレームを積みます。
子が成功すると `resume()` が確定した木、終了位置、タグ環境、Trivia を親へ戻します。
子が通常の不一致なら親はその経路を進めず、親のキューに残る別経路を処理します。
子の曖昧性や安全停止は解析全体へ伝わります。
処理中の同じ境界式へ同じ開始位置で戻ると `safetyStop(.other("Recursive prefix match"))` になります。
[境界のスタックと復帰](../Sources/SpelluSakuya/Runtime/Session.swift)・[確定範囲の契約](CommitBoundaries.md)

## 共有導出上での選択

共有式による選択は旧 Interpreter v4 から Sakuya に移植した方式です。
`PackedSelection` は、出口に到達した結果の `Family` を共有式へ写します。
子の候補を配列に展開した直積を作らず、木、Atom（照合や範囲の識別子）、順位、選択履歴、反復履歴を式として持ちます。
出口と各テンプレートの `Family` に選択肢が一つしかなければ、`SingleDerivation` が一つの導出から木を組み立てます。

- `ChoiceOf` は宣言順、`AnyOf` は指定優先値を使います。順位はルールや明示 `Sequence` などの範囲で比較します。
- `Optional` は本文と空成功の両方を後続へ渡し、成立する候補では本文を優先します。Optional 自身の順位と本文の順位は別に扱います。
- `Repeat` は eager で継続、reluctant で終了を優先します。先頭の回から継続・終了と本文を比べます。反復の前半は共有履歴で表し、終了候補ごとに反復履歴を組み直しません。

### 選択条件と使用箇所

分岐条件は縮約した多値決定 DAG（MDD）で表します。
複数の出口を選ぶ変数を先に作り、次にテンプレートを逆後行順でたどります。共有された子へのどの辺でも親の変数が先になります。
同じ `Family` で同時に使う子が同じ分岐変数を持つ場合は、重なる変数だけを使用箇所の展開時に複製します。
排他的な `Family` 間では変数を共有でき、複製の順序は元の変数の順序と複製 ID で決まります。

同じ構造の条件付き値は構造を共有し、各フィールドに条件を残します。
条件を式へ適用するときは、その式が依存しない変数を射影で除きます。
依存集合は複製前の変数を基準とし、未展開の使用箇所ではテンプレートの依存集合を使います。
[共有式の選択](../Sources/SpelluSakuya/Runtime/SharedSelection.swift)・[MDD の演算](../Sources/SpelluSakuya/Runtime/SelectionDecision.swift)

### 優先順位、曖昧性、木の具体化

1. 選択履歴を、構造の一致を確認するトークンと順位を比較するトークンの列として読みます。現在の条件で実現可能な値を順に最大化します。
2. 最初の差が順位なら除かれた候補は劣位です。構造が異なる場合は比較不能として記録します。
3. 同じ最上位の履歴が残る条件では、出口の結果 ID と導出の各フィールドが、代表の選択結果と同値かを照会します。比較不能な候補や、異なる木・出口などが残る場合は `ambiguousPath` を返します。
4. 選ばれた構文枝を `DerivationStore` の木に具体化します。字句の葉と子境界で確定した木は既存の ID を参照します。

`.asis` は組み立てた構造を保持します。`.compact` では同じ文法に属する一時ラベルの子を畳み込みます。
`Relabel` は対象の直下の木のラベルを付け替えます。
循環処理、式評価、木の具体化には明示的な作業スタックを使います。
[単一導出](../Sources/SpelluSakuya/Runtime/SingleDerivation.swift)・[構文木の出力](../Sources/SpelluSakuya/Runtime/Storage.swift)

## 字句、Trivia、タグ記録と診断

字句照合用の `SourceStream` は候補の位置から作ります。
タグ付き字句が成功すると、照合した原文の範囲を文法 ID とタグ名で記録します。
後方参照は同じ文法の記録を読み、未記録なら不一致になります。
`Capture` は本文の終了位置と木を保持し、タグ環境を入口の状態へ戻します。

前置 Trivia を許す字句や全体一致の末尾では、字句 Trivia と構文 Trivia の到達から評価を続けます。
構文Triviaが自動で消費した範囲は、選ばれた導出を入力順にたどって `SourceTree.trivia` に出力します。
読み方が複数あるときは、到達ごとに先頭の構文Triviaが最も長い読み方を残すので、先頭から順に各構文Triviaが最も長くなる読み方になります。
読み飛ばしの到達ごとに範囲の列を保持し、本文の選択履歴から分けます。
明示的な `Trivia` は消費範囲を本文の木に持ちます。
通常の失敗は最遠位置と期待値の種別を記録し、最上位の不一致で期待値を生成します。
自動 Trivia の試行中は診断を抑制します。
[走査と Trivia](../Sources/SpelluSakuya/Runtime/Scanner.swift)・[タグ環境と診断](../Sources/SpelluSakuya/Runtime/Session.swift)

## 実行時の上限

- `maxRuleArrivals`（既定4,096）は通常ルールの呼び出しキーごとに、終了位置または出力タグ環境の異なる到達を数えます。同じ到達への導出追加は到達数に含めません。
- `maxWork`（既定1,000,000）は解析セッション全体で共有します。子境界の処理、キュー、共有式、条件演算、木の具体化などで消費します。
- `maxSyntaxRepetition`（既定1,000）は、子境界の深さと構文反復の連続無消費回数を制限します。無消費の回で最小回数を満たした場合は、その到達を公開して反復を終えます。
- `maxTokenRepetition`（既定65,535）は字句反復を制限します。

上限に達して処理を継続できない場合は、安全停止を返します。
[設定値](../Sources/SpelluSakuya/SafetyLimits.swift)・[安全上限のテスト](../Tests/SpelluSakuyaTests/@SafetyLimits.swift)

## 関連テスト

- [解析のテスト](../Tests/SpelluSakuyaTests/@Parser.swift) は左再帰、短い到達、循環、Atomic、Capture を確認します。
- [条件演算のテスト](../Tests/SpelluSakuyaTests/@SelectionDecision.swift) は変数の遅延複製、順序、条件の射影を確認します。
- [内部ストレージのテスト](../Tests/SpelluSakuyaTests/@RuntimeStorage.swift) と [自動 Trivia のテスト](../Tests/SpelluSakuyaTests/@AutomaticTrivia.swift) は、到達・導出の共有と採用した枝の Trivia を確認します。
- [再帰の互換性テスト](../Tests/SpelluCompatibleTests/@Rule-Recursive.swift) と [反復順の互換性テスト](../Tests/SpelluCompatibleTests/@Syntax-RepeatOrder.swift) は、木と選択順を他エンジンと比較します。
