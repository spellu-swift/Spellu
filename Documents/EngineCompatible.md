# エンジン互換性テストの集計

集計日：2026年11月8日。対象：`SpelluCompatibleTests`。
SwiftPMのデバッグ構成で実行し、483テストが成功した。

対象エンジンは Interpreter、Sakuya、Hoori。各テストの一覧ではそれぞれ I、S、H と略す。
「一致」はそのケースで検証したエンジンの期待値が共通であることを示す。
「差異」はエンジン別に異なる期待値を検証しているケースであり、テスト失敗ではない。
エンジン・引数・asis/compactによる実行数を掛けず、テストメソッドを1件と数える。

- 個別ケース：479件（26ファイル）、一致479件、差異0件
- 差分テスト：4件（2ファイル、引数付きテストは1件）
- コメントアウト中：5件（実行件数に含めない）

個別ケースは、特記のない限り木またはエラーを asis・compact の両方で検証する。
各エンジンの対象範囲や設定は各ファイル上部の一覧を参照する。
一致は各ケースで指定されたエンジン間の結果であり、対象外のエンジンの動作は示さない。

## [@Mixed.swift](../Tests/SpelluCompatibleTests/@Mixed.swift)

実行2件、一致2件、差異0件。

## [@Rule-External.swift](../Tests/SpelluCompatibleTests/@Rule-External.swift)

実行5件、一致5件、差異0件。

## [@Rule-Recursive.swift](../Tests/SpelluCompatibleTests/@Rule-Recursive.swift)

実行3件、一致3件、差異0件。

## [@Syntax-AnyOf.swift](../Tests/SpelluCompatibleTests/@Syntax-AnyOf.swift)

実行28件、一致28件、差異0件。

## [@Syntax-AutomaticTrivia.swift](../Tests/SpelluCompatibleTests/@Syntax-AutomaticTrivia.swift)

実行7件、一致7件、差異0件。

Interpreter・Sakuya・Hooriの自動Triviaを比較する。
乱数の文法で見つかった差を固定するケースはasisのみを検証する。

## [@Syntax-Capture.swift](../Tests/SpelluCompatibleTests/@Syntax-Capture.swift)

実行3件、一致3件、差異0件。

## [@Syntax-ChoiceOf.swift](../Tests/SpelluCompatibleTests/@Syntax-ChoiceOf.swift)

実行25件、一致25件、差異0件。

## [@Syntax-Enclosure.swift](../Tests/SpelluCompatibleTests/@Syntax-Enclosure.swift)

実行31件、一致31件、差異0件。

## [@Syntax-Fragment.swift](../Tests/SpelluCompatibleTests/@Syntax-Fragment.swift)

実行25件、一致25件、差異0件。

## [@Syntax-List.swift](../Tests/SpelluCompatibleTests/@Syntax-List.swift)

実行31件、一致31件、差異0件。

## [@Syntax-Optional.swift](../Tests/SpelluCompatibleTests/@Syntax-Optional.swift)

実行9件、一致9件、差異0件。

## [@Syntax-Relabel.swift](../Tests/SpelluCompatibleTests/@Syntax-Relabel.swift)

実行7件、一致7件、差異0件。

- 5件はコメントアウト中。

## [@Syntax-Repeat.swift](../Tests/SpelluCompatibleTests/@Syntax-Repeat.swift)

実行30件、一致30件、差異0件。

## [@Syntax-RepeatOrder.swift](../Tests/SpelluCompatibleTests/@Syntax-RepeatOrder.swift)

実行3件、一致3件、差異0件。

3エンジンのasisの木を比較する。

## [@Syntax-Sequence.swift](../Tests/SpelluCompatibleTests/@Syntax-Sequence.swift)

実行14件、一致14件、差異0件。

## [@Syntax-String.swift](../Tests/SpelluCompatibleTests/@Syntax-String.swift)

実行21件、一致21件、差異0件。

## [@Syntax-Token.swift](../Tests/SpelluCompatibleTests/@Syntax-Token.swift)

実行24件、一致24件、差異0件。

## [@Syntax-Trivia.swift](../Tests/SpelluCompatibleTests/@Syntax-Trivia.swift)

実行35件、一致35件、差異0件。

## [@Syntax-Word.swift](../Tests/SpelluCompatibleTests/@Syntax-Word.swift)

実行29件、一致29件、差異0件。

## [@Token-Character.swift](../Tests/SpelluCompatibleTests/@Token-Character.swift)

実行14件、一致14件、差異0件。

## [@Token-ChoiceOf.swift](../Tests/SpelluCompatibleTests/@Token-ChoiceOf.swift)

実行24件、一致24件、差異0件。

## [@Token-Literal.swift](../Tests/SpelluCompatibleTests/@Token-Literal.swift)

実行1件、一致1件、差異0件。

## [@Token-Optional.swift](../Tests/SpelluCompatibleTests/@Token-Optional.swift)

実行22件、一致22件、差異0件。

## [@Token-Repeat.swift](../Tests/SpelluCompatibleTests/@Token-Repeat.swift)

実行44件、一致44件、差異0件。

## [@Token-Sequence.swift](../Tests/SpelluCompatibleTests/@Token-Sequence.swift)

実行20件、一致20件、差異0件。

## [@Token-String.swift](../Tests/SpelluCompatibleTests/@Token-String.swift)

実行26件、一致26件、差異0件。

## 差分テスト

[InterpreterDifferential.swift](../Tests/SpelluCompatibleTests/InterpreterDifferential.swift) の3件は、
InterpreterとHooriの乱数文法による比較、過去に差が出た文法の回帰、
InterpreterとSakuyaの自動Triviaの比較を実行する。
[HooriDifferential.swift](../Tests/SpelluCompatibleTests/HooriDifferential.swift) の1件は
Interpreter・Sakuya・Hooriを比較する。
乱数の文法数やseedは環境変数で変更でき、比較できなかったケースは各テストで別途集計する。

今回の標準設定では、各差分テストの不一致は0件だった。安全停止や
対象外として比較しなかったケースを含むため、全入力での一致を保証するものではない。

実行：`swift test --scratch-path /private/tmp/swift-package/Spellu --filter SpelluCompatibleTests`
