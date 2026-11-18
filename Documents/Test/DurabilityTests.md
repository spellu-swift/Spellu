# 耐久テスト

大量の反復、深い入れ子、生成パターンによる網羅検査は、通常のテストでは
スキップします。`SPELLU_DURABILITY_TESTS=1`を指定すると実行できます。

```bash
SPELLU_DURABILITY_TESTS=1 \
CLANG_MODULE_CACHE_PATH=/private/tmp/Spellu-durability-clang-module-cache \
swift test --build-system native \
  --scratch-path /private/tmp/Spellu-durability-build \
  --filter DurabilityTests
```

対象は次の4ケースです。入力の大きさや検証条件は、単体テストから移した
時点のものを維持しています。

- TokenProgramCompiler：Sequenceの1万段の入れ子をコンパイルして照合する。
- TokenMatcherと両VM：3種類の反復動作で、2万回の反復と後続照合を処理する。
- SourceStream：3種類の反復動作で、2万回の反復と後続照合を処理する。
- 生成パターン：150パターン・12入力・4上限をTokenMatcherと両VMで相互比較する。

ファイルは各テストターゲットの`Durability`ディレクトリに置いています。
各Suite内のケースは直列で実行します。実行時間は合否条件に含めません。
