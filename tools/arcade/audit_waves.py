#!/usr/bin/env python3
"""Audit des vagues : compare CombatWave aux sondes RAM 8000-83ff.

Usage :
  python tools/arcade/audit_waves.py DOSSIER_SONDES [--godot CHEMIN]
  python tools/arcade/audit_waves.py DOSSIER_SONDES --checkpoints

DOSSIER_SONDES est parcouru à la recherche de */replay-probe.csv
(sorties de capture.py --probe 8000-83ff). Chaque apparition de vague (huit
objets 0x8184 + 20k aux positions d'entrée étroite, large, en rangée ou en
chute) devient un segment : pas du vaisseau (0x822b - 16) à chaque image de
boucle (0x8005), destructions (objet figé, puis 0x823c ou score), crédits
(0x823c), compteurs de motifs 0x8242-0x8247 et maximum de plongeurs 0x823d.
prototype/tests/run_wave.gd rejoue les segments et l'outil affiche la
première divergence de position. --checkpoints régénère
prototype/tests/wave_checkpoints.gd (utilisé par tests/test_waves.gd).
"""
import csv, glob, json, os, subprocess, sys, tempfile

ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROTO=os.path.join(ROOT,'prototype')
GODOT=os.environ.get('GODOT','godot')

def load(path):
    out={}
    with open(path) as f:
        r=csv.reader(f); next(r)
        for row in r: out[int(row[0])]=bytes.fromhex(row[1])
    return out


def has_wave_probe(path):
    with open(path, newline='') as stream:
        return next(csv.reader(stream), []) == ['frame', '8000-83ff']

def name(p): return p.replace('\\','/').split('/')[-3]

NARROW=[(112,96),(112,96),(120,96),(120,96),(128,96),(128,96),(120,88),(120,88)]
WIDE=[(117,128),(123,128)]*4
ROW=[(32,0),(56,0),(80,0),(104,0),(136,0),(160,0),(184,0),(208,0)]
def pos(m,k): a=0x170+20*(k+1); return (m[a+2],m[a+1])
def kind(m):
    ps=[pos(m,k) for k in range(8)]
    if ps[3]==(144,80) and ps[7]==(80,128) and all(ps[k]==(0,0) for k in (0,1,2,4,5,6)):
        return 'fall',255
    for nm,pat in (('narrow',NARROW),('wide',WIDE),('row',ROW)):
        ok=[ps[k]==pat[k] for k in range(8)]
        if sum(ok)>=1 and all(ok[k] or ps[k]==(0,0) for k in range(8)):
            return nm,sum(1<<k for k in range(8) if ok[k])
    return None,0
def segments(P):
    F=sorted(P); segs=[]
    for f in F[1:]:
        if f-1 not in P: continue
        k,mask=kind(P[f])
        kp,_=kind(P[f-1])
        if k and kp!=k and P[f][0x9b] not in (1,0x11):
            segs.append((f,k,mask))
    return segs
def obj(m,k):
    o=0x170+20*(k+1); return bytes(m[o:o+17])
def score(m):
    try: return int('%02x%02x'%(m[0x99],m[0x9a]))
    except: return None
def build(P, start, mask, kindname):
    F=sorted(P); end=F[-1]
    lvl=P[start][0x9b]
    loops=[]; f=start
    while f<=end:
        if f not in P: break
        m=P[f]
        if m[0x9b]!=lvl or m[4]==1 or m[0x1d]!=0: break
        loops.append(f)
        f+=1
        while f in P and P[f][5]==P[f-1][5]: f+=1
    if not loops:
        return [], [], {}
    # kills
    kills={}
    sc=[f for f in range(start+1,loops[-1]+1) if f in P and f-1 in P and (P[f][0x23c]<P[f-1][0x23c] if kindname!='fall' else (score(P[f]) or 0)>(score(P[f-1]) or 0))]
    used=set()
    for s in sc:
        best=None
        for k in range(8):
            if k in used or not mask>>k&1: continue
            # freeze start
            fr=None
            for g in range(s-25,s+1):
                if g not in P or g-2 not in P: continue
                if all(obj(P[h],k)==obj(P[g],k) for h in range(g,min(s+15,loops[-1]+1))) and obj(P[g-2],k)!=obj(P[g],k):
                    fr=g;break
            if fr is not None and kindname=='fall' and pos(P[fr],k)[1]==0: fr=None
            if fr is not None and (best is None or abs((s-fr)-10)<abs((s-best[1])-10)): best=(k,fr)
        if best:
            used.add(best[0]); kills.setdefault(best[1],[]).append(best[0])
    if kindname == 'row':
        # Un impact peut désactiver l'objet avant la fin du segment, puis
        # créditer les points pendant la transition du joueur.
        for k in range(8):
            if k in used or not mask>>k&1:
                continue
            active = 0x182 + 20*k
            for f in range(start+1, loops[-1]+1):
                if P[f-1][active] == 1 and P[f][active] == 0:
                    kills.setdefault(f, []).append(k)
                    break
    steps=[]
    for f in loops:
        steps.append([P[f][0x22b]-16, []])
    # assign each kill to the first loop frame >= freeze-1
    for kf,kl in kills.items():
        for i,f in enumerate(loops):
            # Rangées : l'objet touché fait son dernier pas à l'image figée kf,
            # l'impact s'applique avant le pas suivant.
            if f>=(kf+1 if kindname=='row' else kf-1):
                steps[i][1]+=kl; break
    return loops, steps, kills
