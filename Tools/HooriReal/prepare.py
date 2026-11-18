import json,os,re,glob
ROOT='/Users/fumio/Projects/Spellu'
SRC=ROOT+'/ソース'
DATA=ROOT+'/資料'
OUT='/private/tmp/hoori-real-inputs'
def read(p):
    try:
        return open(p,encoding='utf-8').read()
    except Exception:
        return None
def literals(pkg):
    result=[]
    for p in glob.glob(f'{SRC}/{pkg}/Tests/**/*.swift',recursive=True):
        s=read(p)
        if s is None: continue
        for m in re.finditer(r'"""\n(.*?)\n[ \t]*"""',s,flags=re.S):
            body=m.group(1)
            lines=body.split('\n')
            indent=min([len(l)-len(l.lstrip('\t ')) for l in lines if l.strip()] or [0])
            result.append('\n'.join(l[indent:] for l in lines))
        for m in re.finditer(r'(?<!")"((?:[^"\\\n]|\\.)+)"(?!")',s):
            t=m.group(1)
            if '\\(' in t: continue
            t=t.replace('\\n','\n').replace('\\t','\t').replace('\\"','"').replace('\\\\','\\')
            if len(t)>=2: result.append(t)
    return sorted(set(result))
def files(pattern):
    out=[]
    for p in glob.glob(pattern,recursive=True):
        s=read(p)
        if s is not None: out.append((os.path.relpath(p,ROOT),s))
    return sorted(out)
def write(name,items):
    with open(f'{OUT}/{name}.json','w',encoding='utf-8') as f:
        json.dump([{'name':n,'text':t} for n,t in items],f,ensure_ascii=False)
    print(name,len(items),sum(len(t.encode()) for _,t in items))
write('xml',[(os.path.relpath(p,'/private/tmp/XML-W3C'),read(p)) for p in sorted(glob.glob('/private/tmp/XML-W3C/**/*.xml',recursive=True)) if read(p) is not None])
html=[]
for p,s in files(DATA+'/wpt/**/*.dat'):
    for i,m in enumerate(re.finditer(r'#data\n(.*?)\n#errors',s,flags=re.S)):
        html.append((f'{p}#{i}',m.group(1)))
html+=files(DATA+'/wpt/**/*.html')
write('html',html)
md=[]
cm=json.load(open(SRC+'/ConformanceTestCenter/Tests/MarkdownConformanceTests/Fixtures/commonmark-0.31.2.json'))
for e in cm:
    md.append((f"commonmark#{e['example']}",e['markdown']))
md+=files(DATA+'/**/*.md')
write('markdown',md)
write('ecmascript',files(DATA+'/**/*.js')+[(f'lit#{i}',t) for i,t in enumerate(literals('ECMAScript'))])
write('css',files(DATA+'/**/*.css')+[(f'lit#{i}',t) for i,t in enumerate(literals('CSS'))])
write('lua',[(f'lit#{i}',t) for i,t in enumerate(literals('Lua'))])
write('ebnf',[(f'lit#{i}',t) for i,t in enumerate(literals('EBNF'))])
write('json',files(DATA+'/**/*.json')+[(f'lit#{i}',t) for i,t in enumerate(literals('JSON'))])
