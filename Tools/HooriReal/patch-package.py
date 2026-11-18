# 文法パッケージのコピーを、作業中のSpelluと（指定があれば）別のエンジンで動くように書き換える。
import glob,re,sys
root,mode,W=sys.argv[1],sys.argv[2],sys.argv[3]
SPELLU='/Users/fumio/Projects/Spellu/ソース/Spellu'
p=root+'/Package.swift'
s=open(p,encoding='utf-8').read()
s=s.replace('.package(url: "git://git.orion/spellu/Spellu", branch: "develop")',f'.package(path: "{SPELLU}")')
for d in ['XML','HTML','Markdown','EBNF']:
    s=s.replace(f'.package(url: "git://git.orion/spellu/{d}", branch: "develop")',f'.package(path: "{W}/{d}")')
open(p,'w',encoding='utf-8').write(s)
if mode=='v4':
    for f in glob.glob(root+'/Sources/**/*.swift',recursive=True):
        s=open(f,encoding='utf-8').read()
        n=s.replace('.interpreter(.v2, limits: limits ?? .default)','.interpreter(.v4, limits: limits ?? .default)')
        if n!=s: open(f,'w',encoding='utf-8').write(n)
if mode=='hoori':
    E='.hoori(limits: .init(maxWork: 500_000_000))'
    # InterpreterのAPIを直接使うファイルは置き換えない。
    SKIP=('CLIApplication.swift','CSSGrammarTestSupport.swift')
    for f in glob.glob(root+'/Sources/**/*.swift',recursive=True)+glob.glob(root+'/Tests/**/*.swift',recursive=True):
        if f.endswith(SKIP): continue
        s=open(f,encoding='utf-8').read()
        n=s
        n=n.replace('.interpreter(.v2, limits: limits ?? .default)',E)
        n=re.sub(r'\.interpreter\(\s*\.v[24],\s*limits:\s*\.default\s*\)',E,n)
        n=re.sub(r'\.interpreter\(\s*\.v[24],\s*limits:\s*SafetyLimits\([^)]*\)\s*,?\s*\)',E,n)
        # InterpreterのAPI（method: の直後の engine:）は別の型なので置き換えない。
        n=re.sub(r'(?<!method: \.whole, )engine: \.v2\b','engine: '+E,n)
        if n!=s: open(f,'w',encoding='utf-8').write(n)