_PC={}
def P_cache(p):
    if p not in _PC: _PC[p]=load(p)
    return _PC[p]
def run(segs):
    scenarios = []
    for s in segs:
        probe = P_cache(s['path'])
        credits = []
        for i, frame in enumerate(s['loops']):
            before, after = probe[frame-1], probe[frame]
            if s['kind']=='fall':
                credited = (score(after) or 0) > (score(before) or 0)
            else:
                credited = after[0x23c] < before[0x23c]
            if credited:
                credits.append(i+1)
        scenario = {k:s[k] for k in ('wave', 'mask', 'steps', 'stage', 'patterns', 'max_divers')}
        scenario['credits'] = credits
        scenarios.append(scenario)
    with tempfile.TemporaryDirectory(prefix='swarmattack-waves-') as temp:
        inp = os.path.join(temp, 'input.json')
        out = os.path.join(temp, 'output.txt')
        with open(inp, 'w') as stream:
            json.dump(scenarios, stream)
        subprocess.run([GODOT,'--headless','--path',PROTO,'--script','res://tests/run_wave.gd','--',inp,out],
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=600, check=True)
        res = []
        with open(out) as stream:
            for line in stream:
                if line.startswith('SEG'):
                    res.append([])
                else:
                    res[-1].append([tuple(map(int,t.split(','))) for t in line.split()])
    if len(res) != len(segs):
        raise RuntimeError("Nombre de segments rejoués incorrect")
    return res

SEL=[('pr6b-hitbox-i-ii',10935,None,'0x07 après le premier amarrage, vaisseau mobile'),
     ('pr11c-cycle-vague-4-tir-precoce',20185,None,'0x14 cycle 2, cinq ennemis abattus'),
     ('pr11c-cycle-vague-4-tir-precoce',18337,None,'0x12 cycle 2, séparations et piqués'),
     ('pr11c-cycle-vague-4-tir-precoce',19720,None,'0x13 cycle 2, sept abattus'),
     ('pr11b-cycle-vague-4-patrouille',29507,None,'0x03 démo'),
     ('pr7-amarrage-i-ii-iii',14164,None,'0x09 objets en chute'),
     ('pr7-amarrage-i-ii-iii',14503,None,'0x0a objets en chute'),
     ('pr11d-cycle-vague-4-immobile',16693,None,'0x0c rangée, vaisseau immobile, sept abattus'),
     ('pr11c-cycle-vague-4-tir-precoce',17157,None,'0x0d rangée, huit abattus'),
     ('pr11b-cycle-vague-4-patrouille',16693,None,'0x0c rangée, sorties latérales'),
     ('pr9-tir-i-ii-iii',17668,None,'0x0c rangée, cinq survivants, motifs remis à zéro'),
     ('pr12a-cycle-1-debut',571,None,"0x02 cycle 1, séparations depuis l'ouverture"),
     ('pr12a-cycle-1-debut',2611,None,'0x03 cycle 1, séparations puis piqués sous 5'),
     ('pr12a-cycle-1-debut',3749,None,'0x04 cycle 1'),
     ('pr12a-cycle-1-debut',4531,1200,'0x05 cycle 1, 1200 premiers pas'),
    ('pr13a-suite-depuis-debut',4531,None,'0x05 cycle 1 jusqu’à la perte de vie'),
    ('pr13a-suite-depuis-debut',5915,None,'0x05 reprise après perte, cadence d’entrée conservée'),
    ('pr14a-suite-immobile',5915,None,'0x05 reprise, vaisseau immobile, cadence d’entrée conservée')]

