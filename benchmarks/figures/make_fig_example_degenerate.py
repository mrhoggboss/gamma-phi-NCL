#!/usr/bin/env python3
"""make_fig_example_degenerate -- the manuscript's Figure fig:example-degenerate (Section 3.2, Example ex:degenerate),
TikZ code written to <out>/fig_example_degenerate.tex (plain Python, standard library only; ~35 s).

  python3 benchmarks/figures/make_fig_example_degenerate.py [--out=<dir>]     (default: benchmarks/out/paper/figures)

The instance min x1 s.t. x1^2 - x2^2 - 4 = 0, x1 - 2 = 0 under three (weight, kernel) choices: level sets of the selected
merit Theta(x) = sum_i gamma_i |c_i(x)|^p / p (marching squares on a 241 x 161 grid), the stationary points, the basin
separatrix of the spurious minimizer (steepest-descent flow from a 61 x 41 grid), and two steepest-descent paths.
The plotting code is the generator that wrote the manuscript's file (session scratch make_figs.py of 2026-11-11), unchanged
but for the output path and the caption, which is the manuscript's caption verbatim (captions are Yifan's; the scratch
generator still carried its draft, '[DRAFT] ... Gray curves ...').
"""
import os, sys
_opt = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
OUTDIR = _opt.get("out", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "out", "paper", "figures"))
CAPTION = r"""\caption{A degenerate instance: $\min x_1$ subject to $c_1(x) = x_1^2 - x_2^2 - 4 = 0$ (blue) and $c_2(x) = x_1 - 2 = 0$ (red). The feasible set is the single point $(2,0)$ (star), where the line is tangent to the hyperbola and the constraint Jacobian has rank one. White curves are level sets of the selected merit $\Theta(x) = \sum_i \gamma_i |c_i(x)|^p/p$; a filled dot is a spurious local minimizer of $\Theta$, an open dot a saddle, the dashed curve the boundary of the spurious minimizer's basin, and the two thin paths are steepest-descent paths of $\Theta$ from two starting points. With unit weights (a) a run started left of the saddle ends infeasible; weight $4$ on the line (b) removes the spurious minimizer; the power kernel (c) keeps it and moves it.}"""
import math
from collections import defaultdict
def contours(F,xs,ys,level):
    NX,NY=len(xs),len(ys); segs=[]
    table={1:[(3,0)],2:[(0,1)],3:[(3,1)],4:[(1,2)],5:[(3,0),(1,2)],6:[(0,2)],7:[(3,2)],8:[(2,3)],9:[(0,2)],10:[(0,1),(2,3)],11:[(1,2)],12:[(1,3)],13:[(0,1)],14:[(3,0)]}
    for i in range(NX-1):
        for j in range(NY-1):
            a,b,c,d=F[i][j],F[i+1][j],F[i+1][j+1],F[i][j+1]
            idx=(a>level)|((b>level)<<1)|((c>level)<<2)|((d>level)<<3)
            if idx in (0,15): continue
            def lerp(p,q,fp,fq):
                t=(level-fp)/(fq-fp) if fq!=fp else 0.5
                return (p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1]))
            P=[(xs[i],ys[j]),(xs[i+1],ys[j]),(xs[i+1],ys[j+1]),(xs[i],ys[j+1])]
            e=[lerp(P[0],P[1],a,b),lerp(P[1],P[2],b,c),lerp(P[2],P[3],c,d),lerp(P[3],P[0],d,a)]
            for (u,v) in table[idx]: segs.append((e[u],e[v]))
    key=lambda p:(round(p[0],5),round(p[1],5)); adj=defaultdict(list)
    for n,(p,q) in enumerate(segs): adj[key(p)].append(n); adj[key(q)].append(n)
    used=[False]*len(segs); lines=[]
    for n in range(len(segs)):
        if used[n]: continue
        used[n]=True; p,q=segs[n]; line=[p,q]
        for end in (1,0):
            cur=line[-1] if end else line[0]
            while True:
                nxt=[m for m in adj[key(cur)] if not used[m]]
                if not nxt: break
                m=nxt[0]; used[m]=True; a,b=segs[m]; new=b if key(a)==key(cur) else a
                if end: line.append(new)
                else: line.insert(0,new)
                cur=new
        lines.append(line)
    return lines
def grad(f,x,y,h=1e-6): return ((f(x+h,y)-f(x-h,y))/(2*h),(f(x,y+h)-f(x,y-h))/(2*h))
def flow(f,x,y,targets,step=0.01,maxit=6000):
    for _ in range(maxit):
        gx,gy=grad(f,x,y); n=math.hypot(gx,gy)
        if n<1e-9: break
        x-=step*gx/n; y-=step*gy/n
        for k,(tx,ty) in targets.items():
            if math.hypot(x-tx,y-ty)<0.03: return k,(x,y)
    best=min(targets,key=lambda k:math.hypot(x-targets[k][0],y-targets[k][1])); return best,(x,y)
def path(f,x,y,targets,step=0.01,maxit=6000):
    pts=[(x,y)]
    for _ in range(maxit):
        gx,gy=grad(f,x,y); n=math.hypot(gx,gy)
        if n<1e-9: break
        x-=step*gx/n; y-=step*gy/n; pts.append((x,y))
        if any(math.hypot(x-tx,y-ty)<0.03 for tx,ty in targets.values()): break
    return pts
