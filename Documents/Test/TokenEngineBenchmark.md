# TokenEngineのベンチマーク

`TokenEngineBenchmarkTests`は、Interpreter・キャッシュなしMomojiri・
TokenProgramを再利用するMomojiriを比較します。通常のテスト実行ではスキップされます。

## 実行方法

Spelluパッケージのルートで、Releaseビルドを指定して実行します。
他のテストとの同時実行を避けるため、フィルターを付けます。

```bash
SPELLU_TOKEN_BENCHMARK=1 \
CLANG_MODULE_CACHE_PATH=/private/tmp/spellu-clang-module-cache \
swift test -c release \
  --scratch-path /private/tmp/Spellu-token-vm-build \
  --build-system native \
  --filter TokenEngineBenchmarkTests
```

## 測定する処理

パターンと入力は測定前に作成し、3方式に同じものを渡します。

- `interpreter`: `TokenInputStream.match`に`.interpreter`を指定します。
- `momojiri`: `TokenInputStream.match`に`.momojiri`を指定し、呼び出しごとに
  TokenProgramをコンパイルします。
- `momojiri_cached`: 測定前に1回コンパイルしたTokenProgramを保持し、
  各照合で生成したTokenVMの`match`へ渡します。

評価器の初期化、照合、戻り値の位置比較は、すべての方式で測定に含めます。
`momojiri`はコンパイルも含み、`momojiri_cached`は事前コンパイルを含みません。
最適化設定は両VMとも`optimizeSimpleRepetitions: true`です。

`momojiri_cached`が再利用するのはProgramだけです。VM自体や前回の入力位置、
反復・後戻り用の作業領域は再利用しません。
また、辞書などのキャッシュ検索時間や初回のキャッシュ登録時間は含みません。
Programを再利用するのはベンチマーク内だけです。

次の10ケースを比較します。

- 短い固定文字列。
- 文字クラスによる識別子。
- 16,384文字の反復。
- Sequenceの反復。
- ChoiceOfの後続失敗による別候補への後戻り。
- eagerの反復から短い候補への後戻り。
- reluctantの反復。
- possessiveの反復。
- Unicodeの大小文字を区別しない照合。
- 末尾の不一致で反復を戻り、全体が失敗する照合。

反復上限はすべて65,535です。各ケース・各方式で8回のウォームアップ後、
従来の`interpreter`と`momojiri`の遅い方のバッチが20ms以上になるまで
呼び出し回数を倍増します。上限は65,536回です。
決定した同じ回数で3方式を7サンプル測定し、測定順を循環させます。
入力文字列の生成やパターンの作成、事前コンパイル、
テストの検証、結果の出力は測定区間に含みません。

### 過去と同じバッチ回数で測定する

過去の結果と呼び出し回数まで一致させたい場合は、
`SPELLU_TOKEN_BENCHMARK_BATCHES`へ上記10ケースの順で回数を指定します。
この場合は自動調整をせず、指定値を全方式へ適用します。
10個すべてに1〜65,536の整数を指定してください。
2026-10-22の初回結果と同じ回数で比較する例です。

```bash
SPELLU_TOKEN_BENCHMARK=1 \
SPELLU_TOKEN_BENCHMARK_BATCHES=65536,2048,8,64,64,32,32,32,256,32 \
CLANG_MODULE_CACHE_PATH=/private/tmp/spellu-clang-module-cache \
swift test -c release \
  --scratch-path /private/tmp/Spellu-token-vm-build \
  --build-system native \
  --filter TokenEngineBenchmarkTests
```

## 出力の読み方

結果はケースごと・エンジンごとに、次のCSV列で出力します。
過去のログの`vm`／`vm_cached`は、現在の`momojiri`／`momojiri_cached`に対応します。

```text
case,input_bytes,iterations,samples,engine,median_ns,min_ns,max_ns
```

`iterations`は1サンプルの呼び出し回数です。各サンプルの総時間を回数で割り、
1回あたりの平均ナノ秒数を求めます。時間の3列は、その7個の値の
中央値・最小値・最大値です。低いほど短時間で処理できています。
同じケースの中央値同士を比較してください。ビルド時間は含みません。
`momojiri`と`momojiri_cached`の比がProgram再利用による今回の改善率です。
過去の実行結果だけに頼らず、同じ実行で取り直した値同士で比較できます。

すべての照合が期待する成功位置または不一致を返すことと、
呼び出し元の入力位置が変わらないことを検査します。
時間に固定の合格基準は設けません。マシン、電源設定、他の処理の影響を受けるため、
性能を比較するときは同じ環境で複数回実行してください。