def checkpoints(probes):
    out=[]
    for nm,st,limit,label in SEL:
        p=[x for x in probes if name(x)==nm][0]
        P=load(p); seg=[s for s in segments(P) if s[0]==st][0]
        loops,steps,kills=build(P,seg[0],seg[2],seg[1])
        if limit: loops=loops[:limit]; steps=steps[:limit]
        kind=seg[1]
        lvl=P[st][0x9b]&15
        wave=1 if kind=='narrow' else 5 if kind=='fall' else 3
        stage=1 if 7<=lvl<=10 else 2 if lvl in (12,13) else 0
        rle=[]
        for s in steps:
            if rle and rle[-1][1]==s[0]: rle[-1][0]+=1
            else: rle.append([1,s[0]])
        killsteps=[[i+1,k] for i,s in enumerate(steps) for k in s[1]]
        if kind=='fall':
            credits=[i+1 for i,f in enumerate(loops) if (score(P[f]) or 0)>(score(P[f-1]) or 0)]
        else:
            credits=[i+1 for i,f in enumerate(loops) if P[f][0x23c]<P[f-1][0x23c]]
        dead=set(); cps=[]
        for i,f in enumerate(loops):
            for k in steps[i][1]: dead.add(k)
            if (i+1)%8==0:
                v=[]
                for k in range(8):
                    if k in dead or not seg[2]>>k&1: v+= [-1,-1]
                    else: v+=list(pos(P[f],k))
                cps.append([i+1,v])
        out.append(dict(label='%s %d : %s'%(nm,st,label),wave=wave,mask=seg[2],stage=stage,patterns=list(P[st][0x242:0x248]),max_divers=P[st][0x23d],ship=rle,kills=killsteps,credits=credits,checkpoints=cps))
    def gd(v):
        if isinstance(v,dict): return '{'+', '.join('"%s": %s'%(k,gd(x)) for k,x in v.items())+'}'
        if isinstance(v,list): return '['+', '.join(gd(x) for x in v)+']'
        if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
        return str(v)
    with open(os.path.join(PROTO,'tests','wave_checkpoints.gd'),'w') as f:
        f.write('extends RefCounted\n\n# Généré par tools/arcade/audit_waves.py --checkpoints à partir des sondes RAM\n# (8000-83ff) : position des huit objets 0x8184 + 20k toutes les 8 images de boucle,\n# pas du vaisseau (0x822b - 16), destructions et crédits (0x823c ou score).\n# -1 : objet détruit ou absent du masque.\n')
        f.write('const SEGMENTS := [\n')
        for s in out: f.write('\t'+gd(s)+',\n')
        f.write(']\n')
    print(sum(len(s['checkpoints']) for s in out))

def main():
    global GODOT
    args=sys.argv[1:]
    if not args:
        print(__doc__); return 2
    if '--godot' in args:
        i=args.index('--godot'); GODOT=args[i+1]; del args[i:i+2]
    probes=sorted(p for p in glob.glob(os.path.join(args[0],'**','replay-probe.csv'),recursive=True) if has_wave_probe(p))
    if not probes:
        print("Aucune sonde RAM 8000-83ff trouvée.", file=sys.stderr)
        return 2
    if '--checkpoints' in args:
        checkpoints(probes); return 0
    allsegs=[]
    for p in probes:
        P=P_cache(p)
        for (f,k,mask) in segments(P):
            loops,steps,kills=build(P,f,mask,k)
            if len(loops)<3: continue
            allsegs.append(dict(probe=name(p),path=p,start=f,kind=k,mask=mask,lvl=P[f][0x9b],loops=loops,steps=steps,kills=kills,wave=1 if k=='narrow' else 5 if k=='fall' else 3,stage=(1 if 7<=(P[f][0x9b]&15)<=10 else 2 if (P[f][0x9b]&15) in (12,13) else 0),patterns=list(P[f][0x242:0x248]),max_divers=P[f][0x23d]))
    res=run(allsegs)
    for s,r in zip(allsegs,res):
        P=P_cache(s['path'])
        first=None; dead=set()
        for i,f in enumerate(s['loops']):
            for k in s['steps'][i][1]: dead.add(k)
            for k in range(8):
                if not s['mask']>>k&1 or k in dead: continue
                rp=pos(P[f],k); x,y=r[i][k][:2]
                if (x,y)!=rp:
                    first=(i,f,k,rp,(x,y)); break
            if first: break
        n=first[0] if first else len(s['loops'])
        print('%-34s 0x%02x %-6s début %5d masque %02x pas %4d tués %2d  concordance %4d %s'%(s['probe'][:34],s['lvl'],s['kind'],s['start'],s['mask'],len(s['loops']),sum(len(v) for v in s['kills'].values()),n, ('écart image %d objet %d RAM %s prototype %s'%first[1:]) if first else 'COMPLÈTE'))
    return 0

if __name__=='__main__':
    sys.exit(main())