def panel(f,X0,X1,Y0,Y1,levels,zero_sets,stationary,targets,starts,scale,title,NX=241,NY=161,separatrix=True):
    xs=[X0+(X1-X0)*i/(NX-1) for i in range(NX)]; ys=[Y0+(Y1-Y0)*j/(NY-1) for j in range(NY)]
    F=[[f(x,y) for y in ys] for x in xs]
    out=['\\begin{tikzpicture}[x=%gcm,y=%gcm]'%(scale,scale),'\\begin{scope}','\\clip (%g,%g) rectangle (%g,%g);'%(X0,Y0,X1,Y1),'\\fill[black!12] (%g,%g) rectangle (%g,%g);'%(X0,Y0,X1,Y1)]
    for lv in levels:
        for line in contours(F,xs,ys,lv):
            if len(line)<3: continue
            out.append('\\draw[white, line width=0.45pt] '+' -- '.join('(%.3f,%.3f)'%p for p in line[::2]+[line[-1]])+';')
    # basin separatrix: classify a coarse grid by the flow endpoint
    if separatrix and len(targets)>1:
        BX,BY=61,41; bxs=[X0+(X1-X0)*i/(BX-1) for i in range(BX)]; bys=[Y0+(Y1-Y0)*j/(BY-1) for j in range(BY)]
        trapkey=[k for k in targets if k!='feasible'][0]
        B=[[1.0 if flow(f,x,y,targets)[0]==trapkey else 0.0 for y in bys] for x in bxs]
        for line in contours(B,bxs,bys,0.5):
            if len(line)<3: continue
            out.append('\\draw[black, densely dashed, line width=0.5pt] '+' -- '.join('(%.3f,%.3f)'%p for p in line)+';')
    for style,pts in zero_sets:
        out.append('\\draw[%s] '%style+' -- '.join('(%.3f,%.3f)'%p for p in pts)+';')
    for (x,y) in starts:
        pts=path(f,x,y,targets); out.append('\\draw[black!70, line width=0.5pt, -{Stealth[length=3pt]}] '+' -- '.join('(%.3f,%.3f)'%p for p in pts[::25]+[pts[-1]])+';')
        out.append('\\fill[black!70] (%.3f,%.3f) circle (0.9pt);'%(x,y))
    out.append('\\end{scope}')
    out.append('\\draw[black, line width=0.4pt] (%g,%g) rectangle (%g,%g);'%(X0,Y0,X1,Y1))
    for kind,(x,y) in stationary:
        if kind=='feasible': out.append('\\node[star, star points=5, star point ratio=2.2, fill=black, inner sep=1.4pt] at (%.3f,%.3f) {};'%(x,y))
        elif kind=='trap': out.append('\\fill[black] (%.3f,%.3f) circle (1.8pt);'%(x,y))
        else: out.append('\\draw[black, fill=white, line width=0.6pt] (%.3f,%.3f) circle (1.6pt);'%(x,y))
    out.append('\\node[anchor=north, font=\\scriptsize, align=center] at (%g,%g) {%s};'%((X0+X1)/2,Y0-0.08,title))
    out.append('\\end{tikzpicture}'); return out
# ---------- Yifan's instance ----------
def thY(g1,g2,p):
    return lambda x1,x2: g1*abs(x1*x1-x2*x2-4)**p/p+g2*abs(x1-2)**p/p
X0,X1,Y0,Y1=-3.0,3.0,-2.0,2.0
hyp=lambda s:[(s*math.sqrt(4+t*t),t) for t in [Y0+(Y1-Y0)*k/80 for k in range(81)]]
zsY=[('blue!70!black, line width=0.9pt',hyp(1)),('blue!70!black, line width=0.9pt',hyp(-1)),('red!70!black, line width=0.9pt',[(2,Y0),(2,Y1)])]
def levelsY(f,xm,n=8):
    tmin=f(2,0); tref=f(xm,0) if xm is not None else f(-1.7,0)
    vals=[f(x,y) for x in (X0,X1) for y in (Y0,Y1)]; tmax=max(vals)
    base=max(tref*0.2,1e-3); return [base*(tmax/base)**((k+0.5)/n) for k in range(n)]
outY=['% GENERATED: Yifan instance min x1 s.t. x1^2-x2^2-4=0, x1-2=0; level sets of the selected merit, stationary points, basin separatrix, steepest-descent paths.','\\begin{figure}[tbp]\\centering']
pan=[((1,1),2,-1.707,-0.293,'(a) $\\gamma=(1,1)$, $p=2$'),((1,4),2,None,None,'(b) $\\gamma=(1,4)$, $p=2$'),((1,1),6,-1.154,-0.016,'(c) $\\gamma=(1,1)$, $p=6$')]
for (g1,g2),p,xt,xsd,title in pan:
    f=thY(g1,g2,p); targets={'feasible':(2.0,0.0)}; stat=[('feasible',(2,0))]
    if xt is not None: targets['trap']=(xt,0.0); stat+=[('trap',(xt,0)),('saddle',(xsd,0))]
    starts=[(-2.6,1.6),(0.6,1.6)]
    outY+=panel(f,X0,X1,Y0,Y1,levelsY(f,xt),zsY,stat,targets,starts,0.78,title)
outY.append(CAPTION)
outY.append('\\label{fig:example-degenerate}\\end{figure}')
os.makedirs(OUTDIR, exist_ok=True)
open(os.path.join(OUTDIR, 'fig_example_degenerate.tex'),'w').write('\n'.join(outY)+'\n')
print('  -> ' + os.path.join(OUTDIR, 'fig_example_degenerate.tex'))
